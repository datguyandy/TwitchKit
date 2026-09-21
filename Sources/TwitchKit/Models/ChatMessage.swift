import Foundation

/// A chat message received via EventSub `channel.chat.message` v1.
///
/// Contains the full message payload including text, fragments (emotes, mentions, cheermotes),
/// badges, cheer info, reply thread context, and shared chat source information.
///
/// Condition: `{ "broadcaster_user_id": "<id>", "user_id": "<id>" }`
///
/// - SeeAlso: [channel.chat.message EventSub](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelchatmessage)
public struct ChatMessage: Codable, Sendable, Equatable, Identifiable {
    /// Unique message ID. Maps to `message_id` in the EventSub event payload.
    public let messageId: String
    public var id: String { messageId }

    // Broadcaster
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    // Chatter
    public let chatterUserId: String
    public let chatterUserLogin: String
    public let chatterUserName: String

    // Message content
    public let message: ChatMessageBody
    public let color: String
    public let badges: [ChatBadge]
    public let messageType: ChatMessageType

    // Cheer (bits)
    public let cheer: Cheer?

    // Reply thread
    public let reply: Reply?

    // Channel points reward
    public let channelPointsCustomRewardId: String?

    // Shared chat — when a message originates from another channel
    public let sourceBroadcasterUserId: String?
    public let sourceBroadcasterUserLogin: String?
    public let sourceBroadcasterUserName: String?
    public let sourceMessageId: String?
    public let sourceBadges: [ChatBadge]?

    public let isSourceOnly: Bool?

    // MARK: - Nested Types

    public struct ChatMessageBody: Codable, Sendable, Equatable {
        public let text: String
        public let fragments: [ChatFragment]
    }

    public struct Cheer: Codable, Sendable, Equatable {
        public let bits: Int
    }

    public struct Reply: Codable, Sendable, Equatable {
        public let parentMessageId: String
        public let parentMessageBody: String
        public let parentUserId: String
        public let parentUserLogin: String
        public let parentUserName: String
        public let threadMessageId: String
        public let threadUserId: String
        public let threadUserLogin: String
        public let threadUserName: String
    }
}

public struct ChatFragment: Codable, Sendable, Equatable {
    public let type: ChatFragmentType
    public let text: String
    public let cheermote: CheermoteReference?
    public let emote: EmoteReference?
    public let mention: MentionReference?
    public let gif: GIFReference?
}

public struct EmoteReference: Codable, Sendable, Equatable {
    public let id: String
    public let emoteSetId: String
    public let ownerId: String?
    public let format: [String]?
}

public struct CheermoteReference: Codable, Sendable, Equatable {
    public let prefix: String
    public let bits: Int
    public let tier: Int
}

public struct MentionReference: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
}

public struct ChatBadge: Codable, Sendable, Equatable {
    public let setId: String
    public let id: String
    public let info: String
}

/// GIF metadata in a chat message fragment.
public struct GIFReference: Codable, Sendable, Equatable {
    public let gifId: String
    public let url: String
}
