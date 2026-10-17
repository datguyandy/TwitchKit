import Foundation
import XCTest
@testable import TwitchKit

/// A caller that's cancelled while waiting on shared work (a `connect()`
/// attempt, a token refresh, an app-token request) stops waiting at once,
/// and the shared work carries on for everyone else.
final class CancellationTests: XCTestCase {
    private static let refreshedTokenJSON = #"{"access_token":"new","refresh_token":"r2","expires_in":3600,"scope":[],"token_type":"bearer"}"#

    // MARK: - connect()

    func testCancelledConnectCallersStopWaitingWithoutStoppingTheAttempt() async throws {
        let client = EventSubClient(
            api: HelixClient(
                tokenProvider: TwitchTokenProvider(
                    oauthClient: TwitchOAuthClient(clientID: "client"),
                    tokenStore: InMemoryTokenStore()
                ),
                clientID: "client"
            ),
            shouldKeepReconnecting: { false },
            pathMonitor: MockNetworkPathMonitor()
        )
        let attempts = AttemptCounter()
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        await client.setConnectBodyForTesting {
            await attempts.increment()
            var iterator = gate.makeAsyncIterator()
            _ = await iterator.next()
        }

        let initiator = Task { try await client.connect() }
        while await !(client.isConnectingForTesting) {
            await Task.yield()
        }

        // The caller that started the attempt is cancelled: it returns now.
        initiator.cancel()
        do {
            try await initiator.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {}

        // So does a cancelled caller that joined the attempt.
        let joiner = Task { try await client.connect() }
        joiner.cancel()
        do {
            try await joiner.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {}

        // The attempt is still running, so the next caller would join it.
        let stillConnecting = await client.isConnectingForTesting
        XCTAssertTrue(stillConnecting, "cancelling callers must not end the shared attempt")

        gateContinuation.yield(())
        gateContinuation.finish()
        let finished = await waitUntil { await !client.isConnectingForTesting }
        XCTAssertTrue(finished)
        let count = await attempts.count
        XCTAssertEqual(count, 1)

        await client.disconnect()
    }

    // MARK: - Token refresh

    func testCancelledRefreshCallersStopWaitingWhileTheRefreshCompletes() async throws {
        let gate = ResponseGate()
        let transport = MockHTTPClient(responses: [.gatedJSON(gate: gate, statusCode: 200, body: Self.refreshedTokenJSON)])
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "old", refreshToken: "r1"))
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client", clientSecret: "secret", httpClient: transport),
            tokenStore: store
        )

        let initiator = Task { try await provider.refreshIfNeeded() }
        let sent = await waitUntil { await !transport.recordedRequests().isEmpty }
        XCTAssertTrue(sent)

        initiator.cancel()
        do {
            try await initiator.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {}

        let joiner = Task { try await provider.refreshIfNeeded(rejectedAccessToken: "old") }
        joiner.cancel()
        do {
            try await joiner.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {}

        // The refresh itself finishes and stores the rotated token.
        await gate.open()
        let stored = await waitUntil { (try? await store.loadToken())?.accessToken == "new" }
        XCTAssertTrue(stored, "cancelling callers must not abandon the refresh")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - App access tokens

    func testCancelledAppTokenCallerStopsWaitingAndTheNextCallerGetsTheToken() async throws {
        let gate = ResponseGate()
        let transport = MockHTTPClient(responses: [
            .gatedJSON(gate: gate, statusCode: 200, body: #"{"access_token":"app-1","expires_in":5011271,"token_type":"bearer"}"#),
        ])
        let provider = TwitchAppTokenProvider(clientID: "client", clientSecret: "secret", httpClient: transport)

        let initiator = Task { try await provider.accessToken() }
        let sent = await waitUntil { await !transport.recordedRequests().isEmpty }
        XCTAssertTrue(sent)

        initiator.cancel()
        do {
            _ = try await initiator.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {}

        // The request carried on; the next caller picks up its token.
        await gate.open()
        let token = try await provider.accessToken()
        XCTAssertEqual(token, "app-1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - resultUnlessCancelled()

    func testResultUnlessCancelledReturnsTheResult() async throws {
        let task = Task<Int, any Error> { 42 }

        let result = try await task.resultUnlessCancelled()

        XCTAssertEqual(try result.get(), 42)
    }

    func testResultUnlessCancelledLeavesTheTaskRunning() async throws {
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let work = Task<Int, Never> {
            var iterator = gate.makeAsyncIterator()
            _ = await iterator.next()
            return 7
        }

        let waiter = Task { try await work.resultUnlessCancelled() }
        waiter.cancel()
        do {
            _ = try await waiter.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {}

        XCTAssertFalse(work.isCancelled)
        gateContinuation.yield(())
        gateContinuation.finish()
        let value = await work.value
        XCTAssertEqual(value, 7)
    }
}

private actor AttemptCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

/// Polls (~5s) until `condition` holds.
private func waitUntil(_ condition: @Sendable () async -> Bool) async -> Bool {
    for _ in 0..<500 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
