import Foundation

/// Fans values out to any number of `AsyncStream` consumers.
///
/// Each `makeStream` call returns an independent stream that receives every
/// value sent after it was created (optionally filtered and transformed), so
/// consumers don't split values between them, and one consumer cancelling (a
/// SwiftUI `.task` whose view goes away) doesn't end delivery for anyone else
/// or for consumers created later.
///
/// While there are no consumers at all, values are kept in a backlog, bounded
/// by `backlogPolicy` and by age (`maximumBacklogAge`), and handed to the next
/// consumer that replays the backlog, matching what a single buffered
/// `AsyncStream` did for a consumer that started iterating late. The backlog
/// is emptied as soon as any consumer registers: once one exists, values it
/// doesn't want are dropped rather than kept for later consumers, which would
/// otherwise receive stale values long after the fact. With `replaysLatest`, a
/// consumer that receives nothing from the backlog first receives the most
/// recent value.
///
/// Lock-protected rather than an actor so a `nonisolated` property can create
/// streams synchronously.
final class AsyncBroadcaster<Element: Sendable>: @unchecked Sendable {
    private struct Consumer {
        /// Yields the value if this consumer wants it; returns whether it did.
        let deliver: (Element) -> Bool
        let finish: () -> Void
    }

    private let lock = NSLock()
    private let bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy
    private let backlogPolicy: AsyncStream<Element>.Continuation.BufferingPolicy
    private let replaysLatest: Bool
    private let maximumBacklogAge: Duration
    private let now: @Sendable () -> ContinuousClock.Instant

    private var consumers: [UInt64: Consumer] = [:]
    private var nextID: UInt64 = 0
    private var backlog: [(value: Element, sentAt: ContinuousClock.Instant)] = []
    private var latest: Element?
    private var isFinished = false

    /// - Parameters:
    ///   - bufferingPolicy: Buffering for each consumer's stream.
    ///   - backlogPolicy: Bound on values kept while no consumer wants them.
    ///   - replaysLatest: Whether a new consumer starts with the most recent value.
    ///   - maximumBacklogAge: How long a backlogged value is kept.
    ///   - now: The clock reading; tests inject one to age the backlog.
    init(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy,
        backlogPolicy: AsyncStream<Element>.Continuation.BufferingPolicy,
        replaysLatest: Bool,
        maximumBacklogAge: Duration = .seconds(30),
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.bufferingPolicy = bufferingPolicy
        self.backlogPolicy = backlogPolicy
        self.replaysLatest = replaysLatest
        self.maximumBacklogAge = maximumBacklogAge
        self.now = now
    }

    /// The most recently sent value, when `replaysLatest` is enabled.
    var latestValue: Element? {
        withLock { latest }
    }

    /// The number of consumers currently registered.
    var consumerCount: Int {
        withLock { consumers.count }
    }

    /// Returns a new stream that receives every value from now on (plus any
    /// backlog, or the latest value when replaying).
    func makeStream() -> AsyncStream<Element> {
        makeStream { $0 }
    }

    /// Returns a new stream of `transform`'s non-`nil` results for values sent
    /// from now on. Values `transform` maps to `nil` are not this consumer's.
    ///
    /// - Parameter replayingBacklog: Whether the stream starts with the values
    ///   backlogged while there were no consumers. Pass `false` for filtered
    ///   streams, which are meant to see only what is sent after they exist.
    func makeStream<Output: Sendable>(
        replayingBacklog: Bool = true,
        _ transform: @escaping @Sendable (Element) -> Output?
    ) -> AsyncStream<Output> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Output.self,
            bufferingPolicy: convertBufferingPolicy(bufferingPolicy)
        )
        let consumer = Consumer(
            deliver: { value in
                guard let output = transform(value) else { return false }
                continuation.yield(output)
                return true
            },
            finish: { continuation.finish() }
        )
        let id: UInt64? = withLock {
            guard !isFinished else { return nil }
            // Hand over the (recent) backlogged values this consumer wants, in
            // order. The backlog exists only while there are no consumers, so
            // it ends here either way.
            pruneBacklog()
            var receivedBacklog = false
            if replayingBacklog {
                for entry in backlog where consumer.deliver(entry.value) {
                    receivedBacklog = true
                }
            }
            backlog.removeAll()
            if !receivedBacklog, replaysLatest, let latest {
                _ = consumer.deliver(latest)
            }
            nextID &+= 1
            consumers[nextID] = consumer
            return nextID
        }
        guard let id else {
            continuation.finish()
            return stream
        }
        continuation.onTermination = { [weak self] _ in
            self?.removeConsumer(id)
        }
        return stream
    }

    /// Sends `value` to every consumer that wants it, or to the backlog when
    /// there are no consumers.
    func yield(_ value: Element) {
        withLock {
            guard !isFinished else { return }
            if replaysLatest {
                latest = value
            }
            guard !consumers.isEmpty else {
                appendToBacklog(value)
                return
            }
            for consumer in consumers.values {
                _ = consumer.deliver(value)
            }
        }
    }

    /// Ends every stream; streams created afterwards finish immediately.
    func finish() {
        let finishing: [Consumer] = withLock {
            isFinished = true
            backlog.removeAll()
            let current = Array(consumers.values)
            consumers.removeAll()
            return current
        }
        // Outside the lock: finishing runs onTermination, which takes it.
        for consumer in finishing {
            consumer.finish()
        }
    }

    private func removeConsumer(_ id: UInt64) {
        withLock {
            _ = consumers.removeValue(forKey: id)
        }
    }

    /// Caller holds the lock.
    private func appendToBacklog(_ value: Element) {
        pruneBacklog()
        let entry = (value: value, sentAt: now())
        switch backlogPolicy {
        case .unbounded:
            backlog.append(entry)
        case .bufferingOldest(let limit):
            if backlog.count < limit {
                backlog.append(entry)
            }
        case .bufferingNewest(let limit):
            guard limit > 0 else { return }
            backlog.append(entry)
            if backlog.count > limit {
                backlog.removeFirst(backlog.count - limit)
            }
        @unknown default:
            backlog.append(entry)
        }
    }

    /// Drops backlogged values older than `maximumBacklogAge`. Caller holds
    /// the lock.
    private func pruneBacklog() {
        let cutoff = now() - maximumBacklogAge
        if let firstRecent = backlog.firstIndex(where: { $0.sentAt >= cutoff }) {
            backlog.removeFirst(firstRecent)
        } else {
            backlog.removeAll()
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// Carries a buffering policy over to a stream of a different element type.
func convertBufferingPolicy<From, To>(
    _ policy: AsyncStream<From>.Continuation.BufferingPolicy
) -> AsyncStream<To>.Continuation.BufferingPolicy {
    switch policy {
    case .unbounded:
        return .unbounded
    case .bufferingOldest(let limit):
        return .bufferingOldest(limit)
    case .bufferingNewest(let limit):
        return .bufferingNewest(limit)
    @unknown default:
        return .unbounded
    }
}
