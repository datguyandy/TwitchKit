import Foundation

/// A mutually exclusive filter for listing EventSub subscriptions.
public enum EventSubSubscriptionFilter: Sendable, Equatable {
    case status(EventSubSubscriptionStatus)
    case type(String)
    case userID(String)
    case subscriptionID(String)
    case conduitID(String)

    var queryItem: URLQueryItem {
        switch self {
        case .status(let status):
            URLQueryItem(name: "status", value: status.rawValue)
        case .type(let type):
            URLQueryItem(name: "type", value: type)
        case .userID(let userID):
            URLQueryItem(name: "user_id", value: userID)
        case .subscriptionID(let subscriptionID):
            URLQueryItem(name: "subscription_id", value: subscriptionID)
        case .conduitID(let conduitID):
            URLQueryItem(name: "conduit_id", value: conduitID)
        }
    }

    func validate() throws {
        let value = queryItem.value ?? ""
        guard !value.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "EventSub subscription filter value is required")
            )
        }
    }
}

/// A page of EventSub subscriptions plus account-level cost metadata.
public struct EventSubSubscriptionsPage: Sendable, Equatable {
    /// EventSub subscriptions on this page.
    public let data: [EventSubSubscriptionRecord]

    /// Cursor pagination information, when more pages are available.
    public let pagination: Pagination?

    /// Total number of matching subscriptions, when Twitch includes it.
    public let total: Int?

    /// Total cost of active EventSub subscriptions for the authenticated client.
    public let totalCost: Int?

    /// Maximum EventSub subscription cost allowed for the authenticated client.
    public let maxTotalCost: Int?

    /// HTTP metadata attached by `HelixClient`.
    public let metadata: HelixResponseMetadata?

    public init(
        data: [EventSubSubscriptionRecord],
        pagination: Pagination? = nil,
        total: Int? = nil,
        totalCost: Int? = nil,
        maxTotalCost: Int? = nil,
        metadata: HelixResponseMetadata? = nil
    ) {
        self.data = data
        self.pagination = pagination
        self.total = total
        self.totalCost = totalCost
        self.maxTotalCost = maxTotalCost
        self.metadata = metadata
    }

    /// Cursor used to fetch the next page.
    public var nextCursor: String? {
        pagination?.cursor
    }
}

/// An EventSub subscription returned by Twitch.
public struct EventSubSubscriptionRecord: Decodable, Sendable, Equatable {
    public let id: String
    public let status: EventSubSubscriptionStatus
    public let type: String
    public let version: String
    public let condition: [String: String]
    public let createdAt: Date
    public let transport: Transport
    public let cost: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        status: EventSubSubscriptionStatus,
        type: String,
        version: String,
        condition: [String: String],
        createdAt: Date,
        transport: Transport,
        cost: Int
    ) {
        self.id = id
        self.status = status
        self.type = type
        self.version = version
        self.condition = condition
        self.createdAt = createdAt
        self.transport = transport
        self.cost = cost
    }

    public struct Transport: Decodable, Sendable, Equatable {
        public let method: EventSubTransportMethod
        public let callback: URL?
        public let sessionId: String?
        public let connectedAt: Date?
        public let disconnectedAt: Date?
        public let conduitId: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            method: EventSubTransportMethod,
            callback: URL? = nil,
            sessionId: String? = nil,
            connectedAt: Date? = nil,
            disconnectedAt: Date? = nil,
            conduitId: String? = nil
        ) {
            self.method = method
            self.callback = callback
            self.sessionId = sessionId
            self.connectedAt = connectedAt
            self.disconnectedAt = disconnectedAt
            self.conduitId = conduitId
        }
    }
}

/// EventSub subscription status returned by Twitch.
public enum EventSubSubscriptionStatus: Codable, RawRepresentable, Sendable, Equatable {
    case enabled
    case webhookCallbackVerificationPending
    case webhookCallbackVerificationFailed
    case notificationFailuresExceeded
    case authorizationRevoked
    case moderatorRemoved
    case userRemoved
    case chatUserBanned
    case versionRemoved
    case betaMaintenance
    case websocketDisconnected
    case websocketFailedPingPong
    case websocketReceivedInboundTraffic
    case websocketConnectionUnused
    case websocketInternalError
    case websocketNetworkTimeout
    case websocketNetworkError
    case websocketFailedToReconnect
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .enabled: "enabled"
        case .webhookCallbackVerificationPending: "webhook_callback_verification_pending"
        case .webhookCallbackVerificationFailed: "webhook_callback_verification_failed"
        case .notificationFailuresExceeded: "notification_failures_exceeded"
        case .authorizationRevoked: "authorization_revoked"
        case .moderatorRemoved: "moderator_removed"
        case .userRemoved: "user_removed"
        case .chatUserBanned: "chat_user_banned"
        case .versionRemoved: "version_removed"
        case .betaMaintenance: "beta_maintenance"
        case .websocketDisconnected: "websocket_disconnected"
        case .websocketFailedPingPong: "websocket_failed_ping_pong"
        case .websocketReceivedInboundTraffic: "websocket_received_inbound_traffic"
        case .websocketConnectionUnused: "websocket_connection_unused"
        case .websocketInternalError: "websocket_internal_error"
        case .websocketNetworkTimeout: "websocket_network_timeout"
        case .websocketNetworkError: "websocket_network_error"
        case .websocketFailedToReconnect: "websocket_failed_to_reconnect"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "enabled": .enabled
        case "webhook_callback_verification_pending": .webhookCallbackVerificationPending
        case "webhook_callback_verification_failed": .webhookCallbackVerificationFailed
        case "notification_failures_exceeded": .notificationFailuresExceeded
        case "authorization_revoked": .authorizationRevoked
        case "moderator_removed": .moderatorRemoved
        case "user_removed": .userRemoved
        case "chat_user_banned": .chatUserBanned
        case "version_removed": .versionRemoved
        case "beta_maintenance": .betaMaintenance
        case "websocket_disconnected": .websocketDisconnected
        case "websocket_failed_ping_pong": .websocketFailedPingPong
        case "websocket_received_inbound_traffic": .websocketReceivedInboundTraffic
        case "websocket_connection_unused": .websocketConnectionUnused
        case "websocket_internal_error": .websocketInternalError
        case "websocket_network_timeout": .websocketNetworkTimeout
        case "websocket_network_error": .websocketNetworkError
        case "websocket_failed_to_reconnect": .websocketFailedToReconnect
        default: .unknown(rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Delivery transport used when creating an EventSub subscription.
///
/// Twitch supports webhook, WebSocket, and conduit transports for subscription creation.
public struct EventSubSubscriptionTransport: Encodable, Sendable, Equatable {
    let method: EventSubTransportMethod
    let callback: URL?
    let secret: String?
    let sessionId: String?
    let conduitId: String?

    private init(
        method: EventSubTransportMethod,
        callback: URL? = nil,
        secret: String? = nil,
        sessionId: String? = nil,
        conduitId: String? = nil
    ) {
        self.method = method
        self.callback = callback
        self.secret = secret
        self.sessionId = sessionId
        self.conduitId = conduitId
    }

    /// Delivers events to an HTTPS callback URL.
    public static func webhook(callback: URL, secret: String) -> Self {
        Self(method: .webhook, callback: callback, secret: secret)
    }

    /// Delivers events to an EventSub WebSocket session.
    public static func websocket(sessionID: String) -> Self {
        Self(method: .websocket, sessionId: sessionID)
    }

    /// Delivers events through an EventSub conduit.
    public static func conduit(conduitID: String) -> Self {
        Self(method: .conduit, conduitId: conduitID)
    }

    func validate() throws {
        switch method {
        case .webhook:
            guard callback != nil else {
                throw HelixError.badRequest(TwitchAPIError.fallback(status: 400, message: "Webhook callback URL is required"))
            }
        case .websocket:
            guard sessionId?.isEmpty == false else {
                throw HelixError.badRequest(TwitchAPIError.fallback(status: 400, message: "EventSub WebSocket session ID is required"))
            }
        case .conduit:
            guard conduitId?.isEmpty == false else {
                throw HelixError.badRequest(TwitchAPIError.fallback(status: 400, message: "EventSub conduit ID is required"))
            }
        case .unknown:
            break
        }
    }

    enum CodingKeys: String, CodingKey {
        case method
        case callback
        case secret
        case sessionId = "session_id"
        case conduitId = "conduit_id"
    }
}
