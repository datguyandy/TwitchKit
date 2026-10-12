import Foundation

/// Channel information for a broadcaster.
///
/// Returned by `GET /helix/channels?broadcaster_id=`.
/// Updated via `PATCH /helix/channels?broadcaster_id=` (requires `channel:manage:broadcast`).
///
/// - SeeAlso: [Get Channel Information](https://dev.twitch.tv/docs/api/reference/#get-channel-information)
/// - SeeAlso: [Modify Channel Information](https://dev.twitch.tv/docs/api/reference/#modify-channel-information)
public struct TwitchChannel: Codable, Sendable, Equatable {
    /// Broadcaster's user ID.
    public let broadcasterId: String

    /// Broadcaster's login name.
    public let broadcasterLogin: String?

    /// Broadcaster's display name.
    public let broadcasterName: String

    /// Current stream title (editable via `updateChannelInfo`).
    public let title: String

    /// Name of the game/category being streamed.
    public let gameName: String

    /// ID of the game/category (used when updating channel info).
    public let gameId: String

    /// Channel tags (e.g., ["English", "FPS", "Competitive"]).
    public let tags: [String]

    /// Primary broadcast language (ISO 639-1 code, e.g., "en").
    public let broadcasterLanguage: String

    /// Stream delay in seconds (partners only, requires user access token).
    public let delay: Int?

    /// Content classification labels applied to the channel.
    public let contentClassificationLabels: [String]?

    /// Whether the channel is marked as branded content.
    public let isBrandedContent: Bool?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        broadcasterLogin: String? = nil,
        broadcasterName: String,
        title: String,
        gameName: String,
        gameId: String,
        tags: [String],
        broadcasterLanguage: String,
        delay: Int? = nil,
        contentClassificationLabels: [String]? = nil,
        isBrandedContent: Bool? = nil
    ) {
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.title = title
        self.gameName = gameName
        self.gameId = gameId
        self.tags = tags
        self.broadcasterLanguage = broadcasterLanguage
        self.delay = delay
        self.contentClassificationLabels = contentClassificationLabels
        self.isBrandedContent = isBrandedContent
    }
}
