import Foundation

/// What Twitch reports about an access token when it validates it.
public struct TwitchTokenInfo: Sendable, Equatable {
    /// The client ID the token was issued to, or `nil` when Twitch's
    /// response didn't include one.
    ///
    /// Check it with ``verifyClientID(_:)`` before trusting a token you
    /// didn't obtain yourself.
    public let clientID: String?

    /// The user the token belongs to. `nil` for an app access token.
    public let userID: String?

    /// The user's login name. `nil` for an app access token.
    public let login: String?

    /// The scopes the user granted.
    public let scopes: [TwitchScope]

    /// Seconds until the token expires, as of ``validatedAt``. `0` for tokens
    /// that don't expire.
    public let expiresIn: Int

    /// When Twitch validated the token.
    public let validatedAt: Date

    public init(
        clientID: String?,
        userID: String? = nil,
        login: String? = nil,
        scopes: [TwitchScope] = [],
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

    /// Whether the token was issued to `clientID`. A missing client ID never matches.
    public func isIssued(toClientID clientID: String) -> Bool {
        guard let actual = self.clientID, !clientID.isEmpty else { return false }
        return TwitchOAuthClient.constantTimeEquals(actual, clientID)
    }

    /// Throws ``HelixError/tokenClientMismatch(expected:actual:)`` unless the
    /// token was issued to `expectedClientID`.
    ///
    /// A token issued to another app still validates, so accepting it would
    /// let that app's token act as yours (token substitution).
    public func verifyClientID(_ expectedClientID: String) throws {
        guard isIssued(toClientID: expectedClientID) else {
            throw HelixError.tokenClientMismatch(expected: expectedClientID, actual: clientID)
        }
    }

    /// Whether the user granted `scope`.
    public func hasScope(_ scope: TwitchScope) -> Bool {
        scopes.contains(scope)
    }

    /// The `/oauth2/validate` response body. Every field is optional because
    /// app access tokens omit the user fields, and Twitch sends `null`
    /// scopes for some tokens.
    struct ValidateResponse: Decodable {
        let clientID: String?
        let userID: String?
        let login: String?
        let scopes: [String]?
        let expiresIn: Int?
    }

    init(validateResponse body: ValidateResponse, validatedAt: Date) {
        self.init(
            clientID: body.clientID,
            userID: body.userID,
            login: body.login,
            scopes: (body.scopes ?? []).map { TwitchScope($0) },
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
