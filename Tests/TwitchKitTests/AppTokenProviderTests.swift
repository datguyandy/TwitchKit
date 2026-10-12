import Foundation
import XCTest
@testable import TwitchKit

/// App access tokens come from the client credentials flow, are reused until
/// they near expiry, and are replaced when Twitch rejects them.
final class AppTokenProviderTests: XCTestCase {
    private static func tokenJSON(_ accessToken: String, expiresIn: Int = 5_011_271) -> String {
        #"{"access_token":"\#(accessToken)","expires_in":\#(expiresIn),"token_type":"bearer"}"#
    }

    private static let usersJSON = #"{"data":[{"id":"1","login":"twitchdev","display_name":"TwitchDev","profile_image_url":"https://example.com/p.png","broadcaster_type":""}]}"#
    private static let invalidTokenJSON = #"{"error":"Unauthorized","status":401,"message":"Invalid OAuth token"}"#

    private func makeProvider(_ transport: MockHTTPClient) -> TwitchAppTokenProvider {
        TwitchAppTokenProvider(clientID: "client", clientSecret: "secret", httpClient: transport)
    }

    private func bodyString(_ request: URLRequest?) -> String {
        request?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    func testRequestsATokenOnceAndReusesIt() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.tokenJSON("app-1"))])
        let provider = makeProvider(transport)

        let first = try await provider.accessToken()
        let second = try await provider.accessToken()

        XCTAssertEqual(first, "app-1")
        XCTAssertEqual(second, "app-1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://id.twitch.tv/oauth2/token")
        let body = bodyString(requests.first)
        XCTAssertTrue(body.contains("grant_type=client_credentials"), body)
        XCTAssertTrue(body.contains("client_id=client"), body)
        XCTAssertTrue(body.contains("client_secret=secret"), body)
    }

    func testRenewsATokenNearExpiry() async throws {
        // 100s left is inside the default 300s renewal margin.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.tokenJSON("app-1", expiresIn: 100)),
            .json(statusCode: 200, body: Self.tokenJSON("app-2")),
        ])
        let provider = makeProvider(transport)

        let first = try await provider.accessToken()
        let second = try await provider.accessToken()

        XCTAssertEqual(first, "app-1")
        XCTAssertEqual(second, "app-2")
    }

    func testConcurrentCallersShareOneRequest() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.tokenJSON("app-1"))])
        let provider = makeProvider(transport)

        async let a = provider.accessToken()
        async let b = provider.accessToken()
        async let c = provider.accessToken()
        let tokens = try await [a, b, c]

        XCTAssertEqual(tokens, ["app-1", "app-1", "app-1"])
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testRejectedTokenIsReplacedOnce() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.tokenJSON("app-1")),
            .json(statusCode: 200, body: Self.tokenJSON("app-2")),
        ])
        let provider = makeProvider(transport)
        _ = try await provider.accessToken()

        try await provider.refreshIfNeeded(rejectedAccessToken: "app-1")
        // A second request that was also rejected with app-1 reuses app-2.
        try await provider.refreshIfNeeded(rejectedAccessToken: "app-1")

        let token = try await provider.accessToken()
        XCTAssertEqual(token, "app-2")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func testHelixRetriesWithANewTokenAfterARejection() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.tokenJSON("app-1")),
            .json(statusCode: 401, body: Self.invalidTokenJSON),
            .json(statusCode: 200, body: Self.tokenJSON("app-2")),
            .json(statusCode: 200, body: Self.usersJSON),
        ])
        let api = HelixClient(tokenProvider: makeProvider(transport), clientID: "client", httpClient: transport)

        let user = try await api.fetchUser(id: "1")

        XCTAssertEqual(user?.login, "twitchdev")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map { $0.value(forHTTPHeaderField: "Authorization") }, [nil, "Bearer app-1", nil, "Bearer app-2"])
    }

    func testMissingClientSecretThrows() async throws {
        let transport = MockHTTPClient(responses: [])
        let provider = TwitchAppTokenProvider(oauthClient: TwitchOAuthClient(clientID: "client", httpClient: transport))

        do {
            _ = try await provider.accessToken()
            XCTFail("Expected missingClientSecret")
        } catch HelixError.missingClientSecret {
            // Expected.
        }
    }

    func testRevokeRevokesAndTheNextCallGetsANewToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.tokenJSON("app-1")),
            .json(statusCode: 200, body: ""),
            .json(statusCode: 200, body: Self.tokenJSON("app-2")),
        ])
        let provider = makeProvider(transport)
        _ = try await provider.accessToken()

        try await provider.revoke()
        let token = try await provider.accessToken()

        XCTAssertEqual(token, "app-2")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests[1].url?.absoluteString, "https://id.twitch.tv/oauth2/revoke")
        XCTAssertTrue(bodyString(requests[1]).contains("token=app-1"))
    }

    func testTwitchClientBuildsAppAPIOnlyWithASecret() async throws {
        let withoutSecret = TwitchClient(clientID: "client", tokenStore: InMemoryTokenStore(), pathMonitor: MockNetworkPathMonitor())
        XCTAssertNil(withoutSecret.appAPI)

        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.tokenJSON("app-1")),
            .json(statusCode: 200, body: Self.usersJSON),
        ])
        let withSecret = TwitchClient(
            clientID: "client",
            clientSecret: "secret",
            tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "user-token")),
            httpClient: transport,
            pathMonitor: MockNetworkPathMonitor()
        )
        let appAPI = try XCTUnwrap(withSecret.appAPI)

        _ = try await appAPI.fetchUser(id: "1")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer app-1")
    }
}
