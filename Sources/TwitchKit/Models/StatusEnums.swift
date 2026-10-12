import Foundation

// Status fields Twitch documents as fixed vocabularies. Each enum keeps an
// `.unknown` case so a value Twitch adds later decodes instead of failing the
// response, matches case-insensitively (Helix and EventSub often differ in
// casing for the same value), and accepts a string literal, so comparisons
// written against the old `String` fields (`poll.status == "ACTIVE"`) still
// compile.

/// A poll's status. Helix sends uppercase values and EventSub lowercase ones; both decode to the same case.
public enum TwitchPollStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// The poll is running.
    case active
    /// The poll ended on schedule.
    case completed
    /// The poll was ended before its scheduled end.
    case terminated
    /// The poll was archived and is no longer visible on the channel.
    case archived
    /// The poll was deleted.
    case moderated
    /// Twitch couldn't determine the poll's state.
    case invalid
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .active: "ACTIVE"
        case .completed: "COMPLETED"
        case .terminated: "TERMINATED"
        case .archived: "ARCHIVED"
        case .moderated: "MODERATED"
        case .invalid: "INVALID"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "active": .active
        case "completed": .completed
        case "terminated": .terminated
        case "archived": .archived
        case "moderated": .moderated
        case "invalid": .invalid
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A prediction's status. Helix sends uppercase values and EventSub lowercase ones; both decode to the same case.
public enum TwitchPredictionStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// Viewers can make predictions.
    case active
    /// The broadcaster canceled the prediction and refunded Channel Points.
    case canceled
    /// Viewers can no longer make predictions.
    case locked
    /// The winning outcome was chosen and Channel Points were paid out.
    case resolved
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .active: "ACTIVE"
        case .canceled: "CANCELED"
        case .locked: "LOCKED"
        case .resolved: "RESOLVED"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "active": .active
        case "canceled": .canceled
        case "locked": .locked
        case "resolved": .resolved
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The status of an unban request. Also used to filter Get Unban Requests.
public enum UnbanRequestStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case pending
    case approved
    case denied
    case acknowledged
    case canceled
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .pending: "pending"
        case .approved: "approved"
        case .denied: "denied"
        case .acknowledged: "acknowledged"
        case .canceled: "canceled"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "pending": .pending
        case "approved": .approved
        case "denied": .denied
        case "acknowledged": .acknowledged
        case "canceled": .canceled
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A Drops entitlement's fulfillment status.
public enum DropsEntitlementFulfillmentStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case claimed
    case fulfilled
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .claimed: "CLAIMED"
        case .fulfilled: "FULFILLED"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "claimed": .claimed
        case "fulfilled": .fulfilled
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The result of updating a batch of Drops entitlements.
public enum DropsEntitlementUpdateStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// The entitlements were updated.
    case success
    /// The entitlement IDs aren't valid.
    case invalidID
    /// The entitlement IDs weren't found.
    case notFound
    /// The token's user or organization can't update these entitlements.
    case unauthorized
    /// The update failed; Twitch considers this transient, so retry later.
    case updateFailed
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .success: "SUCCESS"
        case .invalidID: "INVALID_ID"
        case .notFound: "NOT_FOUND"
        case .unauthorized: "UNAUTHORIZED"
        case .updateFailed: "UPDATE_FAILED"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "success": .success
        case "invalid_id": .invalidID
        case "not_found": .notFound
        case "unauthorized": .unauthorized
        case "update_failed": .updateFailed
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A chat user's suspicious-user (low trust) status. Helix sends `NO_TREATMENT` and EventSub `none` for an untreated user; both decode to `.noTreatment`.
public enum SuspiciousUserStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// The user's messages are monitored.
    case activeMonitoring
    /// The user's messages are hidden from chat.
    case restricted
    /// No suspicious-user treatment applies. Twitch rejects this value when adding a status.
    case noTreatment
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .activeMonitoring: "ACTIVE_MONITORING"
        case .restricted: "RESTRICTED"
        case .noTreatment: "NO_TREATMENT"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "active_monitoring": .activeMonitoring
        case "restricted": .restricted
        case "no_treatment", "none": .noTreatment
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A conduit shard's status. The subscriber receives events only for enabled shards.
public enum ConduitShardStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case enabled
    case webhookCallbackVerificationPending
    case webhookCallbackVerificationFailed
    case notificationFailuresExceeded
    case websocketDisconnected
    case websocketFailedPingPong
    case websocketReceivedInboundTraffic
    case websocketConnectionUnused
    case websocketInternalError
    case websocketNetworkTimeout
    case websocketNetworkError
    case websocketFailedToReconnect
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .enabled: "enabled"
        case .webhookCallbackVerificationPending: "webhook_callback_verification_pending"
        case .webhookCallbackVerificationFailed: "webhook_callback_verification_failed"
        case .notificationFailuresExceeded: "notification_failures_exceeded"
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
        self = switch rawValue.lowercased() {
        case "enabled": .enabled
        case "webhook_callback_verification_pending": .webhookCallbackVerificationPending
        case "webhook_callback_verification_failed": .webhookCallbackVerificationFailed
        case "notification_failures_exceeded": .notificationFailuresExceeded
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

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A Guest Star guest's state. Helix invites use uppercase values and EventSub lowercase ones; both decode to the same case.
public enum GuestStarGuestState: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// Invited, but hasn't acknowledged the invite.
    case invited
    /// Joined the waiting room and may still be setting up.
    case accepted
    /// Ready to join the call from the waiting room.
    case ready
    /// In the call but not visible to viewers.
    case backstage
    /// Visible to viewers.
    case live
    /// Removed from the call or the waiting room.
    case removed
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .invited: "INVITED"
        case .accepted: "ACCEPTED"
        case .ready: "READY"
        case .backstage: "BACKSTAGE"
        case .live: "LIVE"
        case .removed: "REMOVED"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "invited": .invited
        case "accepted": .accepted
        case "ready": .ready
        case "backstage": .backstage
        case "live": .live
        case "removed": .removed
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// An extension's review and release state.
public enum ExtensionState: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case approved
    case assetsUploaded
    case deleted
    case deprecated
    case inReview
    case inTest
    case pendingAction
    case rejected
    case released
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .approved: "Approved"
        case .assetsUploaded: "AssetsUploaded"
        case .deleted: "Deleted"
        case .deprecated: "Deprecated"
        case .inReview: "InReview"
        case .inTest: "InTest"
        case .pendingAction: "PendingAction"
        case .rejected: "Rejected"
        case .released: "Released"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "approved": .approved
        case "assetsuploaded": .assetsUploaded
        case "deleted": .deleted
        case "deprecated": .deprecated
        case "inreview": .inReview
        case "intest": .inTest
        case "pendingaction": .pendingAction
        case "rejected": .rejected
        case "released": .released
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The outcome of a message AutoMod held for review.
public enum AutoModMessageStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case approved
    case denied
    case expired
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .approved: "Approved"
        case .denied: "Denied"
        case .expired: "Expired"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "approved": .approved
        case "denied": .denied
        case "expired": .expired
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The outcome of a chat user's message that was held for review.
public enum ChatUserMessageStatus: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case approved
    case denied
    case invalid
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .approved: "approved"
        case .denied: "denied"
        case .invalid: "invalid"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.lowercased() {
        case "approved": .approved
        case "denied": .denied
        case "invalid": .invalid
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
