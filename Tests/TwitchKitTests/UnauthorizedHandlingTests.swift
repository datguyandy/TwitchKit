import Foundation
import XCTest
@testable import TwitchKit

/// Helix answers 401 both for invalid tokens and for problems a new token
/// can't fix (missing scope, mismatched IDs). Only the former should trigger
/// a refresh, and Twitch's message must reach the caller either way.
final class UnauthorizedHandlingTests: XCTestCase {
    private static let missingScopeBody = #"{"error":"Unauthorized","status":401,"message":"Missing scope: moderator:read:followers"}"#
    private static let invalidTokenBody = #"{"error":"Unauthorized","status":401,"message":"Invalid OAuth token"}"#
    private static let refreshedTokenJSON = #"{"access_token":"new","refresh_token":"r2","expires_in":3600,"token_type":"bearer"}"#
    private static let usersJSON = #"{"data":[{"id":"1","login":"twitchdev","display_name":"TwitchDev","profile_image_url":"https://example.com/p.png","broadcaster_type":""}]}"#

    private func makeAuth(httpClient: any HTTPClient, token: OAuthToken) async throws -> TwitchAuth {
        let auth = TwitchAuth(
            oauthClient: TwitchOAuthClient(clientId: "client", clientSecret: "secret", httpClient: httpClient),
            tokenStore: InMemoryTokenStore()
        )
        try await auth.setToken(token)
        return auth
    }

    private func makeProvider(httpClient: any HTTPClient, token: OAuthToken) -> TwitchTokenProvider {
        TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientId: "client", clientSecret: "secret", httpClient: httpClient),
            tokenStore: InMemoryTokenStore(token: token)
        )
    }

    // MARK: - HelixClient

    func testMissingScopeDoesNotRefreshAndKeepsTwitchMessage() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: Self.missingScopeBody)])
        let auth = try await makeAuth(httpClient: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))
        let api = HelixClient(auth: auth, clientId: "client", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected unauthorized")
        } catch HelixError.unauthorized(let apiError) {
            XCTAssertEqual(apiError?.message, "Missing scope: moderator:read:followers")
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1, "A missing scope must not trigger a token refresh or retry")
        let accessToken = try await auth.accessToken()
        XCTAssertEqual(accessToken, "old")
    }

    func testIDMismatchDoesNotRefresh() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: """
        {"error":"Unauthorized","status":401,"message":"The ID in broadcaster_id must match the user ID found in the request's OAuth token."}
        """)])
        let auth = try await makeAuth(httpClient: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))
        let api = HelixClient(auth: auth, clientId: "client", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected unauthorized")
        } catch HelixError.unauthorized(let apiError) {
            XCTAssertEqual(apiError?.message.hasPrefix("The ID in broadcaster_id must match"), true)
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testInvalidTokenRefreshesAndRetries() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: Self.invalidTokenBody),
            .json(statusCode: 200, body: Self.refreshedTokenJSON),
            .json(statusCode: 200, body: Self.usersJSON),
        ])
        let auth = try await makeAuth(httpClient: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))
        let api = HelixClient(auth: auth, clientId: "client", httpClient: transport)

        let user = try await api.fetchUser()

        XCTAssertEqual(user.id, "1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[1].url?.absoluteString, "https://id.twitch.tv/oauth2/token")
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer new")
    }

    func testInvalidTokenWithoutRefreshTokenSurfacesTwitchMessage() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 401, body: Self.invalidTokenBody)])
        let auth = try await makeAuth(httpClient: transport, token: OAuthToken(accessToken: "old"))
        let api = HelixClient(auth: auth, clientId: "client", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected unauthorized")
        } catch HelixError.unauthorized(let apiError) {
            XCTAssertEqual(apiError?.message, "Invalid OAuth token")
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testRetryRejectedAgainKeepsTwitchMessage() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: Self.invalidTokenBody),
            .json(statusCode: 200, body: Self.refreshedTokenJSON),
            .json(statusCode: 401, body: Self.invalidTokenBody),
        ])
        let auth = try await makeAuth(httpClient: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))
        let api = HelixClient(auth: auth, clientId: "client", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected unauthorized")
        } catch HelixError.unauthorized(let apiError) {
            XCTAssertEqual(apiError?.message, "Invalid OAuth token")
        }
    }

    func testUnauthorizedDescriptionIncludesTwitchMessage() {
        let error = HelixError.unauthorized(TwitchAPIError(error: "Unauthorized", status: 401, message: "Missing scope: user:read:chat"))

        XCTAssertEqual(error.errorDescription, "Unauthorized: Missing scope: user:read:chat")
        XCTAssertEqual(HelixError.unauthorized(nil).errorDescription, "Unauthorized — token invalid or expired")
    }

    func testTokenRejectionClassification() {
        func apiError(_ message: String) -> TwitchAPIError {
            TwitchAPIError(error: "Unauthorized", status: 401, message: message)
        }

        XCTAssertTrue(HelixClient.isTokenRejection(nil))
        XCTAssertTrue(HelixClient.isTokenRejection(apiError("Invalid OAuth token")))
        XCTAssertFalse(HelixClient.isTokenRejection(apiError("Missing scope: channel:manage:broadcast")))
        XCTAssertFalse(HelixClient.isTokenRejection(apiError("The ID in broadcaster_id must match the user ID found in the request's OAuth token.")))
        XCTAssertFalse(HelixClient.isTokenRejection(apiError("Client ID and OAuth token do not match")))
    }

    // MARK: - TwitchTokenProvider

    func testRefreshIsSkippedWhenRejectedTokenWasAlreadyReplaced() async throws {
        let transport = MockHTTPClient(responses: [])
        let provider = makeProvider(httpClient: transport, token: OAuthToken(accessToken: "new", refreshToken: "r2"))

        try await provider.refreshIfNeeded(rejectedAccessToken: "old")

        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty, "A token that was already replaced must not be refreshed again")
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "new")
    }

    func testRefreshRunsWhenRejectedTokenIsCurrent() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.refreshedTokenJSON)])
        let provider = makeProvider(httpClient: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))

        try await provider.refreshIfNeeded(rejectedAccessToken: "old")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "new")
    }

    func testSequentialRejectionsOfSameTokenRefreshOnce() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.refreshedTokenJSON)])
        let provider = makeProvider(httpClient: transport, token: OAuthToken(accessToken: "old", refreshToken: "r1"))

        // Two requests sent with "old" both come back 401; the second
        // reports its rejection after the first one's refresh finished.
        try await provider.refreshIfNeeded(rejectedAccessToken: "old")
        try await provider.refreshIfNeeded(rejectedAccessToken: "old")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }
}
