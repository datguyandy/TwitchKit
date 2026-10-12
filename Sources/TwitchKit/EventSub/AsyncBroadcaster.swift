import Foundation

/// Fans values out to any number of `AsyncStream` consumers.
///
/// Each `makeStream()` call returns an independent stream that receives every
/// value sent after it was created, so consumers don't split values between
/// them, and one consumer cancelling (a SwiftUI `.task` whose view goes away)
/// doesn't end delivery for anyone else or for consumers created later.
///
/// Values sent while nobody is listening are kept, bounded by `backlogPolicy`,
/// and handed to the next consumer, matching what a single buffered
/// `AsyncStream` did for a consumer that started iterating late. With
/// `replaysLatest`, a consumer that arrives when there is no backlog first
/// receives the most recent value.
///
/// Lock-protected rather than an actor so a `nonisolated` property can create
/// streams synchronously.
final class AsyncBroadcaster<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy
    private let backlogPolicy: AsyncStream<Element>.Continuation.BufferingPolicy
    private let replaysLatest: Bool

    private var continuations: [UInt64: AsyncStream<Element>.Continuation] = [:]
    private var nextID: UInt64 = 0
    private var backlog: [Element] = []
    private var latest: Element?
    private var isFinished = false

    /// - Parameters:
    ///   - bufferingPolicy: Buffering for each consumer's stream.
    ///   - backlogPolicy: Bound on values kept while nobody is listening.
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
        withLock { continuations.count }
    }

    /// Returns a new stream that receives values from now on (plus any
    /// backlog, or the latest value when replaying).
    func makeStream() -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
        let id: UInt64? = withLock {
            guard !isFinished else { return nil }
            if !backlog.isEmpty {
                for value in backlog {
                    continuation.yield(value)
                }
                backlog.removeAll()
            } else if replaysLatest, let latest {
                continuation.yield(latest)
            }
            nextID &+= 1
            continuations[nextID] = continuation
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

    /// Sends `value` to every consumer, or to the backlog when there are none.
    func yield(_ value: Element) {
        withLock {
            guard !isFinished else { return }
            if replaysLatest {
                latest = value
            }
            guard !continuations.isEmpty else {
                appendToBacklog(value)
                return
            }
            for continuation in continuations.values {
                continuation.yield(value)
            }
        }
    }

    /// Ends every stream; streams created afterwards finish immediately.
    func finish() {
        let finishing: [AsyncStream<Element>.Continuation] = withLock {
            isFinished = true
            backlog.removeAll()
            let current = Array(continuations.values)
            continuations.removeAll()
            return current
        }
        // Outside the lock: finishing runs onTermination, which takes it.
        for continuation in finishing {
            continuation.finish()
        }
    }

    private func removeConsumer(_ id: UInt64) {
        withLock {
            _ = continuations.removeValue(forKey: id)
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
