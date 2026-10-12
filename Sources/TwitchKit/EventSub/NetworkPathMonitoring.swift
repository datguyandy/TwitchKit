import Foundation
import Network

/// Binary network-reachability signal. We only care whether a usable path
/// exists — not the interface type (Wi-Fi vs cellular is irrelevant to EventSub
/// reconnect; we never proactively drop a live socket on an interface change).
public enum NetworkPathStatus: Sendable {
    case satisfied
    case unsatisfied
}

/// Abstracts `NWPathMonitor` so the reconnect logic can be unit-tested with a
/// scripted sequence of path changes.
///
/// The client calls ``start()`` on `connect()` and ``cancel()`` on
/// `disconnect()`, and a later `connect()` calls ``start()`` again, so a
/// monitor must be restartable: ``start()`` after ``cancel()`` begins a new
/// ``pathUpdates`` stream.
public protocol NetworkPathMonitoring: Sendable {
    /// Emits the current status promptly after ``start()``, then on every
    /// change, until ``cancel()``. Read it after ``start()``: each start after
    /// a cancel returns a new stream. Single-consumer.
    var pathUpdates: AsyncStream<NetworkPathStatus> { get }
    func start()
    func cancel()
}

/// Production ``NetworkPathMonitoring`` backed by `NWPathMonitor`.
///
/// An `NWPathMonitor` can't be restarted once cancelled, so each ``start()``
/// after a ``cancel()`` creates a new one, with a new ``pathUpdates`` stream.
/// Lock-protected rather than an actor because the protocol is synchronous.
public final class NWPathNetworkMonitor: NetworkPathMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.twitchkit.networkpath")
    private var monitor: NWPathMonitor?
    private var stream: AsyncStream<NetworkPathStatus>
    private var continuation: AsyncStream<NetworkPathStatus>.Continuation
    private var isCancelled = false

    public init() {
        (stream, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
    }

    public var pathUpdates: AsyncStream<NetworkPathStatus> {
        withLock { stream }
    }

    public func start() {
        withLock {
            guard monitor == nil else { return }
            if isCancelled {
                (stream, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
                isCancelled = false
            }
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [continuation] path in
                continuation.yield(path.status == .satisfied ? .satisfied : .unsatisfied)
            }
            monitor.start(queue: queue)
            self.monitor = monitor
        }
    }

    public func cancel() {
        withLock {
            monitor?.cancel()
            monitor = nil
            isCancelled = true
            continuation.finish()
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
