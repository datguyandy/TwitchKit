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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        messageId: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        chatterUserId: String,
        chatterUserLogin: String,
        chatterUserName: String,
        message: ChatMessageBody,
        color: String,
        badges: [ChatBadge],
        messageType: ChatMessageType,
        cheer: Cheer? = nil,
        reply: Reply? = nil,
        channelPointsCustomRewardId: String? = nil,
        sourceBroadcasterUserId: String? = nil,
        sourceBroadcasterUserLogin: String? = nil,
        sourceBroadcasterUserName: String? = nil,
        sourceMessageId: String? = nil,
        sourceBadges: [ChatBadge]? = nil,
        isSourceOnly: Bool? = nil
    ) {
        self.messageId = messageId
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.chatterUserId = chatterUserId
        self.chatterUserLogin = chatterUserLogin
        self.chatterUserName = chatterUserName
        self.message = message
        self.color = color
        self.badges = badges
        self.messageType = messageType
        self.cheer = cheer
        self.reply = reply
        self.channelPointsCustomRewardId = channelPointsCustomRewardId
        self.sourceBroadcasterUserId = sourceBroadcasterUserId
        self.sourceBroadcasterUserLogin = sourceBroadcasterUserLogin
        self.sourceBroadcasterUserName = sourceBroadcasterUserName
        self.sourceMessageId = sourceMessageId
        self.sourceBadges = sourceBadges
        self.isSourceOnly = isSourceOnly
    }

    // MARK: - Nested Types

    public struct ChatMessageBody: Codable, Sendable, Equatable {
        public let text: String
        public let fragments: [ChatFragment]

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            text: String,
            fragments: [ChatFragment]
        ) {
            self.text = text
            self.fragments = fragments
        }
    }

    public struct Cheer: Codable, Sendable, Equatable {
        public let bits: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            bits: Int
        ) {
            self.bits = bits
        }
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

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            parentMessageId: String,
            parentMessageBody: String,
            parentUserId: String,
            parentUserLogin: String,
            parentUserName: String,
            threadMessageId: String,
            threadUserId: String,
            threadUserLogin: String,
            threadUserName: String
        ) {
            self.parentMessageId = parentMessageId
            self.parentMessageBody = parentMessageBody
            self.parentUserId = parentUserId
            self.parentUserLogin = parentUserLogin
            self.parentUserName = parentUserName
            self.threadMessageId = threadMessageId
            self.threadUserId = threadUserId
            self.threadUserLogin = threadUserLogin
            self.threadUserName = threadUserName
        }
    }
}

public struct ChatFragment: Codable, Sendable, Equatable {
    public let type: ChatFragmentType
    public let text: String
    public let cheermote: CheermoteReference?
    public let emote: EmoteReference?
    public let mention: MentionReference?
    public let gif: GIFReference?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        type: ChatFragmentType,
        text: String,
        cheermote: CheermoteReference? = nil,
        emote: EmoteReference? = nil,
        mention: MentionReference? = nil,
        gif: GIFReference? = nil
    ) {
        self.type = type
        self.text = text
        self.cheermote = cheermote
        self.emote = emote
        self.mention = mention
        self.gif = gif
    }
}

public struct EmoteReference: Codable, Sendable, Equatable {
    public let id: String
    public let emoteSetId: String
    public let ownerId: String?
    public let format: [String]?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        emoteSetId: String,
        ownerId: String? = nil,
        format: [String]? = nil
    ) {
        self.id = id
        self.emoteSetId = emoteSetId
        self.ownerId = ownerId
        self.format = format
    }
}

public struct CheermoteReference: Codable, Sendable, Equatable {
    public let prefix: String
    public let bits: Int
    public let tier: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        prefix: String,
        bits: Int,
        tier: Int
    ) {
        self.prefix = prefix
        self.bits = bits
        self.tier = tier
    }
}

public struct MentionReference: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
    }
}

public struct ChatBadge: Codable, Sendable, Equatable {
    public let setId: String
    public let id: String
    public let info: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        setId: String,
        id: String,
        info: String
    ) {
        self.setId = setId
        self.id = id
        self.info = info
    }
}

/// GIF metadata in a chat message fragment.
public struct GIFReference: Codable, Sendable, Equatable {
    public let gifId: String
    public let url: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        gifId: String,
        url: String
    ) {
        self.gifId = gifId
        self.url = url
    }
}
