import Foundation
import os

private let tokenProviderLogger = Logger(subsystem: "com.twitchkit", category: "token-provider")

/// Provides access tokens for authenticated Twitch API requests.
public protocol TwitchAccessTokenProvider: Sendable {
    /// Returns a usable access token or throws if no token is available.
    func accessToken() async throws -> String

    /// Refreshes the current token when a refresh token is available.
    func refreshIfNeeded() async throws
}

/// Loads, stores, validates, and refreshes OAuth tokens.
public actor TwitchTokenProvider: TwitchAccessTokenProvider {
    private let oauthClient: TwitchOAuthClient
    private let tokenStore: any TwitchTokenStore

    private var tokenRevision: UInt64 = 0
    private var cachedToken: OAuthToken?
    private var hasLoadedStoredToken = false

    public init(oauthClient: TwitchOAuthClient, tokenStore: any TwitchTokenStore) {
        self.oauthClient = oauthClient
        self.tokenStore = tokenStore
    }

    /// Returns whether a token is available locally.
    public func isAuthenticated() async -> Bool {
        (try? await currentToken()) != nil
    }

    /// Returns the current token, loading it from storage if necessary.
    public func token() async throws -> OAuthToken {
        guard let token = try await currentToken() else {
            throw HelixError.notAuthenticated
        }
        return token
    }

    public func accessToken() async throws -> String {
        let token = try await token()

        // Proactive refresh: renew a token that is expired (or expires
        // within the next minute) before handing it out, instead of letting
        // the request fail with a 401 first. Without a refresh token the
        // stale value is returned as-is — the 401 surfaces downstream.
        guard token.isExpired(within: 60), token.refreshToken != nil else {
            return token.accessToken
        }

        do {
            try await refreshIfNeeded()
        } catch {
            // Error rule: a definitive rejection means performRefresh()
            // already logged out — the session is dead and the stale access
            // token is unusable, so propagate. Anything transient (network
            // failure, token-endpoint 5xx, cancellation) left the stored
            // token intact: swallow it and return the possibly stale access
            // token — Helix's reactive 401-retry remains the safety net.
            if Self.isDefinitiveRefreshRejection(error) {
                throw error
            }
            return token.accessToken
        }
        return try await self.token().accessToken
    }

    /// Stores an externally obtained token, stamping `obtainedAt` with the
    /// current time when the caller didn't provide one so expiry can be
    /// computed later.
    public func setToken(_ token: OAuthToken) async throws {
        tokenRevision &+= 1
        var token = token
        if token.obtainedAt == nil {
            token = OAuthToken(
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                expiresIn: token.expiresIn,
                scope: token.scope,
                tokenType: token.tokenType,
                obtainedAt: .now
            )
        }
        cachedToken = token
        hasLoadedStoredToken = true
        try await tokenStore.saveToken(token)
    }

    /// The in-flight refresh attempt, if any. Actors are reentrant, so two
    /// tasks calling refreshIfNeeded() concurrently would both suspend at
    /// the network call and race with the same refresh token — and Twitch
    /// rotates refresh tokens on use, so the loser would clobber the fresh
    /// token and kill the session. Concurrent callers await this task and
    /// share its outcome instead of issuing a second refresh.
    private var inFlightRefresh: Task<Void, Error>?

    public func refreshIfNeeded() async throws {
        // Coalesce concurrent callers onto the in-flight attempt: they
        // succeed together or fail with the same underlying error.
        if let inFlightRefresh {
            try await inFlightRefresh.value
            return
        }

        // Unstructured Task (inheriting this actor's isolation) so the
        // attempt's lifetime is owned by the provider, not the first
        // caller — a cancelled initiator must not tear the refresh out
        // from under the coalesced waiters.
        let attempt = Task {
            try await performRefresh()
        }
        inFlightRefresh = attempt
        defer { inFlightRefresh = nil }
        try await attempt.value
    }

    private func performRefresh() async throws {
        // Read the refresh token here, inside the attempt, so it reflects
        // the token that is current at the moment the network call is made.
        let token = try await token()
        guard let refreshToken = token.refreshToken else {
            tokenProviderLogger.warning("Token refresh requested but no refresh token is available")
            throw HelixError.unauthorized
        }

        let revision = tokenRevision
        do {
            let refreshedToken = try await oauthClient.refreshAccessToken(refreshToken: refreshToken)
            // Logout or token replacement supersedes this network response.
            guard tokenRevision == revision else { return }
            try await setToken(refreshedToken)
            tokenProviderLogger.info("Token refresh succeeded")
        } catch {
            // Only destroy the stored token when the OAuth server
            // DEFINITIVELY rejected the refresh. A network timeout, a
            // cancellation, or a 5xx from the token endpoint says nothing
            // about the refresh token's validity — logging out on those
            // would erase a perfectly recoverable session over a blip, and
            // the same refresh token remains usable on the next attempt.
            if tokenRevision == revision, Self.isDefinitiveRefreshRejection(error) {
                tokenProviderLogger.warning("Token refresh rejected by OAuth server; logging out")
                try await logout()
            }
            throw error
        }
    }

    /// Whether a refresh failure proves the session is dead, so the stored
    /// token should be destroyed. Only a client-error rejection from the
    /// token endpoint qualifies: `HelixError.oauth` with a 400/401/403
    /// status (e.g. `invalid_grant` for a revoked or already-rotated
    /// refresh token). A `nil` status means Twitch sent a parseable OAuth
    /// error body without a status field — still a deliberate rejection,
    /// so it counts. `oauth` with a 5xx status is the fallback path for a
    /// token-endpoint outage, and everything else (networkError,
    /// invalidResponse, CancellationError, …) is transient: rethrow and
    /// leave the store alone.
    private static func isDefinitiveRefreshRejection(_ error: any Error) -> Bool {
        guard let helixError = error as? HelixError else {
            return false
        }
        switch helixError {
        case .unauthorized:
            return true
        case .oauth(let oauthError):
            guard let status = oauthError.status else { return true }
            return status == 400 || status == 401 || status == 403
        default:
            return false
        }
    }

    /// Validates the current token and refreshes it if Twitch reports it as invalid.
    public func validateToken() async throws {
        guard let token = try await currentToken() else {
            tokenProviderLogger.info("No token to validate")
            return
        }

        let revision = tokenRevision
        let isValid = try await oauthClient.validateAccessToken(token.accessToken)
        guard tokenRevision == revision else { return }
        if !isValid {
            tokenProviderLogger.warning("Token validation failed; attempting refresh")
            try await refreshIfNeeded()
        }
    }

    /// Deletes the current token from memory and storage.
    public func logout() async throws {
        tokenRevision &+= 1
        cachedToken = nil
        hasLoadedStoredToken = true
        try await tokenStore.deleteToken()
    }

    private func currentToken() async throws -> OAuthToken? {
        if let cachedToken {
            return cachedToken
        }

        guard !hasLoadedStoredToken else {
            return nil
        }

        let revision = tokenRevision
        let storedToken = try await tokenStore.loadToken()
        guard tokenRevision == revision else { return cachedToken }
        cachedToken = storedToken
        // Only latch a SUCCESSFUL load. A nil read is not proof of
        // "signed out": Keychain-backed stores can transiently report
        // protected items as missing (errSecItemNotFound) during early
        // launch / prewarming after a reboot, before first unlock.
        // Latching that nil would poison this provider for its entire
        // lifetime — every later call short-circuiting to
        // `.notAuthenticated` while a perfectly good token sits in the
        // store. Leaving the flag false means signed-out providers pay
        // one store read per call, which is negligible; transient misses
        // self-heal on the next read. (`logout()` still latches — an
        // explicit sign-out must not resurrect a token the store failed
        // to delete.)
        hasLoadedStoredToken = storedToken != nil
        return storedToken
    }
}
