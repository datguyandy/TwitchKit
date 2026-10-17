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
///
/// Tokens are stored as generic passwords with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: readable by
/// background work after the first unlock, never synced to iCloud Keychain
/// or restored onto another device. Before the first unlock after a reboot,
/// loads and saves throw a ``KeychainError`` whose
/// ``KeychainError/isInteractionNotAllowed`` is `true`.
public actor KeychainTokenStore: TwitchTokenStore {
    private let tokenKey: String
    private let accessGroup: String?

    /// Creates a Keychain token store scoped to a Twitch app and optional account namespace.
    ///
    /// - Parameters:
    ///   - clientID: Your Twitch client ID.
    ///   - namespace: Separates tokens for several accounts.
    ///   - accessGroup: A Keychain access group (from your app's
    ///     `keychain-access-groups` entitlement) to share the token with
    ///     extensions or other apps from your team. `nil` uses the app's
    ///     default group. Tokens stored in one group aren't found in another.
    public init(clientID clientId: String, namespace: String? = nil, accessGroup: String? = nil) {
        tokenKey = "com.twitchkit.\(clientId).\(namespace ?? "default").oauthToken"
        self.accessGroup = accessGroup
    }

    public func loadToken() async throws -> OAuthToken? {
        guard let data = try KeychainStore.load(key: tokenKey, accessGroup: accessGroup) else {
            return nil
        }
        return try JSONDecoder.twitch().decode(OAuthToken.self, from: data)
    }

    public func saveToken(_ token: OAuthToken) async throws {
        let data = try JSONEncoder.twitch().encode(token)
        try KeychainStore.save(key: tokenKey, data: data, accessGroup: accessGroup)
    }

    public func deleteToken() async throws {
        KeychainStore.delete(key: tokenKey, accessGroup: accessGroup)
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
