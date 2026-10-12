import XCTest
import Foundation
@testable import TwitchKit

/// Tests that network-path transitions drive the public `connectionState` stream.
///
/// These tests exercise the network-transition *logic* deterministically via a
/// scripted path monitor — no socket at all, not even a fake one (socket-driven
/// behavior lives in EventSubSocketTests) — and stop at `.reconnecting`, the
/// first post-restore emission, which is the behavior this feature owns.
final class EventSubConnectionStateTests: XCTestCase {

    func test_pathTransitionsDriveConnectionStateSequence() async throws {
        let mock = MockNetworkPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: mock)

        // Single-consumer: start iterating before driving transitions. The stream
        // buffers, so emissions made before the first `await next` are preserved.
        let collector = Task { () -> [ConnectionState] in
            var observed: [ConnectionState] = []
            for await state in client.connectionState {
                observed.append(state)
                if state == .reconnecting { break }
            }
            return observed
        }

        // Begin the path-aware lifecycle without opening a real socket.
        await client.startConnectionLifecycle()  // → .connecting

        mock.send(.satisfied)                     // already optimistic → no change
        mock.send(.unsatisfied)                   // → .waitingForNetwork
        mock.send(.satisfied)                     // network restored → .reconnecting

        let observed = await collector.value
        await client.disconnect()                 // stops the parked reconnect loop

        XCTAssertEqual(observed, [.connecting, .waitingForNetwork, .reconnecting])
    }

    func test_disconnectEmitsDisconnected() async throws {
        let mock = MockNetworkPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: mock)

        let collector = Task { () -> [ConnectionState] in
            var observed: [ConnectionState] = []
            for await state in client.connectionState {
                observed.append(state)
                if state == .disconnected { break }
            }
            return observed
        }

        await client.startConnectionLifecycle()  // → .connecting
        await client.disconnect()                 // → .disconnected

        let observed = await collector.value
        XCTAssertEqual(observed, [.connecting, .disconnected])
        XCTAssertTrue(mock.didCancel)
    }

    func test_lateConnectionStateObserverStartsWithCurrentState() async throws {
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: MockNetworkPathMonitor())
        XCTAssertEqual(client.currentConnectionState, .disconnected)

        let early = client.connectionState
        await client.startConnectionLifecycle()  // → .connecting

        // Subscribing after the transition still reports where the client is.
        let late = client.connectionState
        var earlyIterator = early.makeAsyncIterator()
        var lateIterator = late.makeAsyncIterator()
        let earlyFirst = await earlyIterator.next()
        let lateFirst = await lateIterator.next()
        XCTAssertEqual(earlyFirst, .connecting)
        XCTAssertEqual(lateFirst, .connecting)
        XCTAssertEqual(client.currentConnectionState, .connecting)

        await client.disconnect()
        XCTAssertEqual(client.currentConnectionState, .disconnected)
    }

    /// One EventSubClient is shared by every consumer on an account (one
    /// chat session per open channel) — so two consumers calling
    /// `connect()` near-simultaneously is NORMAL operation (e.g. swiping
    /// quickly between channel tabs at app start). The second caller must
    /// coalesce onto the in-flight attempt and share its outcome, not
    /// throw "EventSub connection already in progress".
    func test_concurrentConnectCoalescesInsteadOfThrowing() async throws {
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: MockNetworkPathMonitor())

        // Gate the fake connection attempt so the first connect() stays
        // in flight until the test releases it.
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        await client.setConnectBodyForTesting {
            var iterator = gate.makeAsyncIterator()
            _ = await iterator.next()
        }

        let first = Task { try await client.connect() }
        // Deterministic ordering: wait until the first attempt has
        // actually entered its in-flight window before the second call.
        while await !(client.isConnectingForTesting) {
            await Task.yield()
        }

        let second = Task { try await client.connect() }
        gateContinuation.yield(())
        gateContinuation.finish()

        try await first.value
        // Pre-coalescing this threw networkError("EventSub connection
        // already in progress").
        try await second.value

        await client.disconnect()
    }
}

// MARK: - Test doubles

/// A `NetworkPathMonitoring` whose updates are driven by the test.
final class MockNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    let pathUpdates: AsyncStream<NetworkPathStatus>
    private let continuation: AsyncStream<NetworkPathStatus>.Continuation
    private(set) var didStart = false
    private(set) var didCancel = false

    init() {
        (pathUpdates, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
    }

    func start() { didStart = true }
    func cancel() { didCancel = true; continuation.finish() }

    /// Drives a scripted path-status change.
    func send(_ status: NetworkPathStatus) { continuation.yield(status) }
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
