import Foundation

/// Stores OAuth tokens for a Twitch client.
public protocol TwitchTokenStore: Sendable {
    /// Loads the currently stored token, if one exists.
    func loadToken() async throws -> OAuthToken?

    /// Saves the current OAuth token.
    func saveToken(_ token: OAuthToken) async throws

    /// Deletes any stored OAuth token.
    func deleteToken() async throws
}

/// A Keychain-backed token store for Apple platforms.
public actor KeychainTokenStore: TwitchTokenStore {
    private let tokenKey: String

    /// Creates a Keychain token store scoped to a Twitch app and optional account namespace.
    public init(clientID clientId: String, namespace: String? = nil) {
        tokenKey = "com.twitchkit.\(clientId).\(namespace ?? "default").oauthToken"
    }

    public func loadToken() async throws -> OAuthToken? {
        guard let data = try KeychainStore.load(key: tokenKey) else {
            return nil
        }
        return try JSONDecoder.twitch().decode(OAuthToken.self, from: data)
    }

    public func saveToken(_ token: OAuthToken) async throws {
        let data = try JSONEncoder.twitch().encode(token)
        try KeychainStore.save(key: tokenKey, data: data)
    }

    public func deleteToken() async throws {
        KeychainStore.delete(key: tokenKey)
    }
}

/// An in-memory token store useful for tests, previews, and backend-owned OAuth.
public actor InMemoryTokenStore: TwitchTokenStore {
    private var token: OAuthToken?

    public init(token: OAuthToken? = nil) {
        self.token = token
    }

    public func loadToken() async throws -> OAuthToken? {
        token
    }

    public func saveToken(_ token: OAuthToken) async throws {
        self.token = token
    }

    public func deleteToken() async throws {
        token = nil
    }
}
