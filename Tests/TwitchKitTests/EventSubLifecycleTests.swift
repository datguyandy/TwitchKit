import XCTest
import Foundation
@testable import TwitchKit

/// Tests for `EventSubClient` lifecycle correctness:
///
/// 1. **Deinit reachability** — the client's long-running tasks (path-monitor
///    loop, keepalive watchdog) capture `self` weakly and re-acquire it per
///    step, so they must not retain the client while suspended. A regression
///    here makes `deinit` unreachable and leaks the client (plus its socket)
///    forever.
/// 2. **Cancellation-aware welcome waits** — `connect(timeout:)` enforces its
///    deadline by cancelling the welcome wait inside a task group, and the
///    group must then *await* the cancelled child. A welcome continuation that
///    ignored cancellation would block the group until a socket error or late
///    welcome arrived — potentially minutes past the deadline.
///
/// These tests drive the private machinery directly through small internal
/// test-only seams (`armKeepaliveForTesting`, `waitForWelcomeForTesting`,
/// `deliverWelcomeForTesting`), following the precedent of
/// `setConnectBodyForTesting` — deliberately below the `socketFactory` seam
/// (see EventSubSocketTests), so each property is pinned in isolation.
final class EventSubLifecycleTests: XCTestCase {

    // MARK: - Deinit reachability

    func test_clientDeallocatesWhilePathMonitorStreamIsParked() async throws {
        let mock = MockNetworkPathMonitor()
        var client: EventSubClient? = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: mock)
        weak var weakClient = client

        // Spawns the path-monitor task, which parks on the (never-ending)
        // update stream. Drive one update through so the loop has demonstrably
        // acquired-and-released the client at least once before we drop it.
        await client?.startConnectionLifecycle()
        mock.send(.satisfied)
        await Task.yield()

        // Assigning nil drops the last strong reference deterministically
        // (scope-end release timing is not guaranteed under ARC).
        client = nil

        // Deallocation is asynchronous — the monitor loop may hold a momentary
        // strong reference while handling the update — so poll with a timeout
        // like the connect-coalescing test does. Pre-fix, the task's single
        // `guard let self` pinned the client for the stream's whole life and
        // this never becomes nil.
        var attempts = 0
        while weakClient != nil, attempts < 500 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(weakClient, "path-monitor task retained the client while parked on the update stream")

        // deinit cancels the monitor — poll briefly since weak refs can read
        // nil while the deinit body is still finishing up.
        attempts = 0
        while !mock.didCancel, attempts < 100 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(mock.didCancel, "deinit should cancel the path monitor")
    }

    func test_clientDeallocatesWhileKeepaliveWatchdogIsSleeping() async throws {
        var client: EventSubClient? = EventSubClient(
            api: makeDummyAPI(),
            isLive: { false },
            pathMonitor: MockNetworkPathMonitor()
        )
        weak var weakClient = client

        // Arms the watchdog: it computes a deadline ~15s out (default
        // keepalive 10s + 5s grace) and suspends in its sleep.
        await client?.armKeepaliveForTesting()
        client = nil

        // Pre-fix, the watchdog's `guard let self` held the client across
        // that entire sleep, so it stayed alive well past this 5s poll.
        // Post-fix the sleep holds no strong reference and deallocation is
        // immediate (deinit then cancels the watchdog, which exits).
        var attempts = 0
        while weakClient != nil, attempts < 500 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(weakClient, "keepalive watchdog retained the client while sleeping toward its deadline")
    }

    // MARK: - Cancellation-aware welcome waits

    func test_welcomeWaitTimeoutUnblocksPromptly() async throws {
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: MockNetworkPathMonitor())

        let finishedFlag = CompletionFlag()
        let waiter = Task { () -> Result<Void, Error> in
            let result: Result<Void, Error>
            do {
                try await client.waitForWelcomeForTesting(timeout: .milliseconds(50))
                result = .success(())
            } catch {
                result = .failure(error)
            }
            await finishedFlag.mark()
            return result
        }

        // Bound the test by polling a flag instead of awaiting the waiter:
        // pre-fix, the timeout child throws but the group then blocks awaiting
        // the cancelled welcome child (whose continuation ignores
        // cancellation), so awaiting `waiter` directly would hang the test.
        let finished = await finishedFlag.poll(attempts: 500, interval: .milliseconds(10))
        XCTAssertTrue(finished, "welcome wait should unblock promptly once its timeout passes")
        guard finished else {
            waiter.cancel()
            return
        }

        let result = await waiter.value
        guard case .failure(let error) = result else {
            return XCTFail("expected the timeout error, got success")
        }
        guard case HelixError.networkError(let message) = error else {
            return XCTFail("expected HelixError.networkError, got \(error)")
        }
        XCTAssertEqual(message, "Timed out waiting for EventSub session_welcome")
    }

    func test_welcomeWaitUnblocksWhenCancelled() async throws {
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: MockNetworkPathMonitor())

        let finishedFlag = CompletionFlag()
        let waiter = Task { () -> Result<Void, Error> in
            let result: Result<Void, Error>
            do {
                try await client.waitForWelcomeForTesting(timeout: .seconds(60))
                result = .success(())
            } catch {
                result = .failure(error)
            }
            await finishedFlag.mark()
            return result
        }

        // Deterministic ordering: only cancel once the continuation is parked.
        while await !(client.hasWelcomeWaiterForTesting) {
            await Task.yield()
        }
        waiter.cancel()

        // Pre-fix, cancellation never resumed the parked continuation, so the
        // wait stayed blocked for the full 60s timeout (this is the same
        // mechanism connect(timeout:)'s deadline relies on).
        let finished = await finishedFlag.poll(attempts: 500, interval: .milliseconds(10))
        XCTAssertTrue(finished, "cancelling the welcome wait should unblock it promptly")
        guard finished else { return }

        let result = await waiter.value
        guard case .failure(let error) = result else {
            return XCTFail("expected CancellationError, got success")
        }
        XCTAssertTrue(error is CancellationError, "expected CancellationError, got \(error)")
        // The parked continuation must have been cleared, not abandoned.
        let stillParked = await client.hasWelcomeWaiterForTesting
        XCTAssertFalse(stillParked)
    }

    func test_welcomeDeliveryResumesWait() async throws {
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: MockNetworkPathMonitor())

        let waiter = Task { try await client.waitForWelcomeForTesting(timeout: .seconds(60)) }
        while await !(client.hasWelcomeWaiterForTesting) {
            await Task.yield()
        }

        await client.deliverWelcomeForTesting()
        // Must return promptly and without error — the success path is
        // cancellation-responsive by construction, so awaiting directly is safe.
        try await waiter.value
        let stillParked = await client.hasWelcomeWaiterForTesting
        XCTAssertFalse(stillParked)
    }

    /// A later connect attempt SUPERSEDES the stored welcome continuation
    /// (the first waiter fails with "Superseded…"). Cancelling the first,
    /// already-superseded wait must never tear down the second attempt's
    /// parked wait — the cancellation handler is keyed to its own wait's
    /// identity token.
    func test_cancellingSupersededWaitDoesNotKillActiveWait() async throws {
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: MockNetworkPathMonitor())

        let first = Task { () -> Result<Void, Error> in
            do {
                try await client.waitForWelcomeForTesting(timeout: .seconds(60))
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        while await !(client.hasWelcomeWaiterForTesting) {
            await Task.yield()
        }

        // The second wait supersedes the first: the first resumes with the
        // "Superseded" error in the same actor stretch that stores the
        // second's continuation, so once `first` finishes the second wait is
        // definitely the one parked.
        let second = Task { try await client.waitForWelcomeForTesting(timeout: .seconds(60)) }

        let firstResult = await first.value
        guard case .failure(let error) = firstResult else {
            return XCTFail("expected the superseded error, got success")
        }
        guard case HelixError.networkError(let message) = error else {
            return XCTFail("expected HelixError.networkError, got \(error)")
        }
        XCTAssertEqual(message, "Superseded EventSub connection attempt")

        // Cancel the finished first waiter and give any stale cancellation
        // work a chance to land on the actor — the second wait must survive.
        first.cancel()
        for _ in 0..<20 { await Task.yield() }
        let secondStillParked = await client.hasWelcomeWaiterForTesting
        XCTAssertTrue(secondStillParked, "stale cancellation must not resume the superseding attempt's wait")

        await client.deliverWelcomeForTesting()
        try await second.value
    }
}

// MARK: - Test helpers

/// Minimal completion flag that tests can poll with a deadline, so a
/// regression that re-introduces an unbounded hang fails the test after ~5s
/// instead of wedging the whole test run.
private actor CompletionFlag {
    private var isSet = false

    func mark() { isSet = true }

    func poll(attempts: Int, interval: Duration) async -> Bool {
        for _ in 0..<attempts {
            if isSet { return true }
            try? await Task.sleep(for: interval)
        }
        return isSet
    }
}

private func makeDummyAPI() -> HelixClient {
    HelixClient(
        auth: TwitchAuth(
            oauthClient: TwitchOAuthClient(clientID: "client-id", clientSecret: nil, httpClient: URLSessionHTTPClient()),
            tokenStore: InMemoryTokenStore()
        ),
        clientID: "client-id"
    )
}
