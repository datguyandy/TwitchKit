import Foundation

/// Top-level TwitchKit facade.
///
/// `TwitchClient` wires together OAuth/token storage, Helix HTTP APIs, and EventSub WebSocket APIs.
public final class TwitchClient: Sendable {
    /// Twitch application client ID used for Helix and OAuth requests.
    public let clientID: String

    /// OAuth and token-management helper.
    public let auth: TwitchAuth

    /// Helix HTTP API client.
    public let api: HelixClient

    /// EventSub WebSocket client.
    public let eventSub: EventSubClient

    /// Creates a TwitchKit client with shared auth, Helix, and EventSub components.
    ///
    /// - Parameters:
    ///   - clientId: Twitch application client ID.
    ///   - clientSecret: Optional Twitch application client secret for flows that require it.
    ///   - tokenNamespace: Optional namespace for the default keychain token store.
    ///   - tokenStore: Optional custom token store. Use this when a host app owns persistence.
    ///   - httpClient: HTTP transport used for OAuth and Helix requests.
    ///   - requestConfiguration: Request-level behavior for Helix HTTP calls.
    ///   - retryPolicy: Automatic retry behavior for Helix HTTP calls.
    ///   - responseMetadataHandler: Optional callback invoked with metadata from successful Helix responses.
    ///   - eventBufferingPolicy: Buffering policy for EventSub notifications when consumers are slower than Twitch delivery.
    ///   - isLive: Returns whether the channel is live, used to tune EventSub reconnect behavior.
    ///     **The default `{ false }` GIVES UP**: after a dropped socket, the non-live reconnect
    ///     ladder makes 5 attempts (~31s of cumulative backoff), then emits `.disconnected` on
    ///     `eventSub.connectionState` and parks — it will not retry again until the network path
    ///     drops and returns, or `connect()` is called again. Supply a closure that returns `true`
    ///     while the channel is live to get the persistent ladder that retries forever with a
    ///     short, 5s-capped backoff.
    ///   - pathMonitor: Network-path monitor driving EventSub's path-aware reconnect. Defaults to a `NWPathMonitor`-backed monitor.
    ///   - eventSubSocketFactory: Creates the EventSub WebSocket for a given URL. Defaults to
    ///     `URLSession.shared.webSocketTask(with:)`; primarily a seam for injecting fake sockets in tests.
    public init(
        clientID clientId: String,
        clientSecret: String? = nil,
        tokenNamespace: String? = nil,
        tokenStore: (any TwitchTokenStore)? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil,
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000),
        isLive: @escaping @Sendable () async -> Bool = { false },
        pathMonitor: NetworkPathMonitoring = NWPathNetworkMonitor(),
        eventSubSocketFactory: @escaping @Sendable (URL) -> any EventSubWebSocket = { URLSession.shared.webSocketTask(with: $0) }
    ) {
        self.clientID = clientId
        let oauthClient = TwitchOAuthClient(clientID: clientId, clientSecret: clientSecret, httpClient: httpClient)
        let auth = if let tokenStore {
            TwitchAuth(oauthClient: oauthClient, tokenStore: tokenStore)
        } else {
            TwitchAuth(
                clientID: clientId,
                clientSecret: clientSecret,
                tokenNamespace: tokenNamespace,
                httpClient: httpClient
            )
        }
        let api = HelixClient(
            auth: auth,
            clientID: clientId,
            httpClient: httpClient,
            requestConfiguration: requestConfiguration,
            retryPolicy: retryPolicy,
            responseMetadataHandler: responseMetadataHandler
        )
        self.auth = auth
        self.api = api
        self.eventSub = EventSubClient(
            api: api,
            isLive: isLive,
            pathMonitor: pathMonitor,
            socketFactory: eventSubSocketFactory,
            eventBufferingPolicy: eventBufferingPolicy
        )
    }
}
