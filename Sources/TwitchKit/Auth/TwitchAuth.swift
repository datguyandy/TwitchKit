import Foundation

/// A Twitch OAuth scope, such as `user:read:chat`.
///
/// The static members cover every scope Twitch documents. Twitch adds scopes
/// over time, so any scope string works too, without waiting for a TwitchKit
/// release: `TwitchScope("user:read:new_thing")`, or a string literal where a
/// `TwitchScope` is expected:
///
/// ```swift
/// let url = twitch.auth.authorizationCodeURL(scopes: [.userReadChat, "user:read:new_thing"])
/// ```
public struct TwitchScope: RawRepresentable, Hashable, Sendable, Codable, CaseIterable,
    ExpressibleByStringLiteral, CustomStringConvertible {
    /// The scope string Twitch uses, for example `user:read:chat`.
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String {
        rawValue
    }

    /// Every scope Twitch documents, in the order they're declared below.
    public static let allCases: [TwitchScope] = [
        .analyticsReadExtensions,
        .analyticsReadGames,
        .bitsRead,
        .channelBot,
        .channelManageAds,
        .channelReadAds,
        .channelManageBroadcast,
        .channelReadCharity,
        .channelManageClips,
        .channelEditCommercial,
        .channelReadEditors,
        .channelManageExtensions,
        .channelReadGoals,
        .channelReadGuestStar,
        .channelManageGuestStar,
        .channelReadHypeTrain,
        .channelManageModerators,
        .channelReadPolls,
        .channelManagePolls,
        .channelReadPredictions,
        .channelManagePredictions,
        .channelManageRaids,
        .channelReadRedemptions,
        .channelManageRedemptions,
        .channelManageSchedule,
        .channelReadStreamKey,
        .channelReadSubscriptions,
        .channelManageVideos,
        .channelReadVips,
        .channelManageVips,
        .channelModerate,
        .clipsEdit,
        .editorManageClips,
        .moderationRead,
        .moderatorManageAnnouncements,
        .moderatorManageAutomod,
        .moderatorReadAutomodSettings,
        .moderatorManageAutomodSettings,
        .moderatorReadBannedUsers,
        .moderatorManageBannedUsers,
        .moderatorReadBlockedTerms,
        .moderatorManageBlockedTerms,
        .moderatorReadChatMessages,
        .moderatorManageChatMessages,
        .moderatorReadChatSettings,
        .moderatorManageChatSettings,
        .moderatorReadChatters,
        .moderatorReadFollowers,
        .moderatorReadGuestStar,
        .moderatorManageGuestStar,
        .moderatorReadModerators,
        .moderatorReadShieldMode,
        .moderatorManageShieldMode,
        .moderatorReadShoutouts,
        .moderatorManageShoutouts,
        .moderatorReadSuspiciousUsers,
        .moderatorManageSuspiciousUsers,
        .moderatorReadUnbanRequests,
        .moderatorManageUnbanRequests,
        .moderatorReadVips,
        .moderatorReadWarnings,
        .moderatorManageWarnings,
        .userBot,
        .userEdit,
        .userEditBroadcast,
        .userReadBlockedUsers,
        .userManageBlockedUsers,
        .userReadBroadcast,
        .userReadChat,
        .userManageChatColor,
        .userReadEmail,
        .userReadEmotes,
        .userReadFollows,
        .userReadModeratedChannels,
        .userReadSubscriptions,
        .userReadWhispers,
        .userManageWhispers,
        .userWriteChat,
        .chatEdit,
        .chatRead,
        .whispersRead,
    ]

    // MARK: Twitch API and EventSub

    public static let analyticsReadExtensions = TwitchScope("analytics:read:extensions")
    public static let analyticsReadGames = TwitchScope("analytics:read:games")
    public static let bitsRead = TwitchScope("bits:read")
    public static let channelBot = TwitchScope("channel:bot")
    public static let channelManageAds = TwitchScope("channel:manage:ads")
    public static let channelReadAds = TwitchScope("channel:read:ads")
    public static let channelManageBroadcast = TwitchScope("channel:manage:broadcast")
    public static let channelReadCharity = TwitchScope("channel:read:charity")
    public static let channelManageClips = TwitchScope("channel:manage:clips")
    public static let channelEditCommercial = TwitchScope("channel:edit:commercial")
    public static let channelReadEditors = TwitchScope("channel:read:editors")
    public static let channelManageExtensions = TwitchScope("channel:manage:extensions")
    public static let channelReadGoals = TwitchScope("channel:read:goals")
    public static let channelReadGuestStar = TwitchScope("channel:read:guest_star")
    public static let channelManageGuestStar = TwitchScope("channel:manage:guest_star")
    public static let channelReadHypeTrain = TwitchScope("channel:read:hype_train")
    public static let channelManageModerators = TwitchScope("channel:manage:moderators")
    public static let channelReadPolls = TwitchScope("channel:read:polls")
    public static let channelManagePolls = TwitchScope("channel:manage:polls")
    public static let channelReadPredictions = TwitchScope("channel:read:predictions")
    public static let channelManagePredictions = TwitchScope("channel:manage:predictions")
    public static let channelManageRaids = TwitchScope("channel:manage:raids")
    public static let channelReadRedemptions = TwitchScope("channel:read:redemptions")
    public static let channelManageRedemptions = TwitchScope("channel:manage:redemptions")
    public static let channelManageSchedule = TwitchScope("channel:manage:schedule")
    public static let channelReadStreamKey = TwitchScope("channel:read:stream_key")
    public static let channelReadSubscriptions = TwitchScope("channel:read:subscriptions")
    public static let channelManageVideos = TwitchScope("channel:manage:videos")
    public static let channelReadVips = TwitchScope("channel:read:vips")
    public static let channelManageVips = TwitchScope("channel:manage:vips")
    public static let channelModerate = TwitchScope("channel:moderate")
    public static let clipsEdit = TwitchScope("clips:edit")
    public static let editorManageClips = TwitchScope("editor:manage:clips")
    public static let moderationRead = TwitchScope("moderation:read")
    public static let moderatorManageAnnouncements = TwitchScope("moderator:manage:announcements")
    public static let moderatorManageAutomod = TwitchScope("moderator:manage:automod")
    public static let moderatorReadAutomodSettings = TwitchScope("moderator:read:automod_settings")
    public static let moderatorManageAutomodSettings = TwitchScope("moderator:manage:automod_settings")
    public static let moderatorReadBannedUsers = TwitchScope("moderator:read:banned_users")
    public static let moderatorManageBannedUsers = TwitchScope("moderator:manage:banned_users")
    public static let moderatorReadBlockedTerms = TwitchScope("moderator:read:blocked_terms")
    public static let moderatorManageBlockedTerms = TwitchScope("moderator:manage:blocked_terms")
    public static let moderatorReadChatMessages = TwitchScope("moderator:read:chat_messages")
    public static let moderatorManageChatMessages = TwitchScope("moderator:manage:chat_messages")
    public static let moderatorReadChatSettings = TwitchScope("moderator:read:chat_settings")
    public static let moderatorManageChatSettings = TwitchScope("moderator:manage:chat_settings")
    public static let moderatorReadChatters = TwitchScope("moderator:read:chatters")
    public static let moderatorReadFollowers = TwitchScope("moderator:read:followers")
    public static let moderatorReadGuestStar = TwitchScope("moderator:read:guest_star")
    public static let moderatorManageGuestStar = TwitchScope("moderator:manage:guest_star")
    public static let moderatorReadModerators = TwitchScope("moderator:read:moderators")
    public static let moderatorReadShieldMode = TwitchScope("moderator:read:shield_mode")
    public static let moderatorManageShieldMode = TwitchScope("moderator:manage:shield_mode")
    public static let moderatorReadShoutouts = TwitchScope("moderator:read:shoutouts")
    public static let moderatorManageShoutouts = TwitchScope("moderator:manage:shoutouts")
    public static let moderatorReadSuspiciousUsers = TwitchScope("moderator:read:suspicious_users")
    public static let moderatorManageSuspiciousUsers = TwitchScope("moderator:manage:suspicious_users")
    public static let moderatorReadUnbanRequests = TwitchScope("moderator:read:unban_requests")
    public static let moderatorManageUnbanRequests = TwitchScope("moderator:manage:unban_requests")
    public static let moderatorReadVips = TwitchScope("moderator:read:vips")
    public static let moderatorReadWarnings = TwitchScope("moderator:read:warnings")
    public static let moderatorManageWarnings = TwitchScope("moderator:manage:warnings")
    public static let userBot = TwitchScope("user:bot")
    public static let userEdit = TwitchScope("user:edit")
    public static let userEditBroadcast = TwitchScope("user:edit:broadcast")
    public static let userReadBlockedUsers = TwitchScope("user:read:blocked_users")
    public static let userManageBlockedUsers = TwitchScope("user:manage:blocked_users")
    public static let userReadBroadcast = TwitchScope("user:read:broadcast")
    public static let userReadChat = TwitchScope("user:read:chat")
    public static let userManageChatColor = TwitchScope("user:manage:chat_color")
    public static let userReadEmail = TwitchScope("user:read:email")
    public static let userReadEmotes = TwitchScope("user:read:emotes")
    public static let userReadFollows = TwitchScope("user:read:follows")
    public static let userReadModeratedChannels = TwitchScope("user:read:moderated_channels")
    public static let userReadSubscriptions = TwitchScope("user:read:subscriptions")
    public static let userReadWhispers = TwitchScope("user:read:whispers")
    public static let userManageWhispers = TwitchScope("user:manage:whispers")
    public static let userWriteChat = TwitchScope("user:write:chat")

    // MARK: IRC Chat

    public static let chatEdit = TwitchScope("chat:edit")
    public static let chatRead = TwitchScope("chat:read")

    // MARK: PubSub-specific Chat

    public static let whispersRead = TwitchScope("whispers:read")
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

/// Placeholder printed in place of a secret by TwitchKit's
/// `description`, `debugDescription` and `customMirror` implementations.
let redactedPlaceholder = "<redacted>"

/// `print`, string interpolation, `debugPrint` and `dump` never show the
/// access or refresh token.
extension OAuthToken: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        let refresh = refreshToken == nil ? "nil" : redactedPlaceholder
        let scopes = scope.map { "\($0)" } ?? "nil"
        let expires = expiresIn.map(String.init) ?? "nil"
        return "OAuthToken(accessToken: \(redactedPlaceholder), refreshToken: \(refresh), expiresIn: \(expires), scope: \(scopes), tokenType: \(tokenType ?? "nil"))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "accessToken": redactedPlaceholder,
                "refreshToken": refreshToken == nil ? "nil" : redactedPlaceholder,
                "expiresIn": expiresIn as Any,
                "scope": scope as Any,
                "tokenType": tokenType as Any,
                "obtainedAt": obtainedAt as Any,
            ],
            displayStyle: .struct
        )
    }
}

/// The initial response for Twitch's OAuth device code flow.
///
/// `deviceCode` can be exchanged for the user's tokens, so it's redacted
/// from `description`, `debugDescription` and `dump(_:)`. `userCode` is meant
/// to be shown to the user and is printed.
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

extension DeviceCodeAuthorization: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "DeviceCodeAuthorization(deviceCode: \(redactedPlaceholder), expiresIn: \(expiresIn), interval: \(interval), userCode: \(userCode), verificationUri: \(verificationUri))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "deviceCode": redactedPlaceholder,
                "expiresIn": expiresIn,
                "interval": interval,
                "userCode": userCode,
                "verificationUri": verificationUri,
            ],
            displayStyle: .struct
        )
    }
}

/// Convenience facade that composes OAuth URL/exchange helpers with token storage and refresh.
///
/// ## Signing in from an iOS or macOS app
///
/// - Prefer the **device code flow** with an app registered as Client Type
///   *Public*: ``startDeviceCodeFlow(scopes:)`` then
///   ``pollDeviceCode(_:scopes:)``. It needs no client secret and still gets
///   refresh tokens; Twitch has no PKCE, so it's the only safe way for a
///   shipped app to hold a refresh token.
/// - The **implicit grant** (``implicitGrantURL(scopes:state:forceVerify:)``)
///   is legacy: no refresh token, and the token arrives in a redirect URL.
/// - **Never ship a client secret in an app.** Pass `clientSecret` only on a
///   server, where the authorization code and client credentials flows run.
///
/// Present browser flows with `ASWebAuthenticationSession`
/// (`prefersEphemeralWebBrowserSession = true`, and an HTTPS callback via
/// `.https(host:path:)` on iOS 17.4+/macOS 14.4+), send a fresh
/// ``TwitchOAuthClient/makeState()``, and hand the redirect to
/// ``authenticate(withCallbackURL:expectedState:)``. See ``TwitchOAuthClient``
/// for a full example. OIDC `id_token`s are not verified by TwitchKit;
/// verify the signature (JWKS), `iss`, `aud`, `exp` and `nonce` yourself.
public actor TwitchAuth: TwitchAccessTokenProvider {
    public nonisolated let oauthClient: TwitchOAuthClient
    public nonisolated let tokenProvider: TwitchTokenProvider

    /// Redirect URI — Twitch requires the value to match one of the redirect URLs registered for the app.
    public static let redirectURI = TwitchOAuthClient.defaultRedirectURI

    /// Every scope known to this package.
    public static let allScopeCases = TwitchScope.allCases

    /// Every scope known to this package as raw Twitch scope strings.
    public static let allScopes = allScopeCases.map(\.rawValue)

    /// The minimal set used when an OAuth helper is called without explicit scopes:
    /// reading and sending chat, which ``EventSubClient/joinChat(broadcasterID:userID:additionalSubscriptions:)`` and Send Chat Message need.
    ///
    /// Twitch asks apps to request only the scopes they use, so anything beyond chat —
    /// email, followers, subscriptions, channel management, the stream key — must be
    /// requested explicitly, for example
    /// `scopes: TwitchAuth.defaultScopeCases + [.moderatorReadFollowers]`.
    public static let defaultScopeCases: [TwitchScope] = [
        .userReadChat,
        .userWriteChat,
    ]

    /// ``defaultScopeCases`` as raw Twitch scope strings.
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public nonisolated func oidcAuthorizationCodeURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oauthClient.oidcAuthorizationCodeURL(rawScopes: rawScopes, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Handles an OAuth redirect: checks its `state`, then stores the
    /// implicit-grant token or exchanges the authorization code.
    ///
    /// An implicit-grant token is validated with Twitch, and rejected unless
    /// it was issued to this app's client ID, before it's stored.
    ///
    /// - Throws: ``HelixError/oauthStateMismatch`` for a forged or stale
    ///   redirect, ``HelixError/oauth(_:)`` when the user denied access,
    ///   ``HelixError/tokenClientMismatch(expected:actual:)`` for a token
    ///   issued to another app, or ``HelixError/unauthorized(_:)`` when
    ///   Twitch rejects the token.
    public func authenticate(withCallbackURL url: URL, expectedState: String) async throws {
        switch try TwitchOAuthClient.parseCallback(url, expectedState: expectedState) {
        case .accessToken(let token, _):
            guard try await oauthClient.validateOwnToken(token.accessToken) != nil else {
                throw HelixError.unauthorized(nil)
            }
            try await tokenProvider.setToken(token)
        case .authorizationCode(let code, _):
            try await authenticate(withAuthorizationCode: code)
        }
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public nonisolated func requestAppAccessToken(rawScopes: [String]) async throws -> OAuthToken {
        try await oauthClient.requestAppAccessToken(rawScopes: rawScopes)
    }

    /// Starts Twitch's device code flow for clients with limited text input.
    public nonisolated func startDeviceCodeFlow(scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> DeviceCodeAuthorization {
        try await oauthClient.startDeviceCodeFlow(scopes: scopes)
    }

    /// Starts Twitch's device code flow with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
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
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
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

    /// Validates the current token with Twitch, refreshing it if Twitch
    /// reports it as invalid. See ``TwitchTokenProvider/validateToken()``.
    ///
    /// - Returns: What Twitch reports about the current token, or `nil` when
    ///   there's no token.
    @discardableResult
    public func validateToken() async throws -> TwitchTokenInfo? {
        try await tokenProvider.validateToken()
    }

    /// Validates the token now and then every `interval` (an hour by
    /// default), as Twitch requires, for as long as the stream is iterated.
    /// See ``TwitchTokenProvider/validations(every:)``.
    public nonisolated func validations(every interval: Duration = .seconds(3_600)) -> AsyncStream<TokenValidationResult> {
        tokenProvider.validations(every: interval)
    }

    /// Signs out: deletes the stored token, then revokes it on Twitch.
    ///
    /// Revocation is best effort; see
    /// ``TwitchTokenProvider/logout(revokingToken:)``.
    public func logout(revokingToken: Bool = true) async throws {
        try await tokenProvider.logout(revokingToken: revokingToken)
    }
}
