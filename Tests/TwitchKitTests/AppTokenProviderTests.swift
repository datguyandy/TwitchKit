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

    func testATokenRequestedWhileRevokingIsRevokedAndNotHandedOut() async throws {
        let gate = ResponseGate()
        let transport = RoutingTokenTransport(gatedTokenRequest: 2, gate: gate)
        // A renewal margin longer than the token's life: every accessToken()
        // requests a new token, so one can be in flight while app-1 is cached.
        let provider = TwitchAppTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client", clientSecret: "secret", httpClient: transport),
            renewalMargin: .seconds(10_000_000)
        )
        let first = try await provider.accessToken()
        XCTAssertEqual(first, "app-1")

        // app-2 is being requested when revoke() starts.
        let requesting = Task { try await provider.accessToken() }
        let requested = await waitFor { await transport.tokenRequestCount == 2 }
        XCTAssertTrue(requested)
        let revoking = Task { try await provider.revoke() }
        let revokedCurrent = await waitFor { await transport.revokedTokens == ["app-1"] }
        XCTAssertTrue(revokedCurrent)
        await gate.open()

        let token = try await requesting.value
        try await revoking.value

        XCTAssertEqual(token, "app-3", "a token issued after revoke() began must not be handed out")
        let revoked = await transport.revokedTokens
        XCTAssertEqual(revoked, ["app-1", "app-2"], "the token issued after revoke() began must be revoked")
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

/// Polls (~5s) until `condition` holds.
private func waitFor(_ condition: @Sendable () async -> Bool) async -> Bool {
    for _ in 0..<500 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

/// Answers by endpoint rather than in order: token requests get `app-1`,
/// `app-2`, … (request number `gatedTokenRequest` held until `gate` opens),
/// and revokes succeed and are recorded.
private actor RoutingTokenTransport: HTTPClient {
    private let gatedTokenRequest: Int
    private let gate: ResponseGate
    private(set) var tokenRequestCount = 0
    private(set) var revokedTokens: [String] = []

    init(gatedTokenRequest: Int, gate: ResponseGate) {
        self.gatedTokenRequest = gatedTokenRequest
        self.gate = gate
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url ?? URL(string: "https://example.com")!
        let body: String
        if url.path().hasSuffix("/revoke") {
            let form = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let token = form.split(separator: "&")
                .first { $0.hasPrefix("token=") }
                .map { String($0.dropFirst("token=".count)) } ?? ""
            revokedTokens.append(token)
            body = ""
        } else {
            tokenRequestCount += 1
            let number = tokenRequestCount
            if number == gatedTokenRequest {
                await gate.wait()
            }
            body = #"{"access_token":"app-\#(number)","expires_in":5011271,"token_type":"bearer"}"#
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:])!
        return (Data(body.utf8), response)
    }
}
