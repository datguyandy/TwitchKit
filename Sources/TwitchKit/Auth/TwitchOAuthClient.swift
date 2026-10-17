import Foundation

/// Builds Twitch OAuth URLs and exchanges OAuth grants for tokens.
public struct TwitchOAuthClient: Sendable {
    private let clientId: String
    private let clientSecret: String?
    private let redirectUri: String
    private let httpClient: any HTTPClient

    /// Redirect URI used when one is not supplied.
    public static let defaultRedirectURI = "https://localhost"

    public init(
        clientID clientId: String,
        clientSecret: String? = nil,
        redirectURI redirectUri: String = TwitchOAuthClient.defaultRedirectURI,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUri = redirectUri
        self.httpClient = httpClient
    }

    /// Builds an OAuth implicit grant URL for public mobile/client apps without refresh tokens.
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
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri,
        ])
    }

    /// Requests an app access token with the client credentials flow.
    public func requestAppAccessToken(scopes: [TwitchScope] = []) async throws -> OAuthToken {
        guard let clientSecret else { throw HelixError.missingClientSecret }
        return try await postTokenRequest(fields: [
            "client_id": clientId,
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

    /// Starts Twitch's device code flow for clients with limited text input.
    public func startDeviceCodeFlow(scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> DeviceCodeAuthorization {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/device")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = twitchFormEncoded([
            "client_id": clientId,
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
                throw HelixError.oauth(TwitchOAuthError(error: "expired_token", message: "Device code expired"))
            }

            do {
                return try await exchangeDeviceCode(deviceCode: deviceCode, scopes: scopes)
            } catch HelixError.oauth(let error) where error.error == "authorization_pending" {
                try await Task.sleep(for: .seconds(pollingInterval))
            } catch HelixError.oauth(let error) where error.error == "slow_down" {
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
    public func exchangeDeviceCode(deviceCode: String, scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> OAuthToken {
        try await postTokenRequest(fields: [
            "client_id": clientId,
            "scope": Self.joined(scopes),
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
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
            "client_id": clientId,
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

    /// Returns whether the access token is valid according to Twitch.
    /// ``validate(_:)`` also returns the token's user, scopes and expiry.
    public func validateAccessToken(_ accessToken: String) async throws -> Bool {
        try await validationResponse(for: accessToken) != nil
    }

    /// The body of a 200 from `/oauth2/validate`, or `nil` for a 401.
    @concurrent
    private func validationResponse(for accessToken: String) async throws -> Data? {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/validate")!)
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
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/revoke")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = twitchFormEncoded(["client_id": clientId, "token": accessToken])

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
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/token")!)
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
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: responseType),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "force_verify", value: forceVerify ? "true" : "false"),
        ]
        if let state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
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
