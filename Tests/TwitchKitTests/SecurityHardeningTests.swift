import Foundation
import Security
import XCTest
@testable import TwitchKit

/// Device code polling, OAuth state and redirects, token ownership, caching,
/// Keychain attributes, secret redaction and webhook transport validation.
final class SecurityHardeningTests: XCTestCase {
    private static let tokenJSON = #"{"access_token":"device-token","refresh_token":"refresh-token","expires_in":14124,"scope":["user:read:email"],"token_type":"bearer"}"#

    // MARK: - Device code flow (Twitch's documented bodies)

    func test_pollDeviceCodeWaitsThroughDocumentedPendingBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"status":400,"message":"authorization_pending"}"#),
            .json(statusCode: 400, body: #"{"status":400,"message":"Authorization_Pending"}"#),
            .json(statusCode: 200, body: Self.tokenJSON),
        ])
        let client = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        let token = try await client.pollDeviceCode(deviceCode: "device-code", scopes: [.userReadEmail], interval: 0, expiresIn: 60)

        XCTAssertEqual(token.accessToken, "device-token")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 3)
        let fields = try formFields(requests[0])
        XCTAssertEqual(fields["scopes"], "user:read:email")
        XCTAssertNil(fields["scope"])
        XCTAssertEqual(fields["device_code"], "device-code")
        XCTAssertEqual(fields["grant_type"], "urn:ietf:params:oauth:grant-type:device_code")
    }

    func test_documentedPendingBodyIsRecognisedOnTheErrorType() throws {
        let pending = try JSONDecoder.twitch().decode(
            TwitchOAuthError.self,
            from: Data(#"{"status":400,"message":"authorization_pending"}"#.utf8)
        )
        XCTAssertTrue(pending.isAuthorizationPending)
        XCTAssertFalse(pending.isSlowDown)

        XCTAssertTrue(TwitchOAuthError(error: "slow_down").isSlowDown)
        XCTAssertTrue(TwitchOAuthError(error: "oauth_error", message: "SLOW_DOWN").isSlowDown)
        XCTAssertTrue(TwitchOAuthError(error: "oauth_error", message: "invalid device code").isDeviceCodeRejected)
    }

    func test_exchangeDeviceCodeSurfacesSlowDownFromMessage() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"status":400,"message":"slow_down"}"#),
        ])
        let client = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        do {
            _ = try await client.exchangeDeviceCode(deviceCode: "device-code")
            XCTFail("Expected an OAuth error")
        } catch HelixError.oauth(let error) {
            // pollDeviceCode backs off on exactly this predicate.
            XCTAssertTrue(error.isSlowDown)
        }
    }

    func test_invalidDeviceCodeMapsToDeviceCodeRejected() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"status":400,"message":"authorization_pending"}"#),
            .json(statusCode: 400, body: #"{"status":400,"message":"invalid device code"}"#),
        ])
        let client = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        do {
            _ = try await client.pollDeviceCode(deviceCode: "device-code", interval: 0, expiresIn: 60)
            XCTFail("Expected deviceCodeRejected")
        } catch HelixError.deviceCodeRejected(let error) {
            XCTAssertEqual(error.message, "invalid device code")
            XCTAssertEqual(error.status, 400)
        }
    }

    func test_pollDeviceCodePastDeadlineThrowsDeviceCodeRejected() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"status":400,"message":"authorization_pending"}"#),
        ])
        let client = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        do {
            _ = try await client.pollDeviceCode(deviceCode: "device-code", interval: 1, expiresIn: 1)
            XCTFail("Expected deviceCodeRejected")
        } catch HelixError.deviceCodeRejected(let error) {
            XCTAssertEqual(error.error, "expired_token")
        }
    }

    // MARK: - OAuth state and redirects

    func test_makeStateIsRandomBase64URL() {
        let states = (0..<20).map { _ in TwitchOAuthClient.makeState() }
        XCTAssertEqual(Set(states).count, states.count)
        let alphabet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        for state in states {
            XCTAssertEqual(state.count, 43) // 32 bytes, unpadded base64url
            XCTAssertTrue(state.unicodeScalars.allSatisfy(alphabet.contains), state)
        }
    }

    func test_authorizationURLsAlwaysCarryAState() throws {
        let client = TwitchOAuthClient(clientID: "client-id")
        let urls = [
            client.implicitGrantURL(scopes: [.userReadChat]),
            client.authorizationCodeURL(scopes: [.userReadChat]),
            client.oidcImplicitGrantURL(scopes: [.userReadChat], nonce: "n"),
            client.oidcAuthorizationCodeURL(scopes: [.userReadChat], nonce: "n"),
        ]
        for url in urls {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let state = try XCTUnwrap(items.first { $0.name == "state" }?.value)
            XCTAssertEqual(state.count, 43)
        }

        let explicit = client.implicitGrantURL(scopes: [.userReadChat], state: "chosen-state")
        XCTAssertEqual(
            URLComponents(url: explicit, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value,
            "chosen-state"
        )
    }

    func test_parseCallbackReadsImplicitFragment() throws {
        // Twitch's documented implicit-grant redirect.
        let url = URL(string: "http://localhost:3000/#access_token=73d0f8mkabpbmjp921asv2jaidwxn&scope=channel%3Amanage%3Apolls+channel%3Aread%3Apolls&state=c3ab8aa609ea11e793ae92361f002671&token_type=bearer")!

        let result = try TwitchOAuthClient.parseCallback(url, expectedState: "c3ab8aa609ea11e793ae92361f002671")

        guard case .accessToken(let token, let idToken) = result else {
            return XCTFail("Expected an access token, got \(result)")
        }
        XCTAssertEqual(token.accessToken, "73d0f8mkabpbmjp921asv2jaidwxn")
        XCTAssertEqual(token.scope, ["channel:manage:polls", "channel:read:polls"])
        XCTAssertEqual(token.tokenType, "bearer")
        XCTAssertNil(idToken)
    }

    func test_parseCallbackReadsAuthorizationCodeQuery() throws {
        let url = URL(string: "http://localhost:3000/?code=gulfwdmys5lsm6qyz4xiz9q32l10&scope=channel%3Amanage%3Apolls+channel%3Aread%3Apolls&state=c3ab8aa609ea11e793ae92361f002671")!

        let result = try TwitchOAuthClient.parseCallback(url, expectedState: "c3ab8aa609ea11e793ae92361f002671")

        XCTAssertEqual(result, .authorizationCode("gulfwdmys5lsm6qyz4xiz9q32l10", scopes: [.channelManagePolls, .channelReadPolls]))
    }

    func test_parseCallbackSurfacesTwitchError() throws {
        let url = URL(string: "http://localhost:3000/?error=access_denied&error_description=The+user+denied+you+access&state=c3ab8aa609ea11e793ae92361f002671")!

        XCTAssertThrowsError(try TwitchOAuthClient.parseCallback(url, expectedState: "c3ab8aa609ea11e793ae92361f002671")) { error in
            guard case HelixError.oauth(let oauthError) = error else {
                return XCTFail("Expected oauth error, got \(error)")
            }
            XCTAssertEqual(oauthError.error, "access_denied")
            XCTAssertEqual(oauthError.message, "The user denied you access")
        }
    }

    func test_parseCallbackRejectsMissingOrWrongState() {
        let wrong = URL(string: "http://localhost:3000/#access_token=abc&state=attacker")!
        let missing = URL(string: "http://localhost:3000/#access_token=abc")!
        let errorWithWrongState = URL(string: "http://localhost:3000/?error=access_denied&state=attacker")!

        for url in [wrong, missing, errorWithWrongState] {
            XCTAssertThrowsError(try TwitchOAuthClient.parseCallback(url, expectedState: "expected")) { error in
                guard case HelixError.oauthStateMismatch = error else {
                    return XCTFail("Expected oauthStateMismatch, got \(error)")
                }
            }
        }
        XCTAssertThrowsError(try TwitchOAuthClient.parseCallback(URL(string: "http://localhost/#access_token=abc&state=")!, expectedState: ""))
    }

    func test_constantTimeEquals() {
        XCTAssertTrue(TwitchOAuthClient.constantTimeEquals("abc", "abc"))
        XCTAssertFalse(TwitchOAuthClient.constantTimeEquals("abc", "abd"))
        XCTAssertFalse(TwitchOAuthClient.constantTimeEquals("abc", "abcd"))
        XCTAssertFalse(TwitchOAuthClient.constantTimeEquals("", "a"))
    }

    // MARK: - Token client ID

    func test_tokenInfoRejectsAnotherClientsToken() throws {
        let info = TwitchTokenInfo(clientID: "other-client", expiresIn: 100)
        XCTAssertFalse(info.isIssued(toClientID: "client-id"))
        XCTAssertThrowsError(try info.verifyClientID("client-id")) { error in
            guard case HelixError.tokenClientMismatch(let expected, let actual) = error else {
                return XCTFail("Expected tokenClientMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "client-id")
            XCTAssertEqual(actual, "other-client")
        }
        XCTAssertNoThrow(try TwitchTokenInfo(clientID: "client-id", expiresIn: 100).verifyClientID("client-id"))
    }

    func test_missingClientIDIsNotMaskedAndNeverMatches() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: #"{"login":"twitchdev","expires_in":100}"#)])
        let client = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        let validated = try await client.validate("token")
        let info = try XCTUnwrap(validated)
        XCTAssertNil(info.clientID)
        XCTAssertThrowsError(try client.verifyClientID(of: info))
    }

    func test_validateOwnTokenRejectsSubstitutedToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"client_id":"other-client","login":"twitchdev","user_id":"1","scopes":[],"expires_in":100}"#),
            .json(statusCode: 200, body: #"{"client_id":"client-id","login":"twitchdev","user_id":"1","scopes":[],"expires_in":100}"#),
        ])
        let client = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        do {
            _ = try await client.validateOwnToken("token")
            XCTFail("Expected tokenClientMismatch")
        } catch HelixError.tokenClientMismatch(let expected, let actual) {
            XCTAssertEqual(expected, "client-id")
            XCTAssertEqual(actual, "other-client")
        }
        let own = try await client.validateOwnToken("token")
        XCTAssertEqual(own?.clientID, "client-id")
    }

    func test_authenticateWithCallbackURLValidatesAndStoresToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"client_id":"client-id","login":"twitchdev","user_id":"1","scopes":["user:read:chat"],"expires_in":100}"#),
        ])
        let store = InMemoryTokenStore()
        let auth = TwitchAuth(oauthClient: TwitchOAuthClient(clientID: "client-id", httpClient: transport), tokenStore: store)

        try await auth.authenticate(
            withCallbackURL: URL(string: "https://auth.example.com/cb#access_token=abc&state=s1&token_type=bearer")!,
            expectedState: "s1"
        )

        let stored = try await store.loadToken()
        XCTAssertEqual(stored?.accessToken, "abc")
    }

    func test_authenticateWithCallbackURLRejectsOtherClientsToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"client_id":"other-client","login":"twitchdev","user_id":"1","scopes":[],"expires_in":100}"#),
        ])
        let store = InMemoryTokenStore()
        let auth = TwitchAuth(oauthClient: TwitchOAuthClient(clientID: "client-id", httpClient: transport), tokenStore: store)

        do {
            try await auth.authenticate(
                withCallbackURL: URL(string: "https://auth.example.com/cb#access_token=abc&state=s1")!,
                expectedState: "s1"
            )
            XCTFail("Expected tokenClientMismatch")
        } catch HelixError.tokenClientMismatch {}
        let stored = try await store.loadToken()
        XCTAssertNil(stored)
    }

    // MARK: - Caching

    func test_defaultSessionKeepsNothingOnDisk() {
        let configuration = URLSessionHTTPClient().session.configuration
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertFalse(URLSessionHTTPClient().session === URLSession.shared)
    }

    func test_helixAndOAuthRequestsIgnoreLocalCache() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"id":"1","login":"twitchdev","display_name":"TwitchDev","profile_image_url":"https://example.com/p.png","broadcaster_type":""}]}"#),
            .json(statusCode: 200, body: #"{"client_id":"client-id","expires_in":100}"#),
            .json(statusCode: 200, body: Self.tokenJSON),
        ])
        let oauth = TwitchOAuthClient(clientID: "client-id", httpClient: transport)
        let auth = TwitchAuth(oauthClient: oauth, tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "access-token")))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchUser()
        _ = try await oauth.validate("access-token")
        _ = try await oauth.refreshAccessToken(refreshToken: "refresh-token")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 3)
        for request in requests {
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData, request.url?.absoluteString ?? "")
        }
    }

    // MARK: - Keychain

    func test_keychainAttributeDictionariesSetDeviceOnlyAccessibility() {
        let expected = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        XCTAssertEqual(KeychainStore.updateAttributes(data: Data())[kSecAttrAccessible as String] as? String, expected)
        XCTAssertEqual(KeychainStore.migrationAttributes()[kSecAttrAccessible as String] as? String, expected)
    }

    func test_keychainQueryIncludesAccessGroupWhenGiven() {
        XCTAssertEqual(KeychainStore.query(key: "k", accessGroup: "TEAM.group")[kSecAttrAccessGroup as String] as? String, "TEAM.group")
        XCTAssertNil(KeychainStore.query(key: "k")[kSecAttrAccessGroup as String])
        _ = KeychainTokenStore(clientID: "client-id", namespace: "n", accessGroup: "TEAM.group")
    }

    func test_keychainErrorReportsInteractionNotAllowed() {
        XCTAssertTrue(KeychainError.loadFailed(errSecInteractionNotAllowed).isInteractionNotAllowed)
        XCTAssertFalse(KeychainError.saveFailed(errSecDuplicateItem).isInteractionNotAllowed)
        XCTAssertEqual(KeychainError.saveFailed(errSecDuplicateItem).status, errSecDuplicateItem)
    }

    // MARK: - Redaction

    func test_secretsAreRedactedFromDescriptionsAndDumps() throws {
        let token = OAuthToken(accessToken: "secret-access-token", refreshToken: "secret-refresh-token", expiresIn: 60, scope: ["user:read:chat"], tokenType: "bearer")
        let client = TwitchOAuthClient(clientID: "client-id", clientSecret: "secret-client-secret")
        let device = DeviceCodeAuthorization(deviceCode: "secret-device-code", expiresIn: 1800, interval: 5, userCode: "ABCDEFGH", verificationURI: "https://www.twitch.tv/activate")
        let callback = TwitchOAuthCallback.accessToken(token, idToken: "secret-id-token")
        let code = TwitchOAuthCallback.authorizationCode("secret-auth-code", scopes: [])
        let transport = EventSubSubscriptionTransport.webhook(callback: URL(string: "https://example.com/eventsub")!, secret: "secret-webhook-secret")

        let secrets = ["secret-access-token", "secret-refresh-token", "secret-client-secret", "secret-device-code", "secret-id-token", "secret-auth-code", "secret-webhook-secret"]
        let values: [Any] = [token, client, device, callback, code, transport, [token], Optional(token) as Any]
        for value in values {
            var dumped = ""
            dump(value, to: &dumped)
            for output in [String(describing: value), String(reflecting: value), dumped] {
                for secret in secrets {
                    XCTAssertFalse(output.contains(secret), "\(secret) leaked in: \(output)")
                }
            }
        }
        XCTAssertTrue(String(describing: device).contains("ABCDEFGH"))
        XCTAssertTrue(String(describing: client).contains("client-id"))
    }

    // MARK: - Webhook transport

    func test_webhookTransportRequiresHTTPSOn443AndAValidSecret() {
        let secret = "webhook-secret"
        XCTAssertNoThrow(try EventSubSubscriptionTransport.webhook(callback: URL(string: "https://example.com/eventsub")!, secret: secret).validate())
        XCTAssertNoThrow(try EventSubSubscriptionTransport.webhook(callback: URL(string: "https://example.com:443/eventsub")!, secret: secret).validate())
        XCTAssertThrowsError(try EventSubSubscriptionTransport.webhook(callback: URL(string: "http://example.com/eventsub")!, secret: secret).validate())
        XCTAssertThrowsError(try EventSubSubscriptionTransport.webhook(callback: URL(string: "https://example.com:8443/eventsub")!, secret: secret).validate())
        XCTAssertThrowsError(try EventSubSubscriptionTransport.webhook(callback: URL(string: "https://example.com/eventsub")!, secret: "short").validate())
    }

    // MARK: - Privacy manifest

    func test_privacyManifestIsBundled() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((plist["NSPrivacyAccessedAPITypes"] as? [Any])?.count, 0)
    }

    // MARK: - Helpers

    private func formFields(_ request: URLRequest) throws -> [String: String] {
        let body = try XCTUnwrap(String(data: request.httpBody ?? Data(), encoding: .utf8))
        var components = URLComponents()
        components.percentEncodedQuery = body
        var fields: [String: String] = [:]
        for item in components.queryItems ?? [] {
            fields[item.name] = item.value
        }
        return fields
    }
}
