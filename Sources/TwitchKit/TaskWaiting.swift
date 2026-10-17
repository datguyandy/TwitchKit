import Foundation

extension Task {
    /// The task's result, or `CancellationError` as soon as the *waiting*
    /// task is cancelled, whichever comes first.
    ///
    /// TwitchKit shares one unstructured task between concurrent callers of
    /// `connect()` and token refreshes, so cancelling one caller mustn't
    /// cancel the work the others are waiting on. `await task.value` gets
    /// that right but ignores the caller's own cancellation, leaving it stuck
    /// until the shared work finishes. This returns early instead and leaves
    /// the task running.
    func resultUnlessCancelled() async throws -> Result<Success, Failure> {
        let outcome = FirstOutcome<Result<Success, Failure>>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard outcome.install(continuation) else { return }
                Task<Void, Never> {
                    let result = await self.result
                    outcome.finish(.success(result))
                }
            }
        } onCancel: {
            outcome.finish(.failure(CancellationError()))
        }
    }
}

/// Resumes a continuation with whichever outcome arrives first; later ones
/// are ignored. Lock-protected because the cancellation handler runs
/// synchronously on an arbitrary thread.
private final class FirstOutcome<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var outcome: Result<Value, any Error>?

    /// Stores the continuation, or resumes it at once if an outcome (an
    /// early cancellation) already arrived. Returns whether it was stored.
    func install(_ continuation: CheckedContinuation<Value, any Error>) -> Bool {
        lock.lock()
        if let outcome {
            lock.unlock()
            continuation.resume(with: outcome)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func finish(_ result: Result<Value, any Error>) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        outcome = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
