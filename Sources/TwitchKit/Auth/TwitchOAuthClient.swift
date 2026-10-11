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
        clientId: String,
        clientSecret: String? = nil,
        redirectUri: String = TwitchOAuthClient.defaultRedirectURI,
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
        implicitGrantURL(rawScopes: scopes.map(\.rawValue), state: state, forceVerify: forceVerify)
    }

    /// Builds an OAuth implicit grant URL with raw scope strings.
    public func implicitGrantURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "token", scopes: rawScopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL for apps that can exchange the code safely.
    public func authorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationCodeURL(rawScopes: scopes.map(\.rawValue), state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL with raw scope strings.
    public func authorizationCodeURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "code", scopes: rawScopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL when the app also needs an ID token for sign-in.
    public func oidcImplicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oidcImplicitGrantURL(rawScopes: scopes.map(\.rawValue), claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL with raw scope strings.
    public func oidcImplicitGrantURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(
            responseType: "token id_token",
            scopes: oidcScopes(rawScopes),
            state: state,
            forceVerify: forceVerify,
            nonce: nonce,
            claims: claims
        )
    }

    /// Builds an OIDC authorization code URL for sign-in plus Twitch API access.
    public func oidcAuthorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oidcAuthorizationCodeURL(rawScopes: scopes.map(\.rawValue), claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC authorization code URL with raw scope strings.
    public func oidcAuthorizationCodeURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(
            responseType: "code",
            scopes: oidcScopes(rawScopes),
            state: state,
            forceVerify: forceVerify,
            nonce: nonce,
            claims: claims
        )
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
        try await requestAppAccessToken(rawScopes: scopes.map(\.rawValue))
    }

    /// Requests an app access token with raw scope strings.
    public func requestAppAccessToken(rawScopes: [String]) async throws -> OAuthToken {
        guard let clientSecret else { throw HelixError.missingClientSecret }
        return try await postTokenRequest(fields: [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "client_credentials",
            "scope": rawScopes.joined(separator: " "),
        ])
    }

    /// Starts Twitch's device code flow for clients with limited text input.
    public func startDeviceCodeFlow(scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> DeviceCodeAuthorization {
        try await startDeviceCodeFlow(rawScopes: scopes.map(\.rawValue))
    }

    /// Starts Twitch's device code flow with raw scope strings.
    public func startDeviceCodeFlow(rawScopes: [String]) async throws -> DeviceCodeAuthorization {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/device")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = twitchFormEncoded([
            "client_id": clientId,
            "scopes": rawScopes.joined(separator: " "),
        ])

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw HelixError.invalidResponse }
        guard http.statusCode == 200 else {
            throw oauthError(from: data, status: http.statusCode, fallbackMessage: "Device code request failed")
        }
        return try JSONDecoder.twitch().decode(DeviceCodeAuthorization.self, from: data)
    }

    /// Polls Twitch for device-code completion using an authorization response.
    public func pollDeviceCode(
        _ authorization: DeviceCodeAuthorization,
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases
    ) async throws -> OAuthToken {
        try await pollDeviceCode(
            deviceCode: authorization.deviceCode,
            rawScopes: scopes.map(\.rawValue),
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
        try await pollDeviceCode(
            deviceCode: deviceCode,
            rawScopes: scopes.map(\.rawValue),
            interval: interval,
            expiresIn: expiresIn
        )
    }

    /// Polls Twitch for device-code completion using raw scope strings.
    public func pollDeviceCode(
        deviceCode: String,
        rawScopes: [String],
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
                return try await exchangeDeviceCode(deviceCode: deviceCode, rawScopes: rawScopes)
            } catch HelixError.oauth(let error) where error.error == "authorization_pending" {
                try await Task.sleep(for: .seconds(pollingInterval))
            } catch HelixError.oauth(let error) where error.error == "slow_down" {
                pollingInterval += 5
                try await Task.sleep(for: .seconds(pollingInterval))
            }
        }
    }

    /// Performs one device-code token exchange request.
    public func exchangeDeviceCode(deviceCode: String, scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> OAuthToken {
        try await exchangeDeviceCode(deviceCode: deviceCode, rawScopes: scopes.map(\.rawValue))
    }

    /// Performs one device-code token exchange request with raw scope strings.
    public func exchangeDeviceCode(deviceCode: String, rawScopes: [String]) async throws -> OAuthToken {
        try await postTokenRequest(fields: [
            "client_id": clientId,
            "scope": rawScopes.joined(separator: " "),
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
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

    /// Returns whether the access token is valid according to Twitch.
    public func validateAccessToken(_ accessToken: String) async throws -> Bool {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/validate")!)
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw HelixError.invalidResponse }
        switch http.statusCode {
        case 200: return true
        case 401: return false
        case 500...599: throw HelixError.serverError(status: http.statusCode)
        default: throw oauthError(from: data, status: http.statusCode, fallbackMessage: "Token validation failed")
        }
    }

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
