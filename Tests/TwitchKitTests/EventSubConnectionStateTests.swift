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
        let client = EventSubClient(api: makeDummyAPI(), shouldKeepReconnecting: { false }, pathMonitor: mock)

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

    func test_pathMonitoringResumesAfterDisconnectAndReconnect() async throws {
        let mock = MockNetworkPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), shouldKeepReconnecting: { false }, pathMonitor: mock)

        let collector = Task { () -> [ConnectionState] in
            var observed: [ConnectionState] = []
            for await state in client.connectionState {
                observed.append(state)
                if observed.count == 6 { break }
            }
            return observed
        }
        // A regression leaves the second session's path changes unobserved;
        // end the wait instead of hanging the run.
        let timeout = Task {
            try await Task.sleep(for: .seconds(10))
            collector.cancel()
        }

        await client.startConnectionLifecycle()   // → .connecting
        mock.send(.unsatisfied)                    // → .waitingForNetwork
        await waitForState(.waitingForNetwork, on: client)
        await client.disconnect()                  // → .disconnected

        // connect() again: the monitor restarts with a fresh stream, and the
        // client must be listening to it.
        await client.startConnectionLifecycle()    // → .connecting
        mock.send(.unsatisfied)                    // → .waitingForNetwork
        await waitForState(.waitingForNetwork, on: client)
        mock.send(.satisfied)                      // → .reconnecting

        let observed = await collector.value
        timeout.cancel()
        await client.disconnect()

        XCTAssertEqual(observed, [.connecting, .waitingForNetwork, .disconnected, .connecting, .waitingForNetwork, .reconnecting])
    }

    /// The update stream must be read right after `start()`, not later by
    /// the monitoring task: after a quick disconnect and connect, a late read
    /// gets the NEXT session's stream, and the cancelled task finishes it.
    func test_pathUpdatesAreReadWhenMonitoringStarts() async throws {
        let monitor = ReadRecordingPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), shouldKeepReconnecting: { false }, pathMonitor: monitor)
        let testTask = withUnsafeCurrentTask { $0?.hashValue }

        await client.startConnectionLifecycle()

        XCTAssertNotNil(testTask)
        XCTAssertEqual(monitor.readingTasks, [testTask], "pathUpdates must be read synchronously by startConnectionLifecycle()")
        await client.disconnect()
    }

    func test_nwPathMonitorReportsAgainAfterRestart() async throws {
        let monitor = NWPathNetworkMonitor()
        monitor.start()
        let first = await firstStatus(of: monitor.pathUpdates)
        monitor.cancel()
        XCTAssertNotNil(first)

        monitor.start()
        let second = await firstStatus(of: monitor.pathUpdates)
        monitor.cancel()
        XCTAssertNotNil(second, "a monitor started again after cancel() must report the path again")
    }

    func test_disconnectEmitsDisconnected() async throws {
        let mock = MockNetworkPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), shouldKeepReconnecting: { false }, pathMonitor: mock)

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
        let client = EventSubClient(api: makeDummyAPI(), shouldKeepReconnecting: { false }, pathMonitor: MockNetworkPathMonitor())
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
        let client = EventSubClient(api: makeDummyAPI(), shouldKeepReconnecting: { false }, pathMonitor: MockNetworkPathMonitor())

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
/// Restartable like `NWPathNetworkMonitor`: a start after a cancel begins a
/// new stream.
final class MockNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stream: AsyncStream<NetworkPathStatus>
    private var continuation: AsyncStream<NetworkPathStatus>.Continuation
    private var isCancelled = false
    private var startCount = 0
    private var cancelCount = 0

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
    }

    var pathUpdates: AsyncStream<NetworkPathStatus> { withLock { stream } }
    var didStart: Bool { withLock { startCount > 0 } }
    var didCancel: Bool { withLock { cancelCount > 0 } }

    func start() {
        withLock {
            startCount += 1
            if isCancelled {
                (stream, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
                isCancelled = false
            }
        }
    }

    func cancel() {
        withLock {
            cancelCount += 1
            isCancelled = true
            continuation.finish()
        }
    }

    /// Drives a scripted path-status change.
    func send(_ status: NetworkPathStatus) {
        let current = withLock { self.continuation }
        current.yield(status)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// A path monitor that records which task read `pathUpdates`.
private final class ReadRecordingPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private let stream: AsyncStream<NetworkPathStatus>
    private let continuation: AsyncStream<NetworkPathStatus>.Continuation
    private var readers: [Int?] = []

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
    }

    var readingTasks: [Int?] {
        lock.lock()
        defer { lock.unlock() }
        return readers
    }

    var pathUpdates: AsyncStream<NetworkPathStatus> {
        let reader = withUnsafeCurrentTask { $0?.hashValue }
        lock.lock()
        defer { lock.unlock() }
        readers.append(reader)
        return stream
    }

    func start() {}

    func cancel() {
        continuation.finish()
    }
}

/// The stream's first value, or nil if none arrives within ~5s.
private func firstStatus(of stream: AsyncStream<NetworkPathStatus>) async -> NetworkPathStatus? {
    let reader = Task { () -> NetworkPathStatus? in
        for await status in stream {
            return status
        }
        return nil
    }
    let timeout = Task {
        try await Task.sleep(for: .seconds(5))
        reader.cancel()
    }
    defer { timeout.cancel() }
    return await reader.value
}

/// Polls (~5s) until the client reports `state`.
private func waitForState(_ state: ConnectionState, on client: EventSubClient) async {
    for _ in 0..<500 {
        if client.currentConnectionState == state { return }
        try? await Task.sleep(for: .milliseconds(10))
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
