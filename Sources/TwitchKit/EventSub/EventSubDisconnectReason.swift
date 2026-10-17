import Foundation

/// A WebSocket close code from Twitch's EventSub server.
///
/// Twitch closes the connection with one of these codes to say why. Codes
/// Twitch adds later arrive as ``other(_:)``, and standard WebSocket codes
/// (1000–1015) do too.
public enum EventSubCloseCode: Sendable, Hashable, CustomStringConvertible {
    /// 4000: a problem on Twitch's side, like an HTTP 500.
    case internalServerError
    /// 4001: the client sent the server a message other than a pong.
    case clientSentInboundTraffic
    /// 4002: the client didn't answer a ping with a pong.
    case clientFailedPingPong
    /// 4003: no subscription was created within 10 seconds of connecting.
    case connectionUnused
    /// 4004: the client didn't move to the new URL within 30 seconds of a
    /// `session_reconnect` message.
    case reconnectGraceTimeExpired
    /// 4005: a transient network timeout.
    case networkTimeout
    /// 4006: a transient network error.
    case networkError
    /// 4007: the reconnect URL was invalid.
    case invalidReconnect
    /// Any other close code.
    case other(Int)

    public init(rawValue: Int) {
        switch rawValue {
        case 4000: self = .internalServerError
        case 4001: self = .clientSentInboundTraffic
        case 4002: self = .clientFailedPingPong
        case 4003: self = .connectionUnused
        case 4004: self = .reconnectGraceTimeExpired
        case 4005: self = .networkTimeout
        case 4006: self = .networkError
        case 4007: self = .invalidReconnect
        default: self = .other(rawValue)
        }
    }

    /// The numeric close code.
    public var rawValue: Int {
        switch self {
        case .internalServerError: 4000
        case .clientSentInboundTraffic: 4001
        case .clientFailedPingPong: 4002
        case .connectionUnused: 4003
        case .reconnectGraceTimeExpired: 4004
        case .networkTimeout: 4005
        case .networkError: 4006
        case .invalidReconnect: 4007
        case .other(let code): code
        }
    }

    public var description: String {
        switch self {
        case .internalServerError: "4000 internal server error"
        case .clientSentInboundTraffic: "4001 client sent inbound traffic"
        case .clientFailedPingPong: "4002 client failed ping-pong"
        case .connectionUnused: "4003 connection unused"
        case .reconnectGraceTimeExpired: "4004 reconnect grace time expired"
        case .networkTimeout: "4005 network timeout"
        case .networkError: "4006 network error"
        case .invalidReconnect: "4007 invalid reconnect"
        case .other(let code): "\(code)"
        }
    }
}

/// Why an ``EventSubClient``'s connection ended. Read it from
/// ``EventSubClient/lastDisconnectReason`` when ``EventSubClient/connectionState``
/// moves to `.reconnecting`, `.waitingForNetwork` or `.disconnected`.
public enum EventSubDisconnectReason: Sendable, Equatable, CustomStringConvertible {
    /// The server closed the WebSocket with this code, and the reason text it
    /// sent, if any.
    case closedByServer(EventSubCloseCode, reason: String?)
    /// The connection failed without a close code, for example the network
    /// dropped. Carries the error's description.
    case connectionLost(String)
    /// Nothing arrived, not even a keepalive, within the session's keepalive
    /// timeout.
    case keepaliveTimeout
    /// A `session_reconnect` handoff to the new URL didn't complete.
    case reconnectFailed
    /// A `session_reconnect` message named a host that isn't Twitch's, so the
    /// client reconnected normally instead.
    case untrustedReconnectURL
    /// The app called ``EventSubClient/disconnect(forgettingSubscriptions:)``.
    case requested

    public var description: String {
        switch self {
        case .closedByServer(let code, let reason):
            if let reason, !reason.isEmpty {
                "closed by server (\(code)): \(reason)"
            } else {
                "closed by server (\(code))"
            }
        case .connectionLost(let error): "connection lost: \(error)"
        case .keepaliveTimeout: "keepalive timeout"
        case .reconnectFailed: "session_reconnect handoff failed"
        case .untrustedReconnectURL: "session_reconnect to an untrusted URL"
        case .requested: "disconnect requested"
        }
    }
}
