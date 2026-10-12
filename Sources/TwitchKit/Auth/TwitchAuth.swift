import Foundation

/// A Twitch OAuth scope.
public enum TwitchScope: String, CaseIterable, Sendable {
    // MARK: Twitch API and EventSub

    case analyticsReadExtensions = "analytics:read:extensions"
    case analyticsReadGames = "analytics:read:games"
    case bitsRead = "bits:read"
    case channelBot = "channel:bot"
    case channelManageAds = "channel:manage:ads"
    case channelReadAds = "channel:read:ads"
    case channelManageBroadcast = "channel:manage:broadcast"
    case channelReadCharity = "channel:read:charity"
    case channelManageClips = "channel:manage:clips"
    case channelEditCommercial = "channel:edit:commercial"
    case channelReadEditors = "channel:read:editors"
    case channelManageExtensions = "channel:manage:extensions"
    case channelReadGoals = "channel:read:goals"
    case channelReadGuestStar = "channel:read:guest_star"
    case channelManageGuestStar = "channel:manage:guest_star"
    case channelReadHypeTrain = "channel:read:hype_train"
    case channelManageModerators = "channel:manage:moderators"
    case channelReadPolls = "channel:read:polls"
    case channelManagePolls = "channel:manage:polls"
    case channelReadPredictions = "channel:read:predictions"
    case channelManagePredictions = "channel:manage:predictions"
    case channelManageRaids = "channel:manage:raids"
    case channelReadRedemptions = "channel:read:redemptions"
    case channelManageRedemptions = "channel:manage:redemptions"
    case channelManageSchedule = "channel:manage:schedule"
    case channelReadStreamKey = "channel:read:stream_key"
    case channelReadSubscriptions = "channel:read:subscriptions"
    case channelManageVideos = "channel:manage:videos"
    case channelReadVips = "channel:read:vips"
    case channelManageVips = "channel:manage:vips"
    case channelModerate = "channel:moderate"
    case clipsEdit = "clips:edit"
    case editorManageClips = "editor:manage:clips"
    case moderationRead = "moderation:read"
    case moderatorManageAnnouncements = "moderator:manage:announcements"
    case moderatorManageAutomod = "moderator:manage:automod"
    case moderatorReadAutomodSettings = "moderator:read:automod_settings"
    case moderatorManageAutomodSettings = "moderator:manage:automod_settings"
    case moderatorReadBannedUsers = "moderator:read:banned_users"
    case moderatorManageBannedUsers = "moderator:manage:banned_users"
    case moderatorReadBlockedTerms = "moderator:read:blocked_terms"
    case moderatorManageBlockedTerms = "moderator:manage:blocked_terms"
    case moderatorReadChatMessages = "moderator:read:chat_messages"
    case moderatorManageChatMessages = "moderator:manage:chat_messages"
    case moderatorReadChatSettings = "moderator:read:chat_settings"
    case moderatorManageChatSettings = "moderator:manage:chat_settings"
    case moderatorReadChatters = "moderator:read:chatters"
    case moderatorReadFollowers = "moderator:read:followers"
    case moderatorReadGuestStar = "moderator:read:guest_star"
    case moderatorManageGuestStar = "moderator:manage:guest_star"
    case moderatorReadModerators = "moderator:read:moderators"
    case moderatorReadShieldMode = "moderator:read:shield_mode"
    case moderatorManageShieldMode = "moderator:manage:shield_mode"
    case moderatorReadShoutouts = "moderator:read:shoutouts"
    case moderatorManageShoutouts = "moderator:manage:shoutouts"
    case moderatorReadSuspiciousUsers = "moderator:read:suspicious_users"
    case moderatorManageSuspiciousUsers = "moderator:manage:suspicious_users"
    case moderatorReadUnbanRequests = "moderator:read:unban_requests"
    case moderatorManageUnbanRequests = "moderator:manage:unban_requests"
    case moderatorReadVips = "moderator:read:vips"
    case moderatorReadWarnings = "moderator:read:warnings"
    case moderatorManageWarnings = "moderator:manage:warnings"
    case userBot = "user:bot"
    case userEdit = "user:edit"
    case userEditBroadcast = "user:edit:broadcast"
    case userReadBlockedUsers = "user:read:blocked_users"
    case userManageBlockedUsers = "user:manage:blocked_users"
    case userReadBroadcast = "user:read:broadcast"
    case userReadChat = "user:read:chat"
    case userManageChatColor = "user:manage:chat_color"
    case userReadEmail = "user:read:email"
    case userReadEmotes = "user:read:emotes"
    case userReadFollows = "user:read:follows"
    case userReadModeratedChannels = "user:read:moderated_channels"
    case userReadSubscriptions = "user:read:subscriptions"
    case userReadWhispers = "user:read:whispers"
    case userManageWhispers = "user:manage:whispers"
    case userWriteChat = "user:write:chat"

    // MARK: IRC Chat

    case chatEdit = "chat:edit"
    case chatRead = "chat:read"

    // MARK: PubSub-specific Chat

    case whispersRead = "whispers:read"
}

/// A token response returned by Twitch OAuth endpoints.
public struct OAuthToken: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int?
    public let scope: [String]?
    public let tokenType: String?

    /// When the token was obtained, stamped locally by TwitchKit when the
    /// token is stored. Twitch's OAuth responses carry no such field, so a
    /// token decoded straight from a token endpoint has `nil` here.
    public let obtainedAt: Date?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: Int? = nil,
        scope: [String]? = nil,
        tokenType: String? = nil,
        obtainedAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.scope = scope
        self.tokenType = tokenType
        self.obtainedAt = obtainedAt
    }

    /// When the token expires (`obtainedAt` plus `expiresIn`), or `nil` when
    /// either value is unknown.
    public var expiresAt: Date? {
        guard let obtainedAt, let expiresIn else {
            return nil
        }
        return obtainedAt.addingTimeInterval(TimeInterval(expiresIn))
    }

    /// Returns whether the token is expired — or will be within `tolerance`
    /// seconds — as of `date`. Returns `false` when the expiry is unknown:
    /// a token without expiry information must not be blocked from use.
    public func isExpired(within tolerance: TimeInterval = 0, at date: Date = .now) -> Bool {
        guard let expiresAt else {
            return false
        }
        return date.addingTimeInterval(tolerance) >= expiresAt
    }
}

/// The initial response for Twitch's OAuth device code flow.
public struct DeviceCodeAuthorization: Decodable, Sendable, Equatable {
    public let deviceCode: String
    public let expiresIn: Int
    public let interval: Int
    public let userCode: String
    public let verificationUri: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        deviceCode: String,
        expiresIn: Int,
        interval: Int,
        userCode: String,
        verificationUri: String
    ) {
        self.deviceCode = deviceCode
        self.expiresIn = expiresIn
        self.interval = interval
        self.userCode = userCode
        self.verificationUri = verificationUri
    }

    public var verificationURL: URL? {
        URL(string: verificationUri)
    }
}

/// Convenience facade that composes OAuth URL/exchange helpers with token storage and refresh.
public actor TwitchAuth: TwitchAccessTokenProvider {
    public nonisolated let oauthClient: TwitchOAuthClient
    public nonisolated let tokenProvider: TwitchTokenProvider

    /// Redirect URI — Twitch requires the value to match one of the redirect URLs registered for the app.
    public static let redirectURI = TwitchOAuthClient.defaultRedirectURI

    /// Every scope known to this package.
    public static let allScopeCases = TwitchScope.allCases

    /// Every scope known to this package as raw Twitch scope strings.
    public static let allScopes = allScopeCases.map(\.rawValue)

    /// A small starter set used by TwitchKit's current convenience APIs.
    public static let defaultScopeCases: [TwitchScope] = [
        .userReadEmail,
        .userReadChat,
        .userWriteChat,
        .moderatorReadFollowers,
        .channelReadSubscriptions,
        .channelManageBroadcast,
        .channelReadStreamKey,
    ]

    /// A small starter set used by TwitchKit's current convenience APIs as raw Twitch scope strings.
    public static let defaultScopes = defaultScopeCases.map(\.rawValue)

    public init(
        clientID clientId: String,
        clientSecret: String? = nil,
        redirectURI redirectUri: String = TwitchAuth.redirectURI,
        tokenNamespace: String? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        let oauthClient = TwitchOAuthClient(
            clientID: clientId,
            clientSecret: clientSecret,
            redirectURI: redirectUri,
            httpClient: httpClient
        )
        self.oauthClient = oauthClient
        self.tokenProvider = TwitchTokenProvider(
            oauthClient: oauthClient,
            tokenStore: KeychainTokenStore(clientID: clientId, namespace: tokenNamespace)
        )
    }

    public init(oauthClient: TwitchOAuthClient, tokenStore: any TwitchTokenStore) {
        self.oauthClient = oauthClient
        self.tokenProvider = TwitchTokenProvider(oauthClient: oauthClient, tokenStore: tokenStore)
    }

    /// Returns whether a token is available locally.
    public var isAuthenticated: Bool {
        get async {
            await tokenProvider.isAuthenticated()
        }
    }

    public func accessToken() async throws -> String {
        try await tokenProvider.accessToken()
    }

    /// Stores externally obtained tokens, useful when the host app or backend owns OAuth.
    public func setToken(_ token: OAuthToken) async throws {
        try await tokenProvider.setToken(token)
    }

    /// Builds an OAuth implicit grant URL for public mobile/client apps without refresh tokens.
    public nonisolated func implicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.implicitGrantURL(scopes: scopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an OAuth implicit grant URL with raw scope strings.
    public nonisolated func implicitGrantURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.implicitGrantURL(rawScopes: rawScopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL for apps that can exchange the code safely.
    public nonisolated func authorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.authorizationCodeURL(scopes: scopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL with raw scope strings.
    public nonisolated func authorizationCodeURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.authorizationCodeURL(rawScopes: rawScopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL when the app also needs an ID token for sign-in.
    public nonisolated func oidcImplicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.oidcImplicitGrantURL(scopes: scopes, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL with raw scope strings.
    public nonisolated func oidcImplicitGrantURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.oidcImplicitGrantURL(rawScopes: rawScopes, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC authorization code URL for sign-in plus Twitch API access.
    public nonisolated func oidcAuthorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.oidcAuthorizationCodeURL(scopes: scopes, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC authorization code URL with raw scope strings.
    public nonisolated func oidcAuthorizationCodeURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.oidcAuthorizationCodeURL(rawScopes: rawScopes, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Exchanges an authorization code for tokens and stores them for future API requests.
    public func authenticate(withAuthorizationCode code: String) async throws {
        let token = try await oauthClient.exchangeAuthorizationCode(code)
        try await tokenProvider.setToken(token)
    }

    /// Requests an app access token with the client credentials flow.
    public nonisolated func requestAppAccessToken(scopes: [TwitchScope] = []) async throws -> OAuthToken {
        try await oauthClient.requestAppAccessToken(scopes: scopes)
    }

    /// Requests an app access token with raw scope strings.
    public nonisolated func requestAppAccessToken(rawScopes: [String]) async throws -> OAuthToken {
        try await oauthClient.requestAppAccessToken(rawScopes: rawScopes)
    }

    /// Starts Twitch's device code flow for clients with limited text input.
    public nonisolated func startDeviceCodeFlow(scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> DeviceCodeAuthorization {
        try await oauthClient.startDeviceCodeFlow(scopes: scopes)
    }

    /// Starts Twitch's device code flow with raw scope strings.
    public nonisolated func startDeviceCodeFlow(rawScopes: [String]) async throws -> DeviceCodeAuthorization {
        try await oauthClient.startDeviceCodeFlow(rawScopes: rawScopes)
    }

    /// Polls Twitch for device-code completion and stores the token on success.
    public func pollDeviceCode(
        _ authorization: DeviceCodeAuthorization,
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases
    ) async throws -> OAuthToken {
        let token = try await oauthClient.pollDeviceCode(authorization, scopes: scopes)
        try await tokenProvider.setToken(token)
        return token
    }

    /// Polls Twitch for device-code completion using an explicit device code.
    public func pollDeviceCode(
        deviceCode: String,
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        interval: Int = 5,
        expiresIn: Int = 600
    ) async throws -> OAuthToken {
        let token = try await oauthClient.pollDeviceCode(
            deviceCode: deviceCode,
            scopes: scopes,
            interval: interval,
            expiresIn: expiresIn
        )
        try await tokenProvider.setToken(token)
        return token
    }

    /// Polls Twitch for device-code completion using raw scope strings.
    public func pollDeviceCode(
        deviceCode: String,
        rawScopes: [String],
        interval: Int = 5,
        expiresIn: Int = 600
    ) async throws -> OAuthToken {
        let token = try await oauthClient.pollDeviceCode(
            deviceCode: deviceCode,
            rawScopes: rawScopes,
            interval: interval,
            expiresIn: expiresIn
        )
        try await tokenProvider.setToken(token)
        return token
    }

    /// Performs one device-code token exchange request and stores the token on success.
    public func exchangeDeviceCode(deviceCode: String, scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> OAuthToken {
        let token = try await oauthClient.exchangeDeviceCode(deviceCode: deviceCode, scopes: scopes)
        try await tokenProvider.setToken(token)
        return token
    }

    /// Performs one device-code token exchange request with raw scope strings and stores the token on success.
    public func exchangeDeviceCode(deviceCode: String, rawScopes: [String]) async throws -> OAuthToken {
        let token = try await oauthClient.exchangeDeviceCode(deviceCode: deviceCode, rawScopes: rawScopes)
        try await tokenProvider.setToken(token)
        return token
    }

    public func refreshIfNeeded() async throws {
        try await tokenProvider.refreshIfNeeded()
    }

    public func refreshIfNeeded(rejectedAccessToken: String) async throws {
        try await tokenProvider.refreshIfNeeded(rejectedAccessToken: rejectedAccessToken)
    }

    public func validateToken() async throws {
        try await tokenProvider.validateToken()
    }

    /// Signs out: deletes the stored token, then revokes it on Twitch.
    ///
    /// Revocation is best effort; see
    /// ``TwitchTokenProvider/logout(revokingToken:)``.
    public func logout(revokingToken: Bool = true) async throws {
        try await tokenProvider.logout(revokingToken: revokingToken)
    }
}
