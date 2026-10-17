import Foundation

/// Top-level TwitchKit facade.
///
/// `TwitchClient` wires together OAuth/token storage, Helix HTTP APIs, and EventSub WebSocket APIs.
public final class TwitchClient: Sendable {
    /// Twitch application client ID used for Helix and OAuth requests.
    public let clientID: String

    /// OAuth and token-management helper.
    public let auth: TwitchAuth

    /// Helix HTTP API client, authorized with the signed-in user's token.
    public let api: HelixClient

    /// Helix client authorized with an app access token, for endpoints that
    /// need one (EventSub webhook and conduit subscriptions, conduits).
    /// `nil` unless the client was created with a `clientSecret`.
    ///
    /// The token comes from a ``TwitchAppTokenProvider``: requested on first
    /// use, kept in memory, and renewed before it expires.
    public let appAPI: HelixClient?

    /// EventSub WebSocket client.
    public let eventSub: EventSubClient

    /// Creates a TwitchKit client with shared auth, Helix, and EventSub components.
    ///
    /// - Parameters:
    ///   - clientID: Twitch application client ID.
    ///   - clientSecret: Optional Twitch application client secret for flows that require it.
    ///     When set, ``appAPI`` makes app-token Helix calls. Keep secrets out of shipped apps.
    ///   - tokenNamespace: Optional namespace for the default keychain token store.
    ///   - tokenStore: Optional custom token store. Use this when a host app owns persistence.
    ///   - httpClient: HTTP transport used for OAuth and Helix requests.
    ///   - requestConfiguration: Request-level behavior for Helix HTTP calls.
    ///   - retryPolicy: Automatic retry behavior for Helix HTTP calls.
    ///   - responseMetadataHandler: Optional callback invoked with metadata from successful Helix responses.
    ///   - eventBufferingPolicy: Buffering policy for EventSub notifications when consumers are slower than Twitch delivery.
    ///   - shouldKeepReconnecting: Asked before each EventSub reconnect attempt. While it returns
    ///     `true` (the default), the client retries forever with a short, 5s-capped backoff. When it
    ///     returns `false`, the client gives up after 5 attempts (~31s of cumulative backoff), emits
    ///     `.disconnected` on `eventSub.connectionState` and parks; it won't retry again until the
    ///     network path drops and returns, or `connect()` is called again. Return `false` when the
    ///     app no longer needs the connection, for example when no chat view is open.
    ///   - pathMonitor: Network-path monitor driving EventSub's path-aware reconnect. Defaults to a `NWPathMonitor`-backed monitor.
    ///   - eventSubSocketFactory: Creates the EventSub WebSocket for a given URL. Defaults to
    ///     `URLSessionHTTPClient.ephemeralSession.webSocketTask(with:)` (no cookies or cache); primarily a seam for injecting fake sockets in tests.
    public init(
        clientID: String,
        clientSecret: String? = nil,
        tokenNamespace: String? = nil,
        tokenStore: (any TwitchTokenStore)? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil,
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000),
        shouldKeepReconnecting: @escaping @Sendable () async -> Bool = { true },
        pathMonitor: any NetworkPathMonitoring = NWPathNetworkMonitor(),
        eventSubSocketFactory: @escaping @Sendable (URL) -> any EventSubWebSocket = { URLSessionHTTPClient.ephemeralSession.webSocketTask(with: $0) }
    ) {
        self.clientID = clientID
        let oauthClient = TwitchOAuthClient(clientID: clientID, clientSecret: clientSecret, httpClient: httpClient)
        let auth = if let tokenStore {
            TwitchAuth(oauthClient: oauthClient, tokenStore: tokenStore)
        } else {
            TwitchAuth(
                clientID: clientID,
                clientSecret: clientSecret,
                tokenNamespace: tokenNamespace,
                httpClient: httpClient
            )
        }
        let api = HelixClient(
            auth: auth,
            clientID: clientID,
            httpClient: httpClient,
            requestConfiguration: requestConfiguration,
            retryPolicy: retryPolicy,
            responseMetadataHandler: responseMetadataHandler
        )
        self.auth = auth
        self.api = api
        self.appAPI = clientSecret.map { _ in
            HelixClient(
                tokenProvider: TwitchAppTokenProvider(oauthClient: oauthClient),
                clientID: clientID,
                httpClient: httpClient,
                requestConfiguration: requestConfiguration,
                retryPolicy: retryPolicy,
                responseMetadataHandler: responseMetadataHandler
            )
        }
        self.eventSub = EventSubClient(
            api: api,
            shouldKeepReconnecting: shouldKeepReconnecting,
            pathMonitor: pathMonitor,
            socketFactory: eventSubSocketFactory,
            eventBufferingPolicy: eventBufferingPolicy
        )
    }
}
