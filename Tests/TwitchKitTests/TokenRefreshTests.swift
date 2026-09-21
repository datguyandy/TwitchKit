import XCTest
@testable import TwitchKit

final class TokenRefreshTests: XCTestCase {
    private static let seedToken = OAuthToken(accessToken: "old", refreshToken: "r1")
    private static let refreshedTokenJSON = #"{"access_token":"new","refresh_token":"r2","expires_in":3600,"scope":[],"token_type":"bearer"}"#

    private func makeProvider(store: InMemoryTokenStore, httpClient: any HTTPClient) -> TwitchTokenProvider {
        TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientId: "id", clientSecret: "secret", httpClient: httpClient),
            tokenStore: store
        )
    }

    func test_refreshKeepsTokenWhenTokenEndpointHasAnOutage() async throws {
        // A 503 from the token endpoint surfaces as HelixError.oauth via the
        // fallback path, but it says nothing about the refresh token's
        // validity — the provider must NOT log out over a server outage.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: "")
        ])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        do {
            try await provider.refreshIfNeeded()
            XCTFail("Expected OAuth error")
        } catch let error as HelixError {
            guard case .oauth(let oauthError) = error else {
                return XCTFail("Expected oauth error, got \(error)")
            }
            XCTAssertEqual(oauthError.status, 503)
        }

        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.refreshToken, "r1")
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "old")
    }

    func test_refreshKeepsTokenWhenTransportFails() async throws {
        // A transport-level failure (timeout, offline, …) must leave the
        // stored token untouched so the next attempt can retry the refresh.
        // An empty response queue makes MockHTTPClient throw networkError.
        let transport = MockHTTPClient(responses: [])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        do {
            try await provider.refreshIfNeeded()
            XCTFail("Expected network error")
        } catch let error as HelixError {
            guard case .networkError = error else {
                return XCTFail("Expected networkError, got \(error)")
            }
        }

        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.refreshToken, "r1")
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "old")
    }

    func test_validateTokenLeavesValidTokenUntouched() async throws {
        // A 200 from /validate means the token is good: exactly one request
        // (the validation itself) and no refresh.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"client_id":"id","login":"user","scopes":[],"user_id":"1","expires_in":3600}"#)
        ])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        try await provider.validateToken()

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://id.twitch.tv/oauth2/validate")
        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.accessToken, "old")
    }

    func test_validateTokenRefreshesWhenTwitchReportsTokenInvalid() async throws {
        // Twitch requires periodic /validate calls; a 401 there means the
        // access token is dead and the provider must refresh through the
        // stored refresh token.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: #"{"status":401,"message":"invalid access token"}"#),
            .json(statusCode: 200, body: Self.refreshedTokenJSON),
        ])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        try await provider.validateToken()

        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.accessToken, "new")
        XCTAssertEqual(storedToken?.refreshToken, "r2")
    }

    func test_validateTokenWithoutStoredTokenIsANoOp() async throws {
        let transport = MockHTTPClient(responses: [])
        let store = InMemoryTokenStore(token: nil)
        let provider = makeProvider(store: store, httpClient: transport)

        try await provider.validateToken()

        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func test_refreshWrapsURLErrorAsHelixTransport() async throws {
        // The OAuth client must wrap raw URLErrors the same way HelixClient
        // does, so callers can pattern-match `HelixError.transport` across
        // the whole SDK instead of special-casing the token endpoints.
        let transport = MockHTTPClient(responses: [.failure(URLError(.notConnectedToInternet))])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        do {
            try await provider.refreshIfNeeded()
            XCTFail("Expected transport error")
        } catch HelixError.transport(let urlError) {
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        }

        // Transport failures are transient: the stored token must survive.
        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.refreshToken, "r1")
    }

    func test_refreshLogsOutWhenOAuthServerRejectsRefreshToken() async throws {
        // A 400 with an OAuth error body is the server definitively
        // rejecting the refresh token — the session is dead, so the stored
        // token must be destroyed.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"error":"invalid_grant","status":400,"message":"Invalid refresh token"}"#)
        ])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        do {
            try await provider.refreshIfNeeded()
            XCTFail("Expected OAuth error")
        } catch let error as HelixError {
            guard case .oauth(let oauthError) = error else {
                return XCTFail("Expected oauth error, got \(error)")
            }
            XCTAssertEqual(oauthError.error, "invalid_grant")
        }

        let storedToken = try await store.loadToken()
        XCTAssertNil(storedToken)
        let authenticated = await provider.isAuthenticated()
        XCTAssertFalse(authenticated)
    }

    func test_refreshLogsOutOnParsedOAuthErrorWithoutStatus() async throws {
        // Preserve the HTTP 400 even when the JSON omits status; this is
        // a rejection, unlike a 503 with the same missing JSON field.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"error":"invalid_grant","error_description":"Invalid refresh token"}"#)
        ])
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        do {
            try await provider.refreshIfNeeded()
            XCTFail("Expected OAuth error")
        } catch let error as HelixError {
            guard case .oauth(let oauthError) = error else {
                return XCTFail("Expected oauth error, got \(error)")
            }
            XCTAssertEqual(oauthError.status, 400)
        }

        let storedToken = try await store.loadToken()
        XCTAssertNil(storedToken)
    }

    func test_concurrentRefreshCallsCoalesceIntoOneTokenRequest() async throws {
        let transport = GatedRefreshTransport(body: Self.refreshedTokenJSON)
        let store = InMemoryTokenStore(token: Self.seedToken)
        let provider = makeProvider(store: store, httpClient: transport)

        // Start one refresh and hold it at the network layer.
        let first = Task { try await provider.refreshIfNeeded() }
        try await transport.waitForFirstRequest()

        // Pile a second caller on while the first is in flight, and give it
        // time to reach the provider — the actor is idle (the first refresh
        // is parked on the transport gate), so it only needs a scheduling
        // pass to coalesce.
        let second = Task { try await provider.refreshIfNeeded() }
        try await Task.sleep(for: .milliseconds(100))

        await transport.release()
        try await first.value
        try await second.value

        // Exactly one request reached the token endpoint — with the rotated
        // refresh token from the seed — and both callers share its outcome.
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        let body = String(data: requests.first?.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(body?.contains("refresh_token=r1"), true)
        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.accessToken, "new")
        XCTAssertEqual(storedToken?.refreshToken, "r2")
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "new")
    }

    func test_setTokenStampsObtainedAt() async throws {
        let store = InMemoryTokenStore()
        let provider = makeProvider(store: store, httpClient: MockHTTPClient(responses: []))

        let before = Date.now
        try await provider.setToken(OAuthToken(accessToken: "access", refreshToken: "r1", expiresIn: 3600))
        let after = Date.now

        let storedToken = try await store.loadToken()
        let obtainedAt = try XCTUnwrap(storedToken?.obtainedAt)
        XCTAssertGreaterThanOrEqual(obtainedAt, before)
        XCTAssertLessThanOrEqual(obtainedAt, after)

        // A caller-provided timestamp must be preserved, not overwritten.
        let explicitDate = Date.now.addingTimeInterval(-1_000)
        try await provider.setToken(OAuthToken(accessToken: "access", obtainedAt: explicitDate))
        let secondToken = try await store.loadToken()
        XCTAssertEqual(secondToken?.obtainedAt, explicitDate)
    }

    func test_accessTokenProactivelyRefreshesExpiredToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.refreshedTokenJSON)
        ])
        let store = InMemoryTokenStore(token: OAuthToken(
            accessToken: "old",
            refreshToken: "r1",
            expiresIn: 30,
            obtainedAt: Date.now.addingTimeInterval(-3_600)
        ))
        let provider = makeProvider(store: store, httpClient: transport)

        let accessToken = try await provider.accessToken()

        XCTAssertEqual(accessToken, "new")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        let storedToken = try await store.loadToken()
        XCTAssertEqual(storedToken?.accessToken, "new")
        XCTAssertEqual(storedToken?.refreshToken, "r2")
        // The refreshed token came off the wire without obtained_at — the
        // provider must stamp it so the next expiry check works.
        XCTAssertNotNil(storedToken?.obtainedAt)
    }

    func test_accessTokenDoesNotRefreshFreshToken() async throws {
        let transport = MockHTTPClient(responses: [])
        let store = InMemoryTokenStore(token: OAuthToken(
            accessToken: "current",
            refreshToken: "r1",
            expiresIn: 3600,
            obtainedAt: .now
        ))
        let provider = makeProvider(store: store, httpClient: transport)

        let accessToken = try await provider.accessToken()

        XCTAssertEqual(accessToken, "current")
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func test_accessTokenReturnsExpiredTokenWithoutRefreshToken() async throws {
        // No refresh token means nothing proactive can be done — return the
        // stale token unchanged and let the downstream 401 surface.
        let transport = MockHTTPClient(responses: [])
        let store = InMemoryTokenStore(token: OAuthToken(
            accessToken: "stale",
            expiresIn: 30,
            obtainedAt: Date.now.addingTimeInterval(-3_600)
        ))
        let provider = makeProvider(store: store, httpClient: transport)

        let accessToken = try await provider.accessToken()

        XCTAssertEqual(accessToken, "stale")
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }
}

/// Serves the token response only after `release()` is called, so a test can
/// hold a refresh in flight at the network layer while more callers pile in.
private actor GatedRefreshTransport: HTTPClient {
    private let body: String
    private var isReleased = false
    private var requests: [URLRequest] = []

    init(body: String) {
        self.body = body
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }

    func release() {
        isReleased = true
    }

    func waitForFirstRequest() async throws {
        for _ in 0..<100 {
            if !requests.isEmpty {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw HelixError.networkError("Timed out waiting for the first token request")
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        while !isReleased {
            try await Task.sleep(for: .milliseconds(10))
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        return (Data(body.utf8), response)
    }
}
