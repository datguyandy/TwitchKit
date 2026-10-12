import XCTest
@testable import TwitchKit

final class AuthArchitectureTests: XCTestCase {
    func test_tokenProviderStoresExternallyManagedToken() async throws {
        let store = InMemoryTokenStore()
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client-id"),
            tokenStore: store
        )

        try await provider.setToken(OAuthToken(accessToken: "access-token", refreshToken: "refresh-token"))

        let accessToken = try await provider.accessToken()
        let storedToken = try await store.loadToken()
        XCTAssertEqual(accessToken, "access-token")
        XCTAssertEqual(storedToken?.refreshToken, "refresh-token")
    }

    func test_tokenProviderRetriesStoreAfterTransientNilLoad() async throws {
        // Keychain-backed stores can transiently report a stored token as
        // missing (errSecItemNotFound during prewarming / before first
        // unlock after a reboot). The provider must NOT latch that nil as
        // "signed out" — the next read should hit the store again and find
        // the token.
        let store = TransientlyEmptyTokenStore(
            token: OAuthToken(accessToken: "access-token"),
            nilLoads: 1
        )
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client-id"),
            tokenStore: store
        )

        // First read hits the transient miss.
        let first = await provider.isAuthenticated()
        XCTAssertFalse(first)

        // Second read must reach the store and recover.
        let accessToken = try await provider.accessToken()
        XCTAssertEqual(accessToken, "access-token")
    }

    func test_tokenProviderStaysLoggedOutAfterLogout() async throws {
        // Counterpart guard: an explicit logout() must stay logged out even
        // if the store still returns a token afterwards (a delete that
        // failed at the storage layer) — the non-latching nil-load fix must
        // not regress this.
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "stale"))
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client-id"),
            tokenStore: store
        )
        try await provider.logout()
        // InMemoryTokenStore.deleteToken cleared it; re-add to simulate the
        // failed delete.
        try await store.saveToken(OAuthToken(accessToken: "stale"))

        let authenticated = await provider.isAuthenticated()
        XCTAssertFalse(authenticated)
    }

    func test_helixClientAcceptsAnyAccessTokenProvider() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let api = HelixClient(
            tokenProvider: StaticTokenProvider(accessToken: "backend-issued-token"),
            clientID: "client-id",
            httpClient: transport
        )

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer backend-issued-token")
    }
}

/// Returns nil for the first `nilLoads` loads, then the real token —
/// simulating a Keychain whose protected items aren't readable yet during
/// early launch.
private actor TransientlyEmptyTokenStore: TwitchTokenStore {
    private let token: OAuthToken
    private var remainingNilLoads: Int

    init(token: OAuthToken, nilLoads: Int) {
        self.token = token
        self.remainingNilLoads = nilLoads
    }

    func loadToken() async throws -> OAuthToken? {
        if remainingNilLoads > 0 {
            remainingNilLoads -= 1
            return nil
        }
        return token
    }

    func saveToken(_ token: OAuthToken) async throws {}
    func deleteToken() async throws {}
}

private struct StaticTokenProvider: TwitchAccessTokenProvider {
    let token: String

    init(accessToken: String) {
        token = accessToken
    }

    func accessToken() async throws -> String {
        token
    }

    func refreshIfNeeded() async throws {}
}
