import Foundation

/// What Twitch reports about an access token when it validates it.
public struct TwitchTokenInfo: Sendable, Equatable {
    /// The client ID the token was issued to.
    public let clientID: String

    /// The user the token belongs to. `nil` for an app access token.
    public let userID: String?

    /// The user's login name. `nil` for an app access token.
    public let login: String?

    /// The scopes the user granted, as raw scope strings.
    public let scopes: [String]

    /// Seconds until the token expires, as of ``validatedAt``. `0` for tokens
    /// that don't expire.
    public let expiresIn: Int

    /// When Twitch validated the token.
    public let validatedAt: Date

    public init(
        clientID: String,
        userID: String? = nil,
        login: String? = nil,
        scopes: [String] = [],
        expiresIn: Int,
        validatedAt: Date = .now
    ) {
        self.clientID = clientID
        self.userID = userID
        self.login = login
        self.scopes = scopes
        self.expiresIn = expiresIn
        self.validatedAt = validatedAt
    }

    /// When the token expires, or `nil` for tokens that don't expire.
    public var expiresAt: Date? {
        expiresIn > 0 ? validatedAt.addingTimeInterval(TimeInterval(expiresIn)) : nil
    }

    /// Whether the user granted `scope`.
    public func hasScope(_ scope: TwitchScope) -> Bool {
        scopes.contains(scope.rawValue)
    }

    /// The `/oauth2/validate` response body. Every field is optional because
    /// app access tokens omit the user fields, and Twitch sends `null`
    /// scopes for some tokens.
    struct ValidateResponse: Decodable {
        let clientId: String?
        let userId: String?
        let login: String?
        let scopes: [String]?
        let expiresIn: Int?
    }

    init(validateResponse body: ValidateResponse, validatedAt: Date) {
        self.init(
            clientID: body.clientId ?? "",
            userID: body.userId,
            login: body.login,
            scopes: body.scopes ?? [],
            expiresIn: body.expiresIn ?? 0,
            validatedAt: validatedAt
        )
    }
}

/// The outcome of one scheduled token validation.
public enum TokenValidationResult: Sendable {
    /// Twitch accepted the token, possibly after the provider refreshed a
    /// rejected one.
    case valid(TwitchTokenInfo)

    /// Twitch rejected the token and it couldn't be refreshed (no refresh
    /// token, or Twitch rejected the refresh). Stop using it and ask the user
    /// to sign in again. Carries the refresh error.
    case invalid(any Error)

    /// There's no token to validate.
    case signedOut

    /// Validation couldn't reach a verdict, for example offline or during a
    /// Twitch outage. The token is left alone and validated again at the
    /// next interval.
    case failed(any Error)
}
