import Foundation

/// Supplies app access tokens from Twitch's client credentials flow.
///
/// Use it for Helix calls that need an app token rather than a user token,
/// such as creating EventSub webhook or conduit subscriptions and managing
/// conduits, and for server-side apps with no signed-in user:
///
/// ```swift
/// let appTokens = TwitchAppTokenProvider(clientID: clientID, clientSecret: clientSecret)
/// let appAPI = HelixClient(tokenProvider: appTokens, clientID: clientID)
/// ```
///
/// `TwitchClient` builds one for you as `appAPI` when you pass a client
/// secret. The token is requested on first use and kept in memory. A new one
/// is requested shortly before it expires, or when Twitch rejects it.
/// Concurrent requests share one token request.
///
/// The client credentials flow needs your client secret, so use it only
/// where the secret can be kept private, such as on a server.
public actor TwitchAppTokenProvider: TwitchAccessTokenProvider {
    private let oauthClient: TwitchOAuthClient
    private let scopes: [TwitchScope]
    private let renewalMargin: TimeInterval
    private var token: OAuthToken?
    private var inFlightRequest: Task<OAuthToken, any Error>?
    /// Bumped by `revoke()`, so a token from a request that started earlier
    /// is neither cached nor handed out.
    private var revision: UInt64 = 0

    /// - Parameters:
    ///   - oauthClient: An OAuth client created with your client secret.
    ///   - scopes: Scopes to request. Most app-token endpoints need none.
    ///   - renewalMargin: How long before expiry to request a new token.
    public init(
        oauthClient: TwitchOAuthClient,
        scopes: [TwitchScope] = [],
        renewalMargin: Duration = .seconds(300)
    ) {
        self.oauthClient = oauthClient
        self.scopes = scopes
        self.renewalMargin = Double(renewalMargin.components.seconds)
            + Double(renewalMargin.components.attoseconds) / 1e18
    }

    /// - Parameters:
    ///   - clientID: Your Twitch application's client ID.
    ///   - clientSecret: Your Twitch application's client secret.
    ///   - scopes: Scopes to request. Most app-token endpoints need none.
    ///   - httpClient: HTTP transport for the token requests.
    public init(
        clientID: String,
        clientSecret: String,
        scopes: [TwitchScope] = [],
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.init(
            oauthClient: TwitchOAuthClient(clientID: clientID, clientSecret: clientSecret, httpClient: httpClient),
            scopes: scopes
        )
    }

    /// Returns the current app access token, requesting a new one if there
    /// is none or it expires within the renewal margin.
    public func accessToken() async throws -> String {
        if let token, !isExpiring(token) {
            return token.accessToken
        }
        return try await requestToken().accessToken
    }

    /// Requests a new app access token. App tokens have no refresh token, so
    /// renewing one means requesting another.
    public func refreshIfNeeded() async throws {
        _ = try await requestToken()
    }

    /// Requests a new app access token after Twitch rejected
    /// `rejectedAccessToken`, unless it has already been replaced.
    public func refreshIfNeeded(rejectedAccessToken: String) async throws {
        if let token, token.accessToken != rejectedAccessToken, !isExpiring(token) {
            return
        }
        try await refreshIfNeeded()
    }

    /// Revokes the current token on Twitch and forgets it. The next request
    /// gets a new token.
    ///
    /// A token request already in flight is revoked too, once Twitch issues
    /// it, and its callers get a new token instead.
    public func revoke() async throws {
        revision &+= 1
        let current = token
        token = nil
        // Later callers mustn't join the request that revoke() is discarding.
        let pending = inFlightRequest
        inFlightRequest = nil

        var firstError: (any Error)?
        if let current {
            do {
                try await oauthClient.revokeToken(current.accessToken)
            } catch {
                firstError = error
            }
        }
        if let pending, let issued = try? await pending.value {
            do {
                try await oauthClient.revokeToken(issued.accessToken)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError {
            throw firstError
        }
    }

    /// Requests a token, joining a request that is already in flight.
    private func requestToken() async throws -> OAuthToken {
        while true {
            let startRevision = revision
            let request = inFlightRequest ?? startRequest()
            let result = await request.result
            if inFlightRequest == request {
                inFlightRequest = nil
            }
            let requested = try result.get()
            // revoke() ran while the request was in flight and revokes this
            // token: don't hand it out, request another.
            guard revision == startRevision else { continue }
            token = requested
            return requested
        }
    }

    private func startRequest() -> Task<OAuthToken, any Error> {
        let request = Task { [oauthClient, scopes] in
            let response = try await oauthClient.requestAppAccessToken(scopes: scopes)
            return OAuthToken(
                accessToken: response.accessToken,
                expiresIn: response.expiresIn,
                scope: response.scope,
                tokenType: response.tokenType,
                obtainedAt: .now
            )
        }
        inFlightRequest = request
        return request
    }

    private func isExpiring(_ token: OAuthToken) -> Bool {
        guard let expiresIn = token.expiresIn, let obtainedAt = token.obtainedAt else {
            return false
        }
        let expiresAt = obtainedAt.addingTimeInterval(TimeInterval(expiresIn))
        return Date.now >= expiresAt.addingTimeInterval(-renewalMargin)
    }
}
