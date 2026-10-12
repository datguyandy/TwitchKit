import Foundation

extension HelixClient {
    /// Gets the list of global emotes (Twitch-created, usable in any chat).
    ///
    /// Global emotes include built-in emotes like Kappa, PogChamp, etc.
    /// Use `imageURL()` on each emote to construct CDN URLs for rendering.
    ///
    /// - Returns: Array of global emotes with format, scale, and template info.
    /// - SeeAlso: [Get Global Emotes](https://dev.twitch.tv/docs/api/reference/#get-global-emotes)
    public func fetchGlobalEmotes() async throws -> [TwitchEmote] {
        let response: HelixResponse<TwitchEmote> = try await request(endpoint: "chat/emotes/global")
        return response.data
    }

    /// Gets the broadcaster's custom emotes (subscriber, Bits tier, follower emotes).
    ///
    /// Channel emotes include `tier` (subscription tier), `emoteType` (subscriptions/bitstier/follower),
    /// and `emoteSetId`. Follower emotes can only be used in the channel's own chat.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Array of channel-specific emotes. Empty if none exist.
    /// - SeeAlso: [Get Channel Emotes](https://dev.twitch.tv/docs/api/reference/#get-channel-emotes)
    public func fetchChannelEmotes(broadcasterID broadcasterId: String) async throws -> [TwitchEmote] {
        let response: HelixResponse<TwitchEmote> = try await request(
            endpoint: "chat/emotes",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data
    }

    /// Gets Twitch's global chat badges (e.g., staff, turbo, premium).
    ///
    /// Each badge set contains multiple versions with images at 1x/2x/4x resolutions.
    /// To render a badge from a chat message, match `ChatBadge.setId` + `ChatBadge.id`
    /// against the badge sets and versions returned here.
    ///
    /// - Returns: Array of global badge sets with version images.
    /// - SeeAlso: [Get Global Chat Badges](https://dev.twitch.tv/docs/api/reference/#get-global-chat-badges)
    public func fetchGlobalBadges() async throws -> [TwitchBadgeSet] {
        let response: HelixResponse<TwitchBadgeSet> = try await request(endpoint: "chat/badges/global")
        return response.data
    }

    /// Gets the broadcaster's custom chat badges (e.g., subscriber tenure badges).
    ///
    /// Channel badges override global badges with the same `setId`.
    /// When rendering, check channel badges first, fall back to global.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Array of channel-specific badge sets.
    /// - SeeAlso: [Get Channel Chat Badges](https://dev.twitch.tv/docs/api/reference/#get-channel-chat-badges)
    public func fetchChannelBadges(broadcasterID broadcasterId: String) async throws -> [TwitchBadgeSet] {
        let response: HelixResponse<TwitchBadgeSet> = try await request(
            endpoint: "chat/badges",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data
    }

    /// Sends a chat message to a channel.
    ///
    /// The `senderId` must match the authenticated user's ID. Optionally reply
    /// to an existing message by providing `replyParentMessageId`.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel to send the message to.
    ///   - senderId: The authenticated user's ID (must match access token).
    ///   - message: The chat message text.
    ///   - replyParentMessageId: Optional message ID to reply to (creates a thread).
    ///   - forSourceOnly: For app access tokens in Shared Chat, whether to send only to the source channel.
    ///   - pin: Send and pin for 20 minutes; cannot be combined with reply or source-only parameters.
    /// - Returns: The result including `messageId`, `isSent`, and optional `dropReason`.
    /// - Throws: `HelixError.forbidden` if the user is banned or lacks permissions.
    /// - SeeAlso: [Send Chat Message](https://dev.twitch.tv/docs/api/reference/#send-chat-message)
    public func sendChatMessage(
        broadcasterID broadcasterId: String,
        senderID senderId: String,
        message: String,
        replyParentMessageID replyParentMessageId: String? = nil,
        forSourceOnly: Bool? = nil,
        pin: Bool? = nil
    ) async throws -> SendChatMessageResponse {
        if pin == true, replyParentMessageId != nil || forSourceOnly != nil {
            throw HelixError.badRequest(.fallback(status: 400, message: "Pinned messages cannot include replyParentMessageId or forSourceOnly"))
        }
        let body = SendChatMessageRequest(
            broadcasterId: broadcasterId,
            senderId: senderId,
            message: message,
            replyParentMessageId: replyParentMessageId,
            forSourceOnly: forSourceOnly,
            pin: pin
        )
        let bodyData = try JSONEncoder.twitch().encode(body)
        let response: HelixResponse<SendChatMessageResponse> = try await request(
            endpoint: "chat/messages",
            method: "POST",
            body: bodyData
        )
        guard let result = response.data.first else { throw HelixError.emptyResponse }
        return result
    }
}

private struct SendChatMessageRequest: Encodable {
    let broadcasterId: String
    let senderId: String
    let message: String
    let replyParentMessageId: String?
    let forSourceOnly: Bool?
    let pin: Bool?
}

/// Response from the Send Chat Message endpoint.
///
/// Indicates whether the message was successfully sent or dropped.
public struct SendChatMessageResponse: Decodable, Sendable {
    /// The ID of the sent message (empty string if not sent).
    public let messageId: String

    /// Whether the message was successfully sent to chat.
    public let isSent: Bool

    /// Reason the message was dropped, if `isSent` is `false`.
    public let dropReason: DropReason?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        messageId: String,
        isSent: Bool,
        dropReason: DropReason? = nil
    ) {
        self.messageId = messageId
        self.isSent = isSent
        self.dropReason = dropReason
    }

    /// Details about why a chat message was not sent.
    public struct DropReason: Decodable, Sendable {
        /// Machine-readable error code (e.g., `"automod_held"`, `"msg_banned"`, `"msg_ratelimit"`).
        public let code: String

        /// Human-readable explanation.
        public let message: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            code: String,
            message: String
        ) {
            self.code = code
            self.message = message
        }
    }
}
