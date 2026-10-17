import Foundation
import XCTest
@testable import TwitchKit

/// Validation returns what Twitch reports about a token, and the periodic
/// stream validates on start and then on every interval.
final class TokenValidationTests: XCTestCase {
    private static let userTokenJSON = #"{"client_id":"wbmytr93xzw8zbg0p1izqyzzc5mbiz","login":"twitchdev","scopes":["channel:read:subscriptions","user:read:chat"],"user_id":"141981764","expires_in":5520838}"#
    private static let appTokenJSON = #"{"client_id":"wbmytr93xzw8zbg0p1izqyzzc5mbiz","scopes":null,"expires_in":5011271}"#
    private static let invalidJSON = #"{"status":401,"message":"invalid access token"}"#
    /// The client ID in the fixtures above: providers must be built with it, since
    /// a token issued to another client ID is rejected.
    private static let clientID = "wbmytr93xzw8zbg0p1izqyzzc5mbiz"

    private func makeProvider(transport: MockHTTPClient, token: OAuthToken?) -> TwitchTokenProvider {
        TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: Self.clientID, clientSecret: "secret", httpClient: transport),
            tokenStore: InMemoryTokenStore(token: token)
        )
    }

    /// Collects the first `count` results from the stream, giving up after ~5s.
    private func firstResults(
        _ count: Int,
        of stream: AsyncStream<TokenValidationResult>
    ) async -> [TokenValidationResult] {
        let reader = Task { () -> [TokenValidationResult] in
            var results: [TokenValidationResult] = []
            for await result in stream {
                results.append(result)
                if results.count == count { break }
            }
            return results
        }
        let timeout = Task {
            try await Task.sleep(for: .seconds(5))
            reader.cancel()
        }
        defer { timeout.cancel() }
        return await reader.value
    }

    // MARK: - TwitchOAuthClient.validate

    func testValidateReturnsUserTokenInfo() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.userTokenJSON)])
        let client = TwitchOAuthClient(clientID: "client", httpClient: transport)

        let before = Date.now
        let info = try await client.validate("token")

        let unwrapped = try XCTUnwrap(info)
        XCTAssertEqual(unwrapped.clientID, "wbmytr93xzw8zbg0p1izqyzzc5mbiz")
        XCTAssertEqual(unwrapped.userID, "141981764")
        XCTAssertEqual(unwrapped.login, "twitchdev")
        XCTAssertEqual(unwrapped.scopes, ["channel:read:subscriptions", "user:read:chat"])
        XCTAssertTrue(unwrapped.hasScope(.userReadChat))
        XCTAssertFalse(unwrapped.hasScope(.channelReadStreamKey))
        XCTAssertEqual(unwrapped.expiresIn, 5_520_838)
        let expiresAt = try XCTUnwrap(unwrapped.expiresAt)
        XCTAssertGreaterThanOrEqual(expiresAt, before.addingTimeInterval(5_520_838))
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "OAuth token")
    }

    func testValidateReturnsAppTokenInfo() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.appTokenJSON)])
        let client = TwitchOAuthClient(clientID: "client", httpClient: transport)

        let validated = try await client.validate("app-token")
        let info = try XCTUnwrap(validated)

        XCTAssertNil(info.userID)
        XCTAssertNil(info.login)
        XCTAssertEqual(info.scopes, [])
    }

    func testValidateReturnsNilForAnInvalidToken() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: Self.invalidJSON)])
        let client = TwitchOAuthClient(clientID: "client", httpClient: transport)

        let info = try await client.validate("expired")

        XCTAssertNil(info)
    }

    func testTokenThatNeverExpiresHasNoExpiryDate() {
        XCTAssertNil(TwitchTokenInfo(clientID: "client", expiresIn: 0).expiresAt)
    }

    // MARK: - TwitchTokenProvider.validateToken

    func testValidateTokenReturnsTheInfo() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.userTokenJSON)])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "token"))

        let info = try await provider.validateToken()

        XCTAssertEqual(info?.login, "twitchdev")
    }

    func testValidateTokenThrowsWhenARejectedTokenCannotBeRefreshed() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: Self.invalidJSON)])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "token"))

        do {
            try await provider.validateToken()
            XCTFail("Expected unauthorized")
        } catch HelixError.unauthorized {
            // Expected: there's no refresh token.
        }
    }

    func testARejectedTokenWithoutARefreshTokenIsForgotten() async throws {
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: Self.invalidJSON)])
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client", clientSecret: "secret", httpClient: transport),
            tokenStore: store
        )

        _ = try? await provider.validateToken()

        // Twitch requires apps to stop using a token it rejects.
        do {
            _ = try await provider.accessToken()
            XCTFail("A rejected token must not be handed out again")
        } catch HelixError.notAuthenticated {
            // Expected.
        }
        let stored = try await store.loadToken()
        XCTAssertNil(stored, "the rejected token is deleted from storage too")
    }

    func testATokenIssuedToAnotherClientIsRejectedAndForgotten() async throws {
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.userTokenJSON)])
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "some-other-client", httpClient: transport),
            tokenStore: store
        )

        let results = await firstResults(1, of: provider.validations())

        guard case .invalid(HelixError.tokenClientMismatch(let expected, let actual))? = results.first else {
            return XCTFail("Expected .invalid(.tokenClientMismatch), got \(results)")
        }
        XCTAssertEqual(expected, "some-other-client")
        XCTAssertEqual(actual, Self.clientID)
        let stored = try await store.loadToken()
        XCTAssertNil(stored, "a token issued to another client is never used again")
    }

    // MARK: - validations(every:)

    func testValidationsRunNowAndThenOnEveryInterval() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.userTokenJSON),
            .json(statusCode: 200, body: Self.userTokenJSON),
        ])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "token"))

        let results = await firstResults(2, of: provider.validations(every: .milliseconds(20)))

        XCTAssertEqual(results.count, 2)
        for result in results {
            guard case .valid(let info) = result else {
                return XCTFail("Expected .valid, got \(result)")
            }
            XCTAssertEqual(info.userID, "141981764")
        }
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func testValidationsRefreshARejectedToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: Self.invalidJSON),
            .json(statusCode: 200, body: #"{"access_token":"new","refresh_token":"r2","expires_in":14400,"scope":[],"token_type":"bearer"}"#),
            .json(statusCode: 200, body: Self.userTokenJSON),
        ])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))

        let results = await firstResults(1, of: provider.validations())

        guard case .valid? = results.first else {
            return XCTFail("Expected .valid, got \(results)")
        }
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "new")
    }

    func testValidationsReportATokenThatCannotBeRefreshed() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: Self.invalidJSON)])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "token"))

        let results = await firstResults(1, of: provider.validations())

        guard case .invalid? = results.first else {
            return XCTFail("Expected .invalid, got \(results)")
        }
    }

    func testValidationsReportARejectedRefreshAsInvalidAndSignOut() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: Self.invalidJSON),
            .json(statusCode: 400, body: #"{"status":400,"message":"Invalid refresh token"}"#),
        ])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "old", refreshToken: "revoked"))

        let results = await firstResults(1, of: provider.validations())

        guard case .invalid? = results.first else {
            return XCTFail("Expected .invalid, got \(results)")
        }
        let authenticated = await provider.isAuthenticated()
        XCTAssertFalse(authenticated)
    }

    func testValidationsReportSignedOut() async throws {
        let transport = MockHTTPClient(responses: [])
        let provider = makeProvider(transport: transport, token: nil)

        let results = await firstResults(1, of: provider.validations())

        guard case .signedOut? = results.first else {
            return XCTFail("Expected .signedOut, got \(results)")
        }
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testValidationsReportAnOutageAndKeepTheToken() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 503, body: "")])
        let provider = makeProvider(transport: transport, token: OAuthToken(accessToken: "token", refreshToken: "r1"))

        let results = await firstResults(1, of: provider.validations())

        guard case .failed(let error)? = results.first else {
            return XCTFail("Expected .failed, got \(results)")
        }
        guard case .serverError(503)? = error as? HelixError else {
            return XCTFail("Expected serverError(503), got \(error)")
        }
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "token")
    }

    func testTwitchAuthForwardsValidations() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.userTokenJSON)])
        let auth = TwitchAuth(
            oauthClient: TwitchOAuthClient(clientID: Self.clientID, httpClient: transport),
            tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
        )

        let results = await firstResults(1, of: auth.validations())

        guard case .valid(let info)? = results.first else {
            return XCTFail("Expected .valid, got \(results)")
        }
        XCTAssertEqual(info.login, "twitchdev")
    }
}
