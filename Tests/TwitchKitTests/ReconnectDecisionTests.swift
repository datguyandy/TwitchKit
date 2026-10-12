import XCTest
@testable import TwitchKit

/// Tests for the pure reconnect-decision helper that drives EventSub's backoff ladder.
///
/// The decision is a pure function so the ladder math + give-up/park gating can be
/// verified deterministically, with no sockets, sleeps, or network involved.
final class ReconnectDecisionTests: XCTestCase {

    func test_clientsKeepReconnectingByDefault() async {
        let twitch = TwitchClient(clientID: "client-id", tokenStore: InMemoryTokenStore(), pathMonitor: MockNetworkPathMonitor())
        let twitchKeepsReconnecting = await twitch.eventSub.shouldKeepReconnecting()
        XCTAssertTrue(twitchKeepsReconnecting)

        let eventSub = EventSubClient(api: twitch.api, pathMonitor: MockNetworkPathMonitor())
        let eventSubKeepsReconnecting = await eventSub.shouldKeepReconnecting()
        XCTAssertTrue(eventSubKeepsReconnecting)
    }

    func test_offlineAlwaysParks() {
        let decision = reconnectDecision(
            networkAvailable: false, shouldReconnect: true, shouldKeepReconnecting: true, attempt: 1
        )
        XCTAssertEqual(decision.action, .park(.networkUnavailable))
    }

    func test_notWantingToReconnectParks() {
        let decision = reconnectDecision(
            networkAvailable: true, shouldReconnect: false, shouldKeepReconnecting: true, attempt: 1
        )
        XCTAssertEqual(decision.action, .park(.stopRequested))
    }

    /// When both gates would park, "we don't want to reconnect" wins — a
    /// deliberate stop must never be reported as a transient network problem.
    func test_stopRequestedTakesPrecedenceOverNetworkUnavailable() {
        let decision = reconnectDecision(
            networkAvailable: false, shouldReconnect: false, shouldKeepReconnecting: true, attempt: 1
        )
        XCTAssertEqual(decision.action, .park(.stopRequested))
    }

    func test_keepReconnectingUsesHalfSecondBaseDelay() {
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: true, attempt: 1).action,
            .attempt(delay: .seconds(0.5))
        )
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: true, attempt: 2).action,
            .attempt(delay: .seconds(1.0))
        )
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: true, attempt: 4).action,
            .attempt(delay: .seconds(4.0))
        )
    }

    func test_keepReconnectingCapsDelayAtFiveSeconds() {
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: true, attempt: 5).action,
            .attempt(delay: .seconds(5.0))
        )
    }

    func test_keepReconnectingNeverGivesUp() {
        // shouldKeepReconnecting == true => unbounded attempts, always capped delay, never .park.
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: true, attempt: 1_000).action,
            .attempt(delay: .seconds(5.0))
        )
    }

    func test_givingUpUsesOneSecondBaseDelayDoublingEachAttempt() {
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: false, attempt: 1).action,
            .attempt(delay: .seconds(1.0))
        )
        // attempt 5 is the last allowed when not keeping on: 1 * 2^4 = 16s (under the 30s cap).
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: false, attempt: 5).action,
            .attempt(delay: .seconds(16.0))
        )
    }

    func test_givingUpStopsAfterFiveAttempts() {
        // maxAttempts == 5 when not keeping on, so attempt 6 onward parks (gives up).
        // The reason matters: `.attemptsExhausted` is what makes EventSubClient
        // emit the terminal `.disconnected` instead of parking silently.
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, shouldKeepReconnecting: false, attempt: 6).action,
            .park(.attemptsExhausted)
        )
    }
}
