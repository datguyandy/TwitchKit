import Foundation

/// A chat message type with forward-compatible support for values Twitch may add later.
public enum ChatMessageType: Codable, RawRepresentable, Sendable, Equatable {
    case text
    case channelPointsHighlighted
    case channelPointsSubOnly
    case userIntro
    case powerUpsMessageEffect
    case powerUpsGigantifiedEmote
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .text: "text"
        case .channelPointsHighlighted: "channel_points_highlighted"
        case .channelPointsSubOnly: "channel_points_sub_only"
        case .userIntro: "user_intro"
        case .powerUpsMessageEffect: "power_ups_message_effect"
        case .powerUpsGigantifiedEmote: "power_ups_gigantified_emote"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "text": .text
        case "channel_points_highlighted": .channelPointsHighlighted
        case "channel_points_sub_only": .channelPointsSubOnly
        case "user_intro": .userIntro
        case "power_ups_message_effect": .powerUpsMessageEffect
        case "power_ups_gigantified_emote": .powerUpsGigantifiedEmote
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

/// A fragment type within an EventSub chat message.
public enum ChatFragmentType: Codable, RawRepresentable, Sendable, Equatable {
    case text
    case cheermote
    case emote
    case mention
    case gif
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .text: "text"
        case .cheermote: "cheermote"
        case .emote: "emote"
        case .mention: "mention"
        case .gif: "gif"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "text": .text
        case "cheermote": .cheermote
        case "emote": .emote
        case "mention": .mention
        case "gif": .gif
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

/// A Twitch subscription tier.
public enum SubscriptionTier: Codable, RawRepresentable, Sendable, Equatable {
    case tier1
    case tier2
    case tier3
    case prime
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .tier1: "1000"
        case .tier2: "2000"
        case .tier3: "3000"
        case .prime: "Prime"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "1000": .tier1
        case "2000": .tier2
        case "3000": .tier3
        case "Prime": .prime
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

/// A Twitch badge click action with forward-compatible support for new values.
public enum BadgeClickAction: Codable, RawRepresentable, Sendable, Equatable {
    case none
    case subscribeToChannel
    case visitURL
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .none: "none"
        case .subscribeToChannel: "subscribe_to_channel"
        case .visitURL: "visit_url"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "none": .none
        case "subscribe_to_channel": .subscribeToChannel
        case "visit_url": .visitURL
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

/// A Twitch stream type with forward-compatible support for new values.
public enum TwitchStreamType: Codable, RawRepresentable, Sendable, Equatable {
    case all
    case live
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .all: "all"
        case .live: "live"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "all": .all
        case "live": .live
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

/// An EventSub transport method with forward-compatible support for new values.
public enum EventSubTransportMethod: Codable, RawRepresentable, Sendable, Equatable {
    case webhook
    case websocket
    case conduit
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .webhook: "webhook"
        case .websocket: "websocket"
        case .conduit: "conduit"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "webhook": .webhook
        case "websocket": .websocket
        case "conduit": .conduit
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

/// A channel points custom reward redemption status.
///
/// Helix requires and returns the uppercase forms (`UNFULFILLED`, `FULFILLED`,
/// `CANCELED`), so `rawValue` emits uppercase. Decoding matches
/// case-insensitively to also tolerate lowercase inputs such as EventSub's
/// redemption payloads.
public enum ChannelPointsRedemptionStatus: Codable, RawRepresentable, Sendable, Equatable {
    case unknown(String)
    case unfulfilled
    case fulfilled
    case canceled

    public var rawValue: String {
        switch self {
        case .unknown(let value): value
        case .unfulfilled: "UNFULFILLED"
        case .fulfilled: "FULFILLED"
        case .canceled: "CANCELED"
        }
    }

    public init(rawValue: String) {
        self = switch rawValue.uppercased() {
        case "UNFULFILLED": .unfulfilled
        case "FULFILLED": .fulfilled
        case "CANCELED": .canceled
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
