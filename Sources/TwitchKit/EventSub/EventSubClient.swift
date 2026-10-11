import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "eventsub")

/// Minimal seam over `URLSessionWebSocketTask` — just the three members
/// ``EventSubClient`` actually uses — so tests can drive the client with a
/// scripted fake socket instead of the network.
///
/// `AnyObject` is required, not stylistic: the client compares sockets by
/// identity (`===`) to reject stale callbacks from superseded connections,
/// and keys its receive loops by `ObjectIdentifier`. Value-typed conformers
/// would silently break both.
public protocol EventSubWebSocket: AnyObject, Sendable {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func receive() async throws -> URLSessionWebSocketTask.Message
}

// Same-module conformance of the real socket type to our own protocol.
// `resume()` is inherited from `URLSessionTask`; `cancel(with:reason:)` and
// the async `receive()` are `URLSessionWebSocketTask`'s own API — all three
// match the protocol requirements exactly, so the extension body is empty.
extension URLSessionWebSocketTask: EventSubWebSocket {}

public actor EventSubClient {
    /// Stream of parsed events — initialized once, consumers iterate without actor hop.
    public nonisolated let events: AsyncStream<EventSubEvent>
    private let eventsContinuation: AsyncStream<EventSubEvent>.Continuation

    /// Stream of connection-state transitions, suitable for driving UI such as a
    /// "Reconnecting…" indicator.
    ///
    /// Single-consumer (like ``events``): exactly one iterator consumes this stream,
    /// and there is no value replay for late subscribers. Begin iterating
    /// *before/around* ``connect(timeout:)`` so you observe the initial
    /// `.connecting`/`.connected` transitions.
    public nonisolated let connectionState: AsyncStream<ConnectionState>
    private let connectionStateContinuation: AsyncStream<ConnectionState>.Continuation
    private var lastEmittedState: ConnectionState?

    private let api: HelixClient
    private let isLive: @Sendable () async -> Bool
    private let pathMonitor: NetworkPathMonitoring
    private var pathMonitorTask: Task<Void, Never>?
    private var isNetworkAvailable = true   // optimistic until told otherwise

    private let socketFactory: @Sendable (URL) -> any EventSubWebSocket
    // JSONDecoder is not Sendable, but actor isolation serializes all access;
    // caching one here avoids two decoder allocations per received message
    // (the envelope pass in handleMessage and the typed notification pass).
    private let messageDecoder = JSONDecoder.twitch()
    private var webSocketTask: (any EventSubWebSocket)?
    private var sessionId: String?
    private var pendingSubscriptionDeletes: Set<String> = []
    private var receiveTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var keepaliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var keepaliveDeadline: ContinuousClock.Instant?
    private var keepaliveTimeout: Int = 10
    private var reconnectAttempts: Int = 0
    private var shouldReconnect = false
    private var isConnecting = false
    private var desiredSubscriptions: Set<EventSubSubscription> = []
    /// The record id `subscribe()` returned for each desired subscription.
    /// Kept across reconnects, even though re-creating a subscription gives it
    /// a new id, so callers can always unsubscribe with the id they were given.
    private var desiredSubscriptionsById: [String: EventSubSubscription] = [:]
    /// Record ids of subscriptions created on the current session.
    private var activeSubscriptionsById: [String: EventSubSubscription] = [:]
    private var seenMessageIds: Set<String> = []
    private var seenMessageIdOrder: [String] = []

    private static let websocketURL = URL(string: "wss://eventsub.wss.twitch.tv/ws")!

    /// Bound on the duplicate-suppression cache (`seenMessageIds`). The cache
    /// deliberately SURVIVES reconnects — Twitch replays notifications across
    /// them within its redelivery window — and is evicted FIFO at this size,
    /// so it never grows unbounded on a long-lived connection. Only an
    /// explicit `disconnect()` clears it.
    private static let maxSeenMessageIds = 4_096

    /// Creates an EventSub WebSocket client.
    ///
    /// - Parameters:
    ///   - api: Helix client used to create (and re-create) subscriptions.
    ///   - isLive: Tunes the reconnect ladder. **A constant `{ false }` ladder
    ///     GIVES UP**: after 5 failed attempts (~31s of cumulative backoff) the
    ///     client emits `.disconnected` and parks — it will not retry again
    ///     until the network path drops and returns (which resets the ladder)
    ///     or `connect()` is called again. Supply a closure that returns `true`
    ///     while the channel is live to get the persistent ladder that retries
    ///     forever with a short, 5s-capped backoff.
    ///   - pathMonitor: Network-path monitor driving path-aware reconnects.
    ///   - socketFactory: Creates the WebSocket for a given URL. Defaults to
    ///     `URLSession.shared.webSocketTask(with:)`; tests inject fakes here.
    ///   - eventBufferingPolicy: Buffering policy for the ``events`` stream.
    public init(
        api: HelixClient,
        isLive: @escaping @Sendable () async -> Bool,
        pathMonitor: NetworkPathMonitoring = NWPathNetworkMonitor(),
        socketFactory: @escaping @Sendable (URL) -> any EventSubWebSocket = { URLSession.shared.webSocketTask(with: $0) },
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000)
    ) {
        self.api = api
        self.isLive = isLive
        self.pathMonitor = pathMonitor
        self.socketFactory = socketFactory
        (events, eventsContinuation) = AsyncStream.makeStream(
            of: EventSubEvent.self,
            bufferingPolicy: eventBufferingPolicy
        )
        (connectionState, connectionStateContinuation) = AsyncStream.makeStream(of: ConnectionState.self)
    }

    deinit {
        reconnectTask?.cancel()
        pathMonitorTask?.cancel()
        pathMonitor.cancel()
        for task in receiveTasks.values {
            task.cancel()
        }
        keepaliveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        welcomeContinuation?.resume(throwing: HelixError.networkError("EventSub client deallocated"))
        eventsContinuation.finish()
        connectionStateContinuation.finish()
    }

    // MARK: - Public

    /// Continuation used to make connect() wait for session_welcome before returning.
    private var welcomeContinuation: CheckedContinuation<Void, Error>?

    /// Monotonic counter handing each welcome wait a unique identity token.
    private var nextWelcomeWaitID: UInt64 = 0

    /// Identity of the wait whose continuation is currently stored in
    /// `welcomeContinuation`. A cancellation handler may only tear down its
    /// OWN wait — a later attempt can supersede the stored continuation, and a
    /// stale cancellation must not kill the newer attempt's wait.
    private var welcomeWaitID: UInt64 = 0

    /// Test seam: replaces the socket-opening body of a connect() attempt
    /// so the connect-coalescing logic can be exercised without any socket
    /// at all — it bypasses even the `socketFactory` seam (see
    /// EventSubConnectionStateTests). Always nil in production.
    private var connectBodyForTesting: (@Sendable () async throws -> Void)?

    /// Internal, for tests only — see `connectBodyForTesting`.
    func setConnectBodyForTesting(_ body: @escaping @Sendable () async throws -> Void) {
        connectBodyForTesting = body
    }

    /// Internal, for tests only — true while a connect() attempt is in flight.
    var isConnectingForTesting: Bool { isConnecting }

    /// Internal, for tests only — drives the private welcome-wait machinery
    /// directly, since `connectBodyForTesting` replaces the whole socket-open
    /// body and therefore never reaches it (see EventSubLifecycleTests).
    func waitForWelcomeForTesting(timeout: Duration) async throws {
        try await waitForWelcome(timeout: timeout)
    }

    /// Internal, for tests only — resumes the parked welcome wait the way the
    /// session_welcome handler does (mechanics only; no session state is set).
    func deliverWelcomeForTesting() {
        welcomeContinuation?.resume()
        welcomeContinuation = nil
    }

    /// Internal, for tests only — true while a welcome wait is parked.
    var hasWelcomeWaiterForTesting: Bool { welcomeContinuation != nil }

    /// Internal, for tests only — arms the keepalive watchdog the way a
    /// session_welcome/session_keepalive message does.
    func armKeepaliveForTesting() {
        updateKeepaliveDeadline()
    }

    /// The in-flight connect() attempt, if any. One shared client serves
    /// every consumer on an account (e.g. one chat session per open
    /// channel), so a second connect() landing while the first is
    /// mid-handshake is normal operation — those callers await this task
    /// and share its outcome instead of erroring.
    private var inFlightConnect: Task<Void, Error>?

    public func connect(timeout: Duration = .seconds(15)) async throws {
        if sessionId != nil {
            return
        }
        // Coalesce concurrent callers onto the in-flight attempt: they
        // succeed together or fail with the same underlying error.
        if let inFlightConnect {
            try await inFlightConnect.value
            return
        }

        startConnectionLifecycle()
        isConnecting = true
        // Unstructured Task (inheriting this actor's isolation) so the
        // attempt's lifetime is owned by the client, not the first
        // caller — a cancelled initiator must not tear the handshake out
        // from under the coalesced waiters.
        let attempt = Task {
            if let connectBodyForTesting {
                try await connectBodyForTesting()
            } else {
                try await openConnection(to: Self.websocketURL, resetReconnectAttempts: true, timeout: timeout)
            }
        }
        inFlightConnect = attempt
        defer {
            inFlightConnect = nil
            isConnecting = false
        }
        try await attempt.value
    }

    /// Marks the client as intending to be connected and begins path monitoring,
    /// emitting `.connecting`. `connect()` calls this before opening the socket;
    /// it is the seam that ties network monitoring to an intended-connected lifecycle.
    func startConnectionLifecycle() {
        shouldReconnect = true
        emit(.connecting)
        startPathMonitorIfNeeded()
    }

    // MARK: - Connection State

    /// Emits a connection state, deduping so rapid flaps don't spam identical states.
    private func emit(_ state: ConnectionState) {
        guard state != lastEmittedState else { return }
        lastEmittedState = state
        connectionStateContinuation.yield(state)
    }

    // MARK: - Network Path Monitoring

    private func startPathMonitorIfNeeded() {
        guard pathMonitorTask == nil else { return }
        pathMonitor.start()
        // Capture the (Sendable) monitor itself, not the client, to iterate
        // the never-ending update stream: a single `guard let self` before
        // the loop would pin the client alive while suspended on the stream,
        // making deinit unreachable. Instead, self is re-acquired per update,
        // so a strong reference exists only while one update is handled.
        pathMonitorTask = Task { [weak self, pathMonitor] in
            for await status in pathMonitor.pathUpdates {
                guard let self else { return }
                await self.handlePathStatus(status)
            }
        }
    }

    private func handlePathStatus(_ status: NetworkPathStatus) {
        switch status {
        case .unsatisfied:
            isNetworkAvailable = false
            // Stop hammering a dead network: cancel the in-flight backoff sleep.
            reconnectTask?.cancel()
            reconnectTask = nil
            if sessionId == nil { emit(.waitingForNetwork) }
        case .satisfied:
            let wasOffline = !isNetworkAvailable
            isNetworkAvailable = true
            // Reconnect immediately if we *want* to be connected but aren't.
            if wasOffline, shouldReconnect, sessionId == nil {
                reconnectAttempts = 0           // reset backoff — restore is "attempt 1"
                reconnectTask?.cancel()
                emit(.reconnecting)
                reconnectTask = makeReconnectTask()
            }
        }
    }

    private func openConnection(
        to url: URL,
        resetReconnectAttempts: Bool,
        timeout: Duration
    ) async throws {
        if sessionId != nil {
            return
        }
        logger.info("🔌 EventSub: connecting to \(url.absoluteString)")
        let task = socketFactory(url)
        webSocketTask = task
        task.resume()
        if resetReconnectAttempts {
            reconnectAttempts = 0
        }
        startReceiveLoop(for: task)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.waitForWelcome() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw HelixError.networkError("Timed out waiting for EventSub session_welcome")
                }
                defer { group.cancelAll() }
                try await group.next()
            }
        } catch {
            cleanupFailedConnection(task: task, error: error)
            throw error
        }
    }

    public func disconnect() async {
        logger.info("🔌 EventSub: disconnecting")
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        pathMonitorTask?.cancel()
        pathMonitorTask = nil
        pathMonitor.cancel()
        emit(.disconnected)
        cancelReceiveTasks()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        keepaliveDeadline = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        sessionId = nil
        activeSubscriptionsById.removeAll()
        pendingSubscriptionDeletes.removeAll()
        clearSeenMessageIds()
        welcomeContinuation?.resume(throwing: HelixError.networkError("EventSub disconnected"))
        welcomeContinuation = nil
    }

    @discardableResult
    public func subscribe(_ subscription: EventSubSubscription) async throws -> EventSubSubscriptionRecord {
        let record = try await createSubscription(subscription)
        desiredSubscriptions.insert(subscription)
        desiredSubscriptionsById[record.id] = subscription
        return record
    }

    @discardableResult
    public func subscribe(type: String, version: String, condition: [String: String]) async throws -> EventSubSubscriptionRecord {
        try await subscribe(EventSubSubscription(type: type, version: version, condition: condition))
    }

    /// Deletes a subscription by id.
    ///
    /// Accepts the id `subscribe()` returned, even after reconnects have
    /// re-created the subscription under a new id: the client resolves it and
    /// deletes the live subscription. Ids the client doesn't know (for
    /// example from `fetchEventSubSubscriptionsPage`) are deleted as given.
    public func unsubscribe(id: String) async throws {
        guard let subscription = activeSubscriptionsById[id] ?? desiredSubscriptionsById[id] else {
            try await api.deleteEventSubSubscription(id: id)
            return
        }
        try await removeSubscription(subscription, alsoDeleting: id)
    }

    public func unsubscribe(_ subscription: EventSubSubscription) async throws {
        try await removeSubscription(subscription, alsoDeleting: nil)
    }

    /// Stops wanting `subscription` and deletes its live record(s).
    ///
    /// The subscription is forgotten before the first await, so a resubscribe
    /// round in flight deletes what it creates instead of recording it. If a
    /// delete fails, the state for the records still live on Twitch is
    /// restored so the caller can retry.
    private func removeSubscription(_ subscription: EventSubSubscription, alsoDeleting extraID: String?) async throws {
        let wasDesired = desiredSubscriptions.contains(subscription)
        let subscribedIDs = desiredSubscriptionsById.filter { $0.value == subscription }.map(\.key)
        let activeIDs = Set(activeSubscriptionsById.filter { $0.value == subscription }.map(\.key))
        forget(subscription)

        var idsToDelete = activeIDs
        if let extraID {
            idsToDelete.insert(extraID)
        }

        var failedIDs: [String] = []
        var firstError: (any Error)?
        for id in idsToDelete.sorted() {
            do {
                try await api.deleteEventSubSubscription(id: id)
            } catch HelixError.notFound {
                // Already gone, e.g. its session ended.
            } catch {
                failedIDs.append(id)
                firstError = firstError ?? error
            }
        }

        if let firstError {
            if wasDesired {
                desiredSubscriptions.insert(subscription)
            }
            for id in subscribedIDs {
                desiredSubscriptionsById[id] = subscription
            }
            for id in failedIDs where activeIDs.contains(id) {
                activeSubscriptionsById[id] = subscription
            }
            throw firstError
        }
    }

    /// Removes every local record of `subscription`, so reconnects no longer
    /// re-create it.
    private func forget(_ subscription: EventSubSubscription) {
        desiredSubscriptions.remove(subscription)
        desiredSubscriptionsById = desiredSubscriptionsById.filter { $0.value != subscription }
        activeSubscriptionsById = activeSubscriptionsById.filter { $0.value != subscription }
    }

    /// Twitch has already deleted a revoked subscription, and the reasons it
    /// revokes one (authorization revoked, user removed, version removed, …)
    /// mean re-creating it would only fail. Forget it so reconnects don't try.
    private func forgetRevokedSubscription(_ revocation: EventSubRevocation) {
        let subscription = activeSubscriptionsById[revocation.id]
            ?? desiredSubscriptionsById[revocation.id]
            ?? desiredSubscriptions.first {
                $0.type == revocation.type && $0.version == revocation.version && $0.condition == revocation.condition
            }
        activeSubscriptionsById.removeValue(forKey: revocation.id)
        if let subscription {
            forget(subscription)
        }
    }

    private func createSubscription(_ subscription: EventSubSubscription) async throws -> EventSubSubscriptionRecord {
        guard let sessionId else {
            logger.error("❌ EventSub: no session ID — can't subscribe")
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "No EventSub session — call connect() first")
            )
        }
        logger.info("📡 EventSub: subscribing to \(subscription.type) v\(subscription.version) with session \(sessionId)")
        let record = try await api.createEventSubSubscription(
            type: subscription.type,
            version: subscription.version,
            condition: subscription.condition,
            sessionId: sessionId,
            isBatchingEnabled: subscription.isBatchingEnabled
        )
        activeSubscriptionsById[record.id] = subscription
        logger.info("✅ EventSub: subscribed to \(subscription.type)")
        return record
    }

    // MARK: - Receive Loop

    private func startReceiveLoop(for task: any EventSubWebSocket) {
        logger.info("🔵 EventSub: starting receive loop")
        // `as AnyObject` is redundant at runtime (the protocol is
        // class-constrained) but keeps ObjectIdentifier's AnyObject
        // initializer resolving against the existential on older compilers.
        let taskId = ObjectIdentifier(task as AnyObject)
        receiveTasks[taskId]?.cancel()
        receiveTasks[taskId] = Task { [weak self, weak task] in
            // Re-acquire self per message: receive() can suspend for the whole
            // life of the socket, and holding the client across that await
            // would keep it alive forever (deinit unreachable). The strong
            // reference exists only while one message is dispatched.
            while !Task.isCancelled {
                guard let task else { return }
                do {
                    let message = try await task.receive()
                    guard let self else { return }
                    await self.handleMessage(message, from: task)
                } catch {
                    logger.error("❌ EventSub: receive error: \(error.localizedDescription)")
                    await self?.receiveLoopDidEnd(for: task, error: error)
                    return
                }
            }
        }
    }

    private func receiveLoopDidEnd(for task: any EventSubWebSocket, error: Error) {
        receiveTasks.removeValue(forKey: ObjectIdentifier(task as AnyObject))
        guard !Task.isCancelled else { return }
        guard webSocketTask === task else { return }
        handleDisconnect()
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message, from task: any EventSubWebSocket) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else {
            logger.warning("⚠️ EventSub: received non-string message")
            return
        }

        let envelope: EventSubEnvelope
        do {
            envelope = try messageDecoder.decode(EventSubEnvelope.self, from: data)
        } catch {
            // Error description is key paths only (safe to force public); the
            // raw payload prefix can carry user chat content, so keep it redacted.
            logger.warning("⚠️ EventSub: failed to decode message: \(eventSubDecodingErrorDescription(error), privacy: .public); JSON prefix: \(text.prefix(200), privacy: .private)")
            return
        }

        guard rememberMessageId(envelope.metadata.messageId) else {
            logger.debug("EventSub: ignoring duplicate message \(envelope.metadata.messageId)")
            return
        }

        switch envelope.metadata.messageType {
        case "session_welcome":
            sessionId = envelope.payload.session?.id
            keepaliveTimeout = envelope.payload.session?.keepaliveTimeoutSeconds ?? 10
            logger.info("🟢 EventSub: session_welcome — id=\(self.sessionId ?? "nil"), keepalive=\(self.keepaliveTimeout)s")
            updateKeepaliveDeadline()
            emit(.connected)
            // Resume connect() — caller was waiting for session ID
            welcomeContinuation?.resume()
            welcomeContinuation = nil

        case "session_keepalive":
            updateKeepaliveDeadline()

        case "notification":
            updateKeepaliveDeadline()
            let subType = envelope.metadata.subscriptionType ?? "unknown"
            logger.debug("EventSub notification: \(subType)")
            let event = parseNotificationEvent(type: subType, envelopeData: data)
            eventsContinuation.yield(event)

        case "session_reconnect":
            if webSocketTask === task,
               let newUrl = envelope.payload.session?.reconnectUrl,
               let url = URL(string: newUrl) {
                reconnectTask?.cancel()
                // [weak self] like every other stored task: a strong capture here
                // would pin the client between task creation and completion even
                // after the last external reference is dropped.
                reconnectTask = Task { [weak self] in
                    await self?.reconnectTo(url, replacing: task)
                }
            }

        case "revocation":
            if let revocation = envelope.payload.subscription {
                forgetRevokedSubscription(revocation)
                eventsContinuation.yield(.revocation(revocation))
            }

        default:
            break
        }
    }

    private func parseNotificationEvent(type: String, envelopeData: Data) -> EventSubEvent {
        EventSubEvent.decodeNotification(type: type, envelope: envelopeData, decoder: messageDecoder)
    }

    // MARK: - Keepalive

    private func updateKeepaliveDeadline() {
        keepaliveDeadline = ContinuousClock().now.advanced(by: .seconds(keepaliveTimeout + 5))
        guard keepaliveTask == nil else { return }

        // The watchdog loop lives in the Task closure — not in an
        // actor-isolated method — so the client is re-acquired per step and
        // never held across the sleep. (A `guard let self` wrapping the whole
        // loop would pin the client alive for the watchdog's entire life,
        // making deinit unreachable.) Each decision is computed on the actor
        // via optional chaining, so no strong binding outlives that one call.
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let step = await self?.keepaliveWatchdogStep() else { return }
                switch step {
                case .sleep(let deadline):
                    try? await ContinuousClock().sleep(until: deadline)
                case .expired:
                    await self?.keepaliveDidExpire()
                    return
                case .idle:
                    await self?.clearExitedKeepaliveTask()
                    return
                }
            }
        }
    }

    /// One decision of the keepalive watchdog. `.sleep` when the deadline is
    /// still ahead (keepalive/notification messages keep pushing it forward),
    /// `.expired` when it has passed, `.idle` when there is no deadline at all
    /// (the connection was torn down, so the watchdog should exit).
    private enum KeepaliveStep: Sendable {
        case sleep(until: ContinuousClock.Instant)
        case expired
        case idle
    }

    /// Computed on the actor so the watchdog Task reads a consistent deadline.
    private func keepaliveWatchdogStep() -> KeepaliveStep {
        guard let deadline = keepaliveDeadline else { return .idle }
        if ContinuousClock().now < deadline {
            return .sleep(until: deadline)
        }
        return .expired
    }

    /// The keepalive deadline passed without a message — treat the socket as
    /// dead. Runs on the actor from the watchdog Task; the cancellation guard
    /// closes the hop between step computation and this call: disconnect()
    /// may have cancelled this watchdog (and possibly armed a fresh one) in
    /// between, and a stale watchdog must not nil the new task or tear down
    /// the new connection.
    private func keepaliveDidExpire() {
        guard !Task.isCancelled else { return }
        keepaliveTask = nil
        handleDisconnect()
    }

    /// The watchdog observed a nil deadline and is exiting — drop our
    /// reference to it. Same stale-watchdog guard as `keepaliveDidExpire()`.
    private func clearExitedKeepaliveTask() {
        guard !Task.isCancelled else { return }
        keepaliveTask = nil
    }

    // MARK: - Reconnection

    private func reconnectTo(_ url: URL, replacing oldTask: any EventSubWebSocket) async {
        guard shouldReconnect, webSocketTask === oldTask else { return }
        let newTask = socketFactory(url)
        webSocketTask = newTask
        newTask.resume()
        startReceiveLoop(for: newTask)

        do {
            try await waitForWelcome(timeout: .seconds(15))
            oldTask.cancel(with: .normalClosure, reason: nil)
            cancelReceiveTask(for: oldTask)
        } catch {
            newTask.cancel(with: .goingAway, reason: nil)
            cancelReceiveTask(for: newTask)
            if webSocketTask === newTask {
                webSocketTask = oldTask
            }
            handleDisconnect()
        }
    }

    private func handleDisconnect() {
        logger.warning("⚠️ EventSub: disconnected")
        cancelReceiveTasks()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        keepaliveDeadline = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionId = nil
        activeSubscriptionsById.removeAll()
        pendingSubscriptionDeletes.removeAll()
        // Deliberately NOT clearing seenMessageIds: Twitch replays
        // notifications across reconnects within its redelivery window, and
        // wiping the cache here would let every replay through as a duplicate
        // event. The cache is bounded (4,096 ids), so surviving reconnects
        // costs nothing; only an explicit disconnect() tears it down.

        // If connect() is still waiting for session_welcome, fail it
        welcomeContinuation?.resume(throwing: HelixError.networkError("WebSocket disconnected before session_welcome"))
        welcomeContinuation = nil

        guard shouldReconnect else { return }
        if isNetworkAvailable {
            emit(.reconnecting)
            reconnectTask?.cancel()
            reconnectTask = makeReconnectTask()
        } else {
            emit(.waitingForNetwork)   // parked; handlePathStatus(.satisfied) will resume
        }
    }

    /// The reconnect ladder as a loop living in the Task closure — not in an
    /// actor-isolated method — for the same two reasons as the keepalive
    /// watchdog: a `Task { await attemptReconnect() }` would pin the client
    /// alive for the entire ladder (backoff sleeps included), making deinit
    /// unreachable while a reconnect is pending; and recursing on failure
    /// (the previous shape) grew an async frame per attempt, unbounded for
    /// live channels, which retry forever. Self is re-acquired per step and
    /// never held across the backoff sleep.
    private func makeReconnectTask() -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.nextReconnectDelay() else { return }
                try? await Task.sleep(for: delay)
                guard let finished = await self?.performReconnectAttempt() else { return }
                if finished { return }
            }
        }
    }

    /// Evaluates the reconnect gates and backoff ladder for the next attempt.
    /// Returns the delay to sleep before attempting, or `nil` to park/stop.
    private func nextReconnectDelay() async -> Duration? {
        guard shouldReconnect else { return nil }
        guard isNetworkAvailable else { emit(.waitingForNetwork); return nil }  // park

        let live = await isLive()
        reconnectAttempts += 1
        let decision = reconnectDecision(
            networkAvailable: isNetworkAvailable,
            shouldReconnect: shouldReconnect,
            isLive: live,
            attempt: reconnectAttempts
        )
        switch decision.action {
        case .attempt(let delay):
            return delay
        case .park(.attemptsExhausted) where sessionId != nil:
            // Connected, but re-creating subscriptions kept failing
            // transiently. The socket still works, so stop retrying without
            // reporting a disconnect that didn't happen; the subscriptions
            // that are still missing are re-created on the next reconnect.
            logger.warning("⚠️ EventSub: giving up re-creating subscriptions on this session")
            return nil
        case .park(.attemptsExhausted):
            // Terminal-state contract: the ladder is giving up, so the
            // connectionState stream must not end on a stale `.reconnecting`
            // — consumers drive "Reconnecting…" UI off that value and would
            // show it forever. `.disconnected` is honest: nothing further
            // happens without outside help (a network drop-and-restore resets
            // the ladder via handlePathStatus, or the caller reconnects).
            emit(.disconnected)
            return nil
        case .park:
            // stopRequested / networkUnavailable are handled by the guards
            // above before the decision is computed; if one slips through,
            // parking silently matches those guards' behavior.
            return nil
        }
    }

    /// One post-backoff connection attempt. Returns `true` when the ladder
    /// should stop looping — either the connection (and resubscribe) succeeded
    /// or the client no longer wants to reconnect — and `false` to retry.
    private func performReconnectAttempt() async -> Bool {
        guard shouldReconnect, !Task.isCancelled else { return true }

        do {
            try await openConnection(to: Self.websocketURL, resetReconnectAttempts: false, timeout: .seconds(15))
            try await resubscribeAll()
            return true
        } catch {
            return false
        }
    }

    private func waitForWelcome() async throws {
        // Cancellation-aware: connect()'s timeout works by cancelling this
        // wait via the task group, and the group must then AWAIT the cancelled
        // child — a continuation that ignores cancellation would block the
        // group until a socket error or late welcome arrived (potentially
        // minutes past the deadline).
        nextWelcomeWaitID &+= 1
        let waitID = nextWelcomeWaitID
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Already cancelled? Then onCancel has ALREADY run — it fires
                // immediately for an already-cancelled task, before this body
                // — and found nothing to resume (our id wasn't stored yet), so
                // parking here would hang forever. Resume right away, and
                // crucially WITHOUT superseding a newer attempt's parked wait:
                // a dead wait has no business tearing down a live one.
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                welcomeContinuation?.resume(throwing: HelixError.networkError("Superseded EventSub connection attempt"))
                welcomeContinuation = continuation
                welcomeWaitID = waitID
                // Cancellation landing after the check above is covered by
                // onCancel: its hop onto the actor can only run once this
                // synchronous body has finished, i.e. with our continuation
                // stored under our id. Re-check anyway as belt-and-braces —
                // cancelWelcomeWait's guards make a second call a no-op, so
                // double-resume is impossible.
                if Task.isCancelled {
                    cancelWelcomeWait(id: waitID)
                }
            }
        } onCancel: {
            // Nonisolated — hop to the actor. If this wait already resumed
            // (welcome arrived, disconnect, or a superseding attempt), the
            // identity + presence guards in cancelWelcomeWait make it a no-op.
            Task { await self.cancelWelcomeWait(id: waitID) }
        }
    }

    /// Resumes the parked welcome wait with `CancellationError`, but only if
    /// it is still the wait identified by `id` and still parked. Every other
    /// resume site nils `welcomeContinuation` after resuming, so a late or
    /// stale cancellation falls through both guards harmlessly.
    private func cancelWelcomeWait(id: UInt64) {
        guard id == welcomeWaitID, let continuation = welcomeContinuation else { return }
        welcomeContinuation = nil
        continuation.resume(throwing: CancellationError())
    }

    private func waitForWelcome(timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.waitForWelcome() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw HelixError.networkError("Timed out waiting for EventSub session_welcome")
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    private func cleanupFailedConnection(task: any EventSubWebSocket, error: Error) {
        cancelReceiveTasks()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        keepaliveDeadline = nil
        task.cancel(with: .goingAway, reason: nil)
        if webSocketTask === task {
            webSocketTask = nil
        }
        sessionId = nil
        // seenMessageIds survives here for the same reason as in
        // handleDisconnect(): a failed attempt is usually followed by a
        // reconnect, and Twitch may replay notifications across it.
        welcomeContinuation?.resume(throwing: error)
        welcomeContinuation = nil
    }

    /// Records a message id in the dedup cache, returning `false` for
    /// duplicates. The cache spans reconnects (see `maxSeenMessageIds`).
    private func rememberMessageId(_ messageId: String) -> Bool {
        let insertResult = seenMessageIds.insert(messageId)
        guard insertResult.inserted else {
            return false
        }

        seenMessageIdOrder.append(messageId)
        let overflow = seenMessageIdOrder.count - Self.maxSeenMessageIds
        if overflow > 0 {
            for staleMessageId in seenMessageIdOrder.prefix(overflow) {
                seenMessageIds.remove(staleMessageId)
            }
            seenMessageIdOrder.removeFirst(overflow)
        }
        return true
    }

    private func clearSeenMessageIds() {
        seenMessageIds.removeAll(keepingCapacity: true)
        seenMessageIdOrder.removeAll(keepingCapacity: true)
    }

    /// Re-creates every desired subscription on the current (fresh) session.
    /// Only called from `performReconnectAttempt()`, after `openConnection`
    /// has succeeded — so `sessionId` is set and `activeSubscriptionsById`
    /// holds only subscriptions created on THIS session (`handleDisconnect()`
    /// cleared everything belonging to the dead one).
    ///
    /// A subscription Twitch rejects outright (see
    /// `isPermanentSubscriptionFailure`) is dropped and reported as
    /// `.subscriptionFailed`, and the round continues with the rest. Failures
    /// that affect every subscription alike (transport, 5xx, rate limits, an
    /// invalid token, the session ending) abort the round so the ladder
    /// retries it.
    private func resubscribeAll() async throws {
        try await retryPendingSubscriptionDeletes()
        // Skip anything already active: `createSubscription` records each
        // success immediately, so entries present here were created on the
        // current session by an earlier pass of this loop. Wiping the map and
        // re-creating everything (the previous shape) meant a mid-loop failure
        // retried already-created subscriptions next round — Twitch answers
        // those duplicates with 409s, wedging the ladder forever.
        for subscription in desiredSubscriptions where !activeSubscriptionsById.values.contains(subscription) {
            // The socket can drop mid-round; don't let createSubscription's
            // "no session" error read as a rejection of this subscription.
            guard let session = sessionId else {
                throw HelixError.networkError("EventSub session ended during resubscribe")
            }
            let record: EventSubSubscriptionRecord
            do {
                record = try await createSubscription(subscription)
            } catch HelixError.conflict {
                // 409 conflict: the subscription already exists on this
                // session (e.g. a previous pass created it but we lost the
                // response). It is live server-side; we just never learned its
                // record id, so there is nothing to store — treat it as
                // already-subscribed rather than failing the whole round.
                logger.warning("⚠️ EventSub: \(subscription.type) already subscribed on this session (409) — continuing")
                continue
            } catch let error as HelixError where Self.isPermanentSubscriptionFailure(error) {
                // A rejection that raced a session change may be about the old
                // session, not this subscription: let the ladder retry it.
                guard sessionId == session else { throw error }
                // Unsubscribed while the create was in flight: nothing to report.
                guard desiredSubscriptions.contains(subscription) else { continue }
                logger.error("❌ EventSub: Twitch rejected \(subscription.type) on resubscribe; dropping it: \(error.localizedDescription)")
                forget(subscription)
                eventsContinuation.yield(.subscriptionFailed(subscription, error))
                continue
            }
            // Reentrancy check: unsubscribe() may have run while the
            // create above was in flight (the actor suspends at every
            // await). Writing the record back would resurrect the
            // subscription locally and leak it live on Twitch's side —
            // undo the create instead of recording it.
            guard desiredSubscriptions.contains(subscription) else {
                pendingSubscriptionDeletes.insert(record.id)
                try await retryPendingSubscriptionDeletes()
                continue
            }
        }
    }

    /// Whether Twitch rejected one subscription in a way retrying can't fix:
    /// an invalid or retired type, version, or condition (400/422), a missing
    /// scope or authorization for it (401/403), or a user that no longer
    /// exists (404). An invalid-token 401 and a 400 about the WebSocket
    /// session concern every subscription, so the ladder retries those.
    static func isPermanentSubscriptionFailure(_ error: HelixError) -> Bool {
        switch error {
        case .badRequest(let apiError):
            !apiError.message.lowercased().contains("session")
        case .forbidden, .notFound, .unprocessable:
            true
        case .unauthorized(let apiError):
            !HelixClient.isTokenRejection(apiError)
        default:
            false
        }
    }

    /// Keep failed deletions addressable and retry them on the reconnect ladder.
    private func retryPendingSubscriptionDeletes() async throws {
        for id in pendingSubscriptionDeletes {
            do {
                try await api.deleteEventSubSubscription(id: id)
            } catch HelixError.notFound {
                // Twitch has already removed it.
            }
            pendingSubscriptionDeletes.remove(id)
            activeSubscriptionsById.removeValue(forKey: id)
        }
    }

    private func cancelReceiveTask(for task: any EventSubWebSocket) {
        receiveTasks.removeValue(forKey: ObjectIdentifier(task as AnyObject))?.cancel()
    }

    private func cancelReceiveTasks() {
        for task in receiveTasks.values {
            task.cancel()
        }
        receiveTasks.removeAll()
    }
}
