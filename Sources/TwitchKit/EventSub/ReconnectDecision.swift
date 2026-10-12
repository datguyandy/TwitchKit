import Foundation

/// The outcome of evaluating whether EventSub should retry its WebSocket connection.
///
/// This is the pure core of the reconnect backoff ladder, extracted from
/// ``EventSubClient`` so the gating + delay math can be unit-tested without
/// sockets, sleeps, or the network.
struct ReconnectDecision: Equatable {
    /// Why the ladder is stopping. The caller's reaction differs per reason —
    /// `attemptsExhausted` in particular is a terminal state that must be
    /// surfaced on the `connectionState` stream (as `.disconnected`), not a
    /// silent park that leaves a stale `.reconnecting` as the last word.
    enum ParkReason: Equatable {
        /// The client no longer intends to be connected (`disconnect()`).
        case stopRequested
        /// The network path is unsatisfied; path restoration resumes the ladder.
        case networkUnavailable
        /// The non-live ladder used up all its attempts — giving up.
        case attemptsExhausted
    }

    enum Action: Equatable {
        /// Stop retrying for now, for the given reason.
        case park(ParkReason)
        /// Sleep `delay`, then attempt a fresh connection.
        case attempt(delay: Duration)
    }

    let action: Action
}

/// Decides whether to attempt a reconnect (and after what backoff delay) or to park.
///
/// - Parameters:
///   - networkAvailable: Whether the OS reports a usable network path.
///   - shouldReconnect: Whether the client still intends to be connected.
///   - shouldKeepReconnecting: Tunes the ladder. When `true` it retries
///     forever with a short, 5s-capped backoff; when `false` it gives up after
///     5 attempts with a longer, 30s-capped backoff.
///   - attempt: The 1-based attempt number being evaluated.
/// - Returns: ``ReconnectDecision/Action/park(_:)`` to stop (with the reason), or
///   ``ReconnectDecision/Action/attempt(delay:)`` with the backoff delay.
func reconnectDecision(
    networkAvailable: Bool,
    shouldReconnect: Bool,
    shouldKeepReconnecting: Bool,
    attempt: Int
) -> ReconnectDecision {
    guard shouldReconnect else { return ReconnectDecision(action: .park(.stopRequested)) }
    guard networkAvailable else { return ReconnectDecision(action: .park(.networkUnavailable)) }

    let maxAttempts = shouldKeepReconnecting ? Int.max : 5
    guard attempt <= maxAttempts else { return ReconnectDecision(action: .park(.attemptsExhausted)) }

    let baseDelay: Double = shouldKeepReconnecting ? 0.5 : 1.0
    let maxDelay: Double = shouldKeepReconnecting ? 5.0 : 30.0
    let seconds = min(baseDelay * pow(2.0, Double(attempt - 1)), maxDelay)
    return ReconnectDecision(action: .attempt(delay: .seconds(seconds)))
}
