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
    public let messageID: String
    public var id: String { messageID }

    // Broadcaster
    public let broadcasterUserID: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    // Chatter
    public let chatterUserID: String
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
    public let channelPointsCustomRewardID: String?

    // Shared chat — when a message originates from another channel
    public let sourceBroadcasterUserID: String?
    public let sourceBroadcasterUserLogin: String?
    public let sourceBroadcasterUserName: String?
    public let sourceMessageID: String?
    public let sourceBadges: [ChatBadge]?

    public let isSourceOnly: Bool?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        messageID: String,
        broadcasterUserID: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        chatterUserID: String,
        chatterUserLogin: String,
        chatterUserName: String,
        message: ChatMessageBody,
        color: String,
        badges: [ChatBadge],
        messageType: ChatMessageType,
        cheer: Cheer? = nil,
        reply: Reply? = nil,
        channelPointsCustomRewardID: String? = nil,
        sourceBroadcasterUserID: String? = nil,
        sourceBroadcasterUserLogin: String? = nil,
        sourceBroadcasterUserName: String? = nil,
        sourceMessageID: String? = nil,
        sourceBadges: [ChatBadge]? = nil,
        isSourceOnly: Bool? = nil
    ) {
        self.messageID = messageID
        self.broadcasterUserID = broadcasterUserID
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.chatterUserID = chatterUserID
        self.chatterUserLogin = chatterUserLogin
        self.chatterUserName = chatterUserName
        self.message = message
        self.color = color
        self.badges = badges
        self.messageType = messageType
        self.cheer = cheer
        self.reply = reply
        self.channelPointsCustomRewardID = channelPointsCustomRewardID
        self.sourceBroadcasterUserID = sourceBroadcasterUserID
        self.sourceBroadcasterUserLogin = sourceBroadcasterUserLogin
        self.sourceBroadcasterUserName = sourceBroadcasterUserName
        self.sourceMessageID = sourceMessageID
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
        public let parentMessageID: String
        public let parentMessageBody: String
        public let parentUserID: String
        public let parentUserLogin: String
        public let parentUserName: String
        public let threadMessageID: String
        public let threadUserID: String
        public let threadUserLogin: String
        public let threadUserName: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            parentMessageID: String,
            parentMessageBody: String,
            parentUserID: String,
            parentUserLogin: String,
            parentUserName: String,
            threadMessageID: String,
            threadUserID: String,
            threadUserLogin: String,
            threadUserName: String
        ) {
            self.parentMessageID = parentMessageID
            self.parentMessageBody = parentMessageBody
            self.parentUserID = parentUserID
            self.parentUserLogin = parentUserLogin
            self.parentUserName = parentUserName
            self.threadMessageID = threadMessageID
            self.threadUserID = threadUserID
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
    public let emoteSetID: String
    public let ownerID: String?
    public let format: [String]?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        emoteSetID: String,
        ownerID: String? = nil,
        format: [String]? = nil
    ) {
        self.id = id
        self.emoteSetID = emoteSetID
        self.ownerID = ownerID
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
    public let userID: String
    public let userLogin: String
    public let userName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userID: String,
        userLogin: String,
        userName: String
    ) {
        self.userID = userID
        self.userLogin = userLogin
        self.userName = userName
    }
}

public struct ChatBadge: Codable, Sendable, Equatable {
    public let setID: String
    public let id: String
    public let info: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        setID: String,
        id: String,
        info: String
    ) {
        self.setID = setID
        self.id = id
        self.info = info
    }
}

/// GIF metadata in a chat message fragment.
public struct GIFReference: Codable, Sendable, Equatable {
    public let gifID: String
    public let url: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        gifID: String,
        url: String
    ) {
        self.gifID = gifID
        self.url = url
    }
}
