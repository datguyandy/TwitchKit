import Foundation
import XCTest
@testable import TwitchKit

/// `logout()` must revoke the token on Twitch, and must still sign out
/// locally when revocation can't reach Twitch.
final class LogoutRevocationTests: XCTestCase {
    private func makeProvider(transport: MockHTTPClient, store: InMemoryTokenStore) -> TwitchTokenProvider {
        TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client", httpClient: transport),
            tokenStore: store
        )
    }

    private func bodyString(_ request: URLRequest) -> String {
        request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    func testLogoutRevokesTheTokenAndDeletesIt() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: "")])
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "access", refreshToken: "refresh"))
        let provider = makeProvider(transport: transport, store: store)

        try await provider.logout()

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://id.twitch.tv/oauth2/revoke")
        XCTAssertEqual(requests.first?.httpMethod, "POST")
        let body = try XCTUnwrap(requests.first.map(bodyString))
        XCTAssertTrue(body.contains("client_id=client"), body)
        XCTAssertTrue(body.contains("token=access"), body)
        let stored = try await store.loadToken()
        XCTAssertNil(stored)
        let authenticated = await provider.isAuthenticated()
        XCTAssertFalse(authenticated)
    }

    func testLogoutSignsOutEvenWhenRevocationFails() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 500, body: "")])
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "access"))
        let provider = makeProvider(transport: transport, store: store)

        try await provider.logout()

        let stored = try await store.loadToken()
        XCTAssertNil(stored)
        let authenticated = await provider.isAuthenticated()
        XCTAssertFalse(authenticated)
    }

    func testLogoutWithoutRevokingMakesNoRequest() async throws {
        let transport = MockHTTPClient(responses: [])
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "access"))
        let provider = makeProvider(transport: transport, store: store)

        try await provider.logout(revokingToken: false)

        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
        let stored = try await store.loadToken()
        XCTAssertNil(stored)
    }

    func testLogoutWhenSignedOutMakesNoRequest() async throws {
        let transport = MockHTTPClient(responses: [])
        let provider = makeProvider(transport: transport, store: InMemoryTokenStore())

        try await provider.logout()

        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testTwitchAuthLogoutRevokes() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: "")])
        let auth = TwitchAuth(
            oauthClient: TwitchOAuthClient(clientID: "client", httpClient: transport),
            tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "access"))
        )

        try await auth.logout()

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map { $0.url?.absoluteString }, ["https://id.twitch.tv/oauth2/revoke"])
    }

    func testRevokingAnAlreadyInvalidTokenSucceeds() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"status":400,"message":"Invalid token"}"#),
        ])
        let client = TwitchOAuthClient(clientID: "client", httpClient: transport)

        try await client.revokeToken("expired")
    }

    func testOtherRevocationRejectionsThrow() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 404, body: #"{"status":404,"message":"client does not exist"}"#),
        ])
        let client = TwitchOAuthClient(clientID: "unknown", httpClient: transport)

        do {
            try await client.revokeToken("access")
            XCTFail("Expected an OAuth error")
        } catch HelixError.oauth(let error) {
            XCTAssertEqual(error.status, 404)
            XCTAssertEqual(error.message, "client does not exist")
        }
    }
}
