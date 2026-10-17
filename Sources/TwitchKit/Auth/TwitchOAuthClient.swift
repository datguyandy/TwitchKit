import Foundation
import Security

/// Builds Twitch OAuth URLs and exchanges OAuth grants for tokens.
///
/// ## Choosing a flow for an iOS or macOS app
///
/// - **Device code flow with a "Public" client type** is the recommended
///   on-device flow. Register the app in the Twitch developer console with
///   Client Type *Public*; it then needs no client secret, gets refresh
///   tokens, and refreshes without a secret. Twitch has no PKCE, so this is
///   the only flow that gives a shipped app refresh tokens safely. See
///   ``startDeviceCodeFlow(scopes:)`` and ``pollDeviceCode(_:scopes:)``.
/// - **Implicit grant** is a legacy option for apps without a backend: it
///   returns the access token in the redirect URL's fragment and has no
///   refresh token. See ``implicitGrantURL(scopes:state:forceVerify:)``.
/// - **Authorization code grant** needs the client secret to exchange the
///   code, so run the exchange on your server. **Never ship a client secret
///   in an app**: anything in the bundle can be extracted.
///
/// For the browser-based flows, present the URL with
/// `ASWebAuthenticationSession`, set `prefersEphemeralWebBrowserSession = true`
/// so no Twitch cookies are shared with Safari, and use an HTTPS callback
/// (iOS 17.4+/macOS 14.4+) rather than a custom URL scheme another app could
/// claim. Always send a fresh ``makeState()`` and check it with
/// ``parseCallback(_:expectedState:)``:
///
/// ```swift
/// let state = TwitchOAuthClient.makeState()
/// let url = oauth.implicitGrantURL(scopes: [.userReadChat], state: state)
/// let session = ASWebAuthenticationSession(
///     url: url,
///     callback: .https(host: "auth.example.com", path: "/twitch/callback")
/// ) { callbackURL, error in
///     guard let callbackURL else { return }
///     let result = try? TwitchOAuthClient.parseCallback(callbackURL, expectedState: state)
///     // …
/// }
/// session.prefersEphemeralWebBrowserSession = true
/// session.presentationContextProvider = contextProvider
/// session.start()
/// ```
///
/// The OIDC URL builders return an `id_token` that TwitchKit doesn't verify.
/// If you rely on it for sign-in, verify it yourself: its signature against
/// Twitch's JWKS (`https://id.twitch.tv/oauth2/keys`), `iss`
/// (`https://id.twitch.tv/oauth2`), `aud` (your client ID), `exp`, and that
/// `nonce` matches the one you sent.
///
/// The client secret never appears in `description`, `debugDescription` or
/// `dump(_:)` output.
public struct TwitchOAuthClient: Sendable {
    /// The client ID tokens are requested for.
    public let clientID: String
    private let clientSecret: String?
    private let redirectURI: String
    private let httpClient: any HTTPClient

    /// Redirect URI used when one is not supplied.
    public static let defaultRedirectURI = "https://localhost"

    public init(
        clientID: String,
        clientSecret: String? = nil,
        redirectURI: String = TwitchOAuthClient.defaultRedirectURI,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.httpClient = httpClient
    }

    /// Builds an OAuth implicit grant URL for public mobile/client apps without refresh tokens.
    ///
    /// The implicit flow is legacy: it has no refresh token and returns the
    /// access token in the redirect URL. On iOS and macOS, prefer the device
    /// code flow with a Public client.
    ///
    /// - Parameters:
    ///   - scopes: The scopes to request. Request only what the app uses.
    ///   - state: The CSRF token Twitch echoes back. Pass a fresh
    ///     ``makeState()`` and check it with ``parseCallback(_:expectedState:)``.
    ///     When `nil`, a random state is generated and included anyway; read it
    ///     back from the URL's `state` query item if you need to check it.
    ///   - forceVerify: Whether Twitch re-prompts the user even if they already
    ///     authorized these scopes.
    public func implicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "token", scopes: scopes.map(\.rawValue), state: state, forceVerify: forceVerify)
    }

    /// Builds an OAuth implicit grant URL with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func implicitGrantURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        implicitGrantURL(scopes: rawScopes.map { TwitchScope($0) }, state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL for apps that can exchange the code safely.
    ///
    /// Exchanging the code needs the client secret, so do it on a server;
    /// never ship a client secret in an app.
    ///
    /// - Parameters:
    ///   - scopes: The scopes to request. Request only what the app uses.
    ///   - state: The CSRF token Twitch echoes back. Pass a fresh
    ///     ``makeState()`` and check it with ``parseCallback(_:expectedState:)``.
    ///     When `nil`, a random state is generated and included anyway.
    ///   - forceVerify: Whether Twitch re-prompts the user even if they already
    ///     authorized these scopes.
    public func authorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "code", scopes: scopes.map(\.rawValue), state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func authorizationCodeURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationCodeURL(scopes: rawScopes.map { TwitchScope($0) }, state: state, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL when the app also needs an ID token for sign-in.
    ///
    /// TwitchKit doesn't verify the returned `id_token`; verify its signature
    /// (Twitch's JWKS), `iss`, `aud`, `exp` and `nonce` before trusting it.
    /// When `state` is `nil`, a random state is generated and included.
    public func oidcImplicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(
            responseType: "token id_token",
            scopes: oidcScopes(scopes.map(\.rawValue)),
            state: state,
            forceVerify: forceVerify,
            nonce: nonce,
            claims: claims
        )
    }

    /// Builds an OIDC implicit grant URL with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func oidcImplicitGrantURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oidcImplicitGrantURL(scopes: rawScopes.map { TwitchScope($0) }, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC authorization code URL for sign-in plus Twitch API access.
    ///
    /// TwitchKit doesn't verify the returned `id_token`; verify its signature
    /// (Twitch's JWKS), `iss`, `aud`, `exp` and `nonce` before trusting it.
    /// When `state` is `nil`, a random state is generated and included.
    public func oidcAuthorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(
            responseType: "code",
            scopes: oidcScopes(scopes.map(\.rawValue)),
            state: state,
            forceVerify: forceVerify,
            nonce: nonce,
            claims: claims
        )
    }

    /// Builds an OIDC authorization code URL with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func oidcAuthorizationCodeURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oidcAuthorizationCodeURL(scopes: rawScopes.map { TwitchScope($0) }, claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Exchanges an authorization code for an OAuth token.
    public func exchangeAuthorizationCode(_ code: String) async throws -> OAuthToken {
        guard let clientSecret else { throw HelixError.missingClientSecret }
        return try await postTokenRequest(fields: [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
    }

    /// Requests an app access token with the client credentials flow.
    public func requestAppAccessToken(scopes: [TwitchScope] = []) async throws -> OAuthToken {
        guard let clientSecret else { throw HelixError.missingClientSecret }
        return try await postTokenRequest(fields: [
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "client_credentials",
            "scope": Self.joined(scopes),
        ])
    }

    /// Requests an app access token with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func requestAppAccessToken(rawScopes: [String]) async throws -> OAuthToken {
        try await requestAppAccessToken(scopes: rawScopes.map { TwitchScope($0) })
    }

    /// Starts Twitch's device code flow.
    ///
    /// This is the recommended sign-in flow for iOS and macOS apps: register
    /// the app with Client Type *Public* so it needs no client secret and
    /// still gets refresh tokens. Show the user ``DeviceCodeAuthorization/userCode``
    /// and open ``DeviceCodeAuthorization/verificationURL``, then call
    /// ``pollDeviceCode(_:scopes:)``.
    public func startDeviceCodeFlow(scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> DeviceCodeAuthorization {
        var request = URLRequest(
            url: URL(string: "https://id.twitch.tv/oauth2/device")!,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = twitchFormEncoded([
            "client_id": clientID,
            "scopes": Self.joined(scopes),
        ])

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw HelixError.invalidResponse }
        guard http.statusCode == 200 else {
            throw oauthError(from: data, status: http.statusCode, fallbackMessage: "Device code request failed")
        }
        return try JSONDecoder.twitch().decode(DeviceCodeAuthorization.self, from: data)
    }

    /// Starts Twitch's device code flow with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func startDeviceCodeFlow(rawScopes: [String]) async throws -> DeviceCodeAuthorization {
        try await startDeviceCodeFlow(scopes: rawScopes.map { TwitchScope($0) })
    }

    /// Polls Twitch for device-code completion using an authorization response.
    ///
    /// Waits through Twitch's `authorization_pending` and `slow_down`
    /// responses until the user finishes authorizing.
    ///
    /// - Throws: ``HelixError/deviceCodeRejected(_:)`` when the user denied
    ///   access or the code expired (start a new flow), or another
    ///   ``HelixError`` for other failures.
    public func pollDeviceCode(
        _ authorization: DeviceCodeAuthorization,
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases
    ) async throws -> OAuthToken {
        try await pollDeviceCode(
            deviceCode: authorization.deviceCode,
            scopes: scopes,
            interval: authorization.interval,
            expiresIn: authorization.expiresIn
        )
    }

    /// Polls Twitch for device-code completion using an explicit device code.
    public func pollDeviceCode(
        deviceCode: String,
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        interval: Int = 5,
        expiresIn: Int = 600
    ) async throws -> OAuthToken {
        var pollingInterval = max(1, interval)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(max(1, expiresIn)))

        while true {
            try Task.checkCancellation()
            if clock.now >= deadline {
                throw HelixError.deviceCodeRejected(TwitchOAuthError(error: "expired_token", message: "Device code expired"))
            }

            do {
                return try await exchangeDeviceCode(deviceCode: deviceCode, scopes: scopes)
            } catch HelixError.oauth(let error) where error.isAuthorizationPending {
                try await Task.sleep(for: .seconds(pollingInterval))
            } catch HelixError.oauth(let error) where error.isSlowDown {
                pollingInterval += 5
                try await Task.sleep(for: .seconds(pollingInterval))
            }
        }
    }

    /// Polls Twitch for device-code completion using raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func pollDeviceCode(
        deviceCode: String,
        rawScopes: [String],
        interval: Int = 5,
        expiresIn: Int = 600
    ) async throws -> OAuthToken {
        try await pollDeviceCode(
            deviceCode: deviceCode,
            scopes: rawScopes.map { TwitchScope($0) },
            interval: interval,
            expiresIn: expiresIn
        )
    }

    /// Performs one device-code token exchange request.
    ///
    /// - Throws: ``HelixError/oauth(_:)`` with
    ///   ``TwitchOAuthError/isAuthorizationPending`` or
    ///   ``TwitchOAuthError/isSlowDown`` while the user hasn't finished, and
    ///   ``HelixError/deviceCodeRejected(_:)`` once Twitch no longer accepts
    ///   the code (denied, expired or already redeemed).
    public func exchangeDeviceCode(deviceCode: String, scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> OAuthToken {
        do {
            // Twitch's device code token request names the field `scopes`.
            return try await postTokenRequest(fields: [
                "client_id": clientID,
                "scopes": Self.joined(scopes),
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])
        } catch HelixError.oauth(let error) where error.isDeviceCodeRejected {
            throw HelixError.deviceCodeRejected(error)
        }
    }

    /// Performs one device-code token exchange request with raw scope strings.
    @available(*, deprecated, message: "Pass scopes: instead. TwitchScope accepts any scope string, for example TwitchScope(\"user:read:chat\") or a string literal.")
    public func exchangeDeviceCode(deviceCode: String, rawScopes: [String]) async throws -> OAuthToken {
        try await exchangeDeviceCode(deviceCode: deviceCode, scopes: rawScopes.map { TwitchScope($0) })
    }

    /// Scopes as Twitch's space-separated form value.
    private static func joined(_ scopes: [TwitchScope]) -> String {
        scopes.map(\.rawValue).joined(separator: " ")
    }

    /// Refreshes an OAuth token using a refresh token.
    public func refreshAccessToken(refreshToken: String) async throws -> OAuthToken {
        var fields = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ]
        if let clientSecret {
            fields["client_secret"] = clientSecret
        }
        return try await postTokenRequest(fields: fields)
    }

    /// Validates an access token with Twitch.
    ///
    /// Twitch requires apps to validate tokens when they start and hourly
    /// after that; ``TwitchTokenProvider/validations(every:)`` does this.
    ///
    /// - Returns: The token's client ID, user, scopes and expiry, or `nil`
    ///   when Twitch reports the token as invalid or expired.
    public func validate(_ accessToken: String) async throws -> TwitchTokenInfo? {
        guard let data = try await validationResponse(for: accessToken) else { return nil }
        do {
            let body = try JSONDecoder.twitch().decode(TwitchTokenInfo.ValidateResponse.self, from: data)
            return TwitchTokenInfo(validateResponse: body, validatedAt: .now)
        } catch {
            throw HelixError.decodingFailed(eventSubDecodingErrorDescription(error))
        }
    }

    /// Throws ``HelixError/tokenClientMismatch(expected:actual:)`` unless
    /// `info` says the token was issued to this client's ID.
    ///
    /// A token issued to another app's client ID still validates, so an app
    /// that accepts tokens from outside (a backend, a deep link, a paste)
    /// must check this to avoid acting with a substituted token.
    public func verifyClientID(of info: TwitchTokenInfo) throws {
        try info.verifyClientID(clientID)
    }

    /// Validates an access token and checks it was issued to this client's ID.
    ///
    /// - Returns: The token info, or `nil` when Twitch reports the token as
    ///   invalid or expired.
    /// - Throws: ``HelixError/tokenClientMismatch(expected:actual:)`` when
    ///   the token belongs to another client ID.
    public func validateOwnToken(_ accessToken: String) async throws -> TwitchTokenInfo? {
        guard let info = try await validate(accessToken) else { return nil }
        try verifyClientID(of: info)
        return info
    }

    /// Returns whether the access token is valid according to Twitch.
    /// ``validate(_:)`` also returns the token's user, scopes and expiry.
    public func validateAccessToken(_ accessToken: String) async throws -> Bool {
        try await validationResponse(for: accessToken) != nil
    }

    /// The body of a 200 from `/oauth2/validate`, or `nil` for a 401.
    @concurrent
    private func validationResponse(for accessToken: String) async throws -> Data? {
        var request = URLRequest(
            url: URL(string: "https://id.twitch.tv/oauth2/validate")!,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw HelixError.invalidResponse }
        switch http.statusCode {
        case 200: return data
        case 401: return nil
        case 500...599: throw HelixError.serverError(status: http.statusCode)
        default: throw oauthError(from: data, status: http.statusCode, fallbackMessage: "Token validation failed")
        }
    }

    /// Revokes an access token, so Twitch rejects it from now on.
    ///
    /// A token Twitch already considers invalid (expired, or revoked
    /// earlier) counts as revoked.
    @concurrent
    public func revokeToken(_ accessToken: String) async throws {
        var request = URLRequest(
            url: URL(string: "https://id.twitch.tv/oauth2/revoke")!,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = twitchFormEncoded(["client_id": clientID, "token": accessToken])

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw HelixError.invalidResponse }
        switch http.statusCode {
        case 200...299:
            return
        case 400 where Self.isInvalidTokenResponse(data):
            return
        case 500...599:
            throw HelixError.serverError(status: http.statusCode)
        default:
            throw oauthError(from: data, status: http.statusCode, fallbackMessage: "Token revocation failed")
        }
    }

    /// Twitch answers 400 "Invalid token" when revoking a token that is
    /// already expired or revoked.
    static func isInvalidTokenResponse(_ data: Data) -> Bool {
        guard let error = try? JSONDecoder.twitch().decode(TwitchOAuthError.self, from: data) else {
            return false
        }
        return error.message.lowercased().contains("invalid token")
    }

    @concurrent
    private func postTokenRequest(fields: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(
            url: URL(string: "https://id.twitch.tv/oauth2/token")!,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = twitchFormEncoded(fields)

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw HelixError.invalidResponse }
        guard http.statusCode == 200 else {
            throw oauthError(from: data, status: http.statusCode, fallbackMessage: "OAuth token request failed")
        }
        return try JSONDecoder.twitch().decode(OAuthToken.self, from: data)
    }

    /// Mirrors `HelixClient`: transport failures surface as
    /// `HelixError.transport` so callers can pattern-match one error type
    /// across the whole SDK (offline vs. timeout vs. TLS) instead of
    /// special-casing raw `URLError`s from the token endpoints.
    @concurrent
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await httpClient.data(for: request)
        } catch let error as URLError {
            if Task.isCancelled { throw CancellationError() }
            throw HelixError.transport(error)
        }
    }

    private func oauthError(from data: Data, status: Int, fallbackMessage: String) -> HelixError {
        let decoded = try? JSONDecoder.twitch().decode(TwitchOAuthError.self, from: data)
        guard let decoded else {
            return .oauth(TwitchOAuthError.fallback(status: status, message: fallbackMessage))
        }
        // The HTTP status remains authoritative even when the JSON omits it.
        return .oauth(TwitchOAuthError(error: decoded.error, status: status,
                                      message: decoded.message, errorDescription: decoded.errorDescription))
    }

    private func authorizationURL(
        responseType: String,
        scopes: [String],
        state: String?,
        forceVerify: Bool,
        nonce: String? = nil,
        claims: String? = nil
    ) -> URL {
        var queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: responseType),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "force_verify", value: forceVerify ? "true" : "false"),
        ]
        // Always send a state: Twitch echoes it back, so a caller that
        // checks it gets CSRF protection, and one that doesn't loses nothing.
        queryItems.append(URLQueryItem(name: "state", value: state ?? Self.makeState()))
        if let nonce {
            queryItems.append(URLQueryItem(name: "nonce", value: nonce))
        }
        if let claims {
            queryItems.append(URLQueryItem(name: "claims", value: claims))
        }

        var components = URLComponents(string: "https://id.twitch.tv/oauth2/authorize")!
        components.setFormSafeQueryItems(queryItems)
        return components.url!
    }

    private func oidcScopes(_ scopes: [String]) -> [String] {
        scopes.contains("openid") ? scopes : ["openid"] + scopes
    }
}

// MARK: - State and redirect handling

extension TwitchOAuthClient {
    /// Returns a fresh, unguessable OAuth `state` value: 32 random bytes,
    /// base64url-encoded without padding.
    ///
    /// Generate one per authorization request, keep it until the redirect
    /// arrives, and check it with ``parseCallback(_:expectedState:)``. It
    /// works as an OIDC `nonce` too.
    public static func makeState() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            // SystemRandomNumberGenerator is cryptographically secure on
            // Apple platforms; it's only a fallback here.
            var generator = SystemRandomNumberGenerator()
            for index in bytes.indices {
                bytes[index] = UInt8.random(in: .min ... .max, using: &generator)
            }
        }
        return Data(bytes).base64EncodedString()
            .replacing("+", with: "-")
            .replacing("/", with: "_")
            .replacing("=", with: "")
    }

    /// Parses the redirect Twitch sends after an implicit-grant or
    /// authorization-code request, after checking its `state`.
    ///
    /// Reads parameters from both the query (authorization code, errors) and
    /// the fragment (implicit grant tokens). The `state` is compared with
    /// `expectedState` in constant time before anything else is read.
    ///
    /// - Parameters:
    ///   - url: The redirect URL, for example from `ASWebAuthenticationSession`.
    ///   - expectedState: The `state` you put in the authorization URL,
    ///     usually from ``makeState()``.
    /// - Returns: The access token (implicit grant) or authorization code.
    /// - Throws: ``HelixError/oauthStateMismatch`` when `state` is missing or
    ///   differs (ignore the redirect); ``HelixError/oauth(_:)`` when Twitch
    ///   reports an `error` such as `access_denied`;
    ///   ``HelixError/invalidResponse`` when the URL carries neither a token
    ///   nor a code.
    public static func parseCallback(_ url: URL, expectedState: String) throws -> TwitchOAuthCallback {
        let parameters = callbackParameters(from: url)

        guard !expectedState.isEmpty,
              let state = parameters["state"],
              constantTimeEquals(state, expectedState)
        else {
            throw HelixError.oauthStateMismatch
        }

        if let error = parameters["error"] {
            throw HelixError.oauth(TwitchOAuthError(error: error, message: parameters["error_description"]))
        }

        let scopes = parameters["scope"]?
            .split(separator: " ")
            .map { TwitchScope(String($0)) } ?? []

        if let accessToken = parameters["access_token"], !accessToken.isEmpty {
            let token = OAuthToken(
                accessToken: accessToken,
                expiresIn: parameters["expires_in"].flatMap(Int.init),
                scope: scopes.map(\.rawValue),
                tokenType: parameters["token_type"]
            )
            return .accessToken(token, idToken: parameters["id_token"])
        }
        if let code = parameters["code"], !code.isEmpty {
            return .authorizationCode(code, scopes: scopes)
        }
        throw HelixError.invalidResponse
    }

    /// Query and fragment parameters, fragment winning on duplicates. `+`
    /// is decoded as a space, as Twitch encodes the scope list that way.
    private static func callbackParameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
        var parameters: [String: String] = [:]
        for encoded in [components.percentEncodedQuery, components.percentEncodedFragment] {
            guard let encoded, !encoded.isEmpty else { continue }
            var parser = URLComponents()
            parser.percentEncodedQuery = encoded.replacing("+", with: "%20")
            for item in parser.queryItems ?? [] {
                parameters[item.name] = item.value ?? ""
            }
        }
        return parameters
    }

    /// Compares two strings without returning early on the first differing byte.
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        var difference: UInt8 = left.count == right.count ? 0 : 1
        for index in 0..<max(left.count, right.count) {
            let leftByte = index < left.count ? left[index] : 0
            let rightByte = index < right.count ? right[index] : 0
            difference |= leftByte ^ rightByte
        }
        return difference == 0
    }
}

/// What an OAuth redirect carried, from ``TwitchOAuthClient/parseCallback(_:expectedState:)``.
///
/// Tokens and codes are redacted from `description`, `debugDescription` and `dump(_:)`.
public enum TwitchOAuthCallback: Sendable, Equatable {
    /// An implicit-grant redirect: the access token, plus the OIDC `id_token`
    /// when one was requested. TwitchKit doesn't verify the `id_token`;
    /// verify its signature, `iss`, `aud`, `exp` and `nonce` before trusting it.
    case accessToken(OAuthToken, idToken: String?)

    /// An authorization-code redirect: exchange the code for tokens (on
    /// your server, as it needs the client secret).
    case authorizationCode(String, scopes: [TwitchScope])
}

extension TwitchOAuthCallback: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        switch self {
        case .accessToken(let token, let idToken):
            "accessToken(\(token), idToken: \(idToken == nil ? "nil" : redactedPlaceholder))"
        case .authorizationCode(_, let scopes):
            "authorizationCode(\(redactedPlaceholder), scopes: \(scopes))"
        }
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        switch self {
        case .accessToken(let token, let idToken):
            Mirror(self, children: ["token": token, "idToken": idToken == nil ? "nil" : redactedPlaceholder], displayStyle: .enum)
        case .authorizationCode(_, let scopes):
            Mirror(self, children: ["code": redactedPlaceholder, "scopes": scopes], displayStyle: .enum)
        }
    }
}

extension TwitchOAuthClient: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "TwitchOAuthClient(clientID: \(clientID), clientSecret: \(clientSecret == nil ? "nil" : redactedPlaceholder), redirectURI: \(redirectURI))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "clientID": clientID,
                "clientSecret": clientSecret == nil ? "nil" : redactedPlaceholder,
                "redirectURI": redirectURI,
            ],
            displayStyle: .struct
        )
    }
}

func twitchFormEncoded(_ fields: [String: String]) -> Data? {
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+="))
    return fields
        .filter { !$0.value.isEmpty }
        .map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
}
