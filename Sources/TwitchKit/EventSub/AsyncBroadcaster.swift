import Foundation

/// Fans values out to any number of `AsyncStream` consumers.
///
/// Each `makeStream` call returns an independent stream that receives every
/// value sent after it was created (optionally filtered and transformed), so
/// consumers don't split values between them, and one consumer cancelling (a
/// SwiftUI `.task` whose view goes away) doesn't end delivery for anyone else
/// or for consumers created later.
///
/// A value that no current consumer wants is kept, bounded by `backlogPolicy`,
/// and handed to the next consumer that wants it, matching what a single
/// buffered `AsyncStream` did for a consumer that started iterating late. With
/// `replaysLatest`, a consumer that receives nothing from the backlog first
/// receives the most recent value.
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

    private var consumers: [UInt64: Consumer] = [:]
    private var nextID: UInt64 = 0
    private var backlog: [Element] = []
    private var latest: Element?
    private var isFinished = false

    /// - Parameters:
    ///   - bufferingPolicy: Buffering for each consumer's stream.
    ///   - backlogPolicy: Bound on values kept while no consumer wants them.
    ///   - replaysLatest: Whether a new consumer starts with the most recent value.
    init(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy,
        backlogPolicy: AsyncStream<Element>.Continuation.BufferingPolicy,
        replaysLatest: Bool
    ) {
        self.bufferingPolicy = bufferingPolicy
        self.backlogPolicy = backlogPolicy
        self.replaysLatest = replaysLatest
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
    func makeStream<Output: Sendable>(
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
            // Hand over the backlogged values this consumer wants, in order,
            // and keep the rest for consumers that want them.
            var remaining: [Element] = []
            var receivedBacklog = false
            for value in backlog {
                if consumer.deliver(value) {
                    receivedBacklog = true
                } else {
                    remaining.append(value)
                }
            }
            backlog = remaining
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
    /// none does.
    func yield(_ value: Element) {
        withLock {
            guard !isFinished else { return }
            if replaysLatest {
                latest = value
            }
            var delivered = false
            for consumer in consumers.values where consumer.deliver(value) {
                delivered = true
            }
            if !delivered {
                appendToBacklog(value)
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
        switch backlogPolicy {
        case .unbounded:
            backlog.append(value)
        case .bufferingOldest(let limit):
            if backlog.count < limit {
                backlog.append(value)
            }
        case .bufferingNewest(let limit):
            guard limit > 0 else { return }
            backlog.append(value)
            if backlog.count > limit {
                backlog.removeFirst(backlog.count - limit)
            }
        @unknown default:
            backlog.append(value)
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
