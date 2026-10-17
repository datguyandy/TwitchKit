import Foundation

/// A set of chat badge versions (e.g., "subscriber" with versions "0", "3", "6", "12" for months).
///
/// Badges appear next to a user's name in chat to indicate status (moderator, subscriber, etc.).
/// The Helix API returns badges grouped by set, each set containing multiple versions
/// with different images.
///
/// Helix response shape:
/// ```json
/// {
///   "data": [{
///     "set_id": "subscriber",
///     "versions": [{
///       "id": "0",
///       "image_url_1x": "https://...",
///       "image_url_2x": "https://...",
///       "image_url_4x": "https://...",
///       "title": "Subscriber",
///       "description": "Subscriber",
///       "click_action": "subscribe_to_channel",
///       "click_url": null
///     }]
///   }]
/// }
/// ```
///
/// - SeeAlso: [Get Global Chat Badges](https://dev.twitch.tv/docs/api/reference/#get-global-chat-badges)
/// - SeeAlso: [Get Channel Chat Badges](https://dev.twitch.tv/docs/api/reference/#get-channel-chat-badges)
public struct TwitchBadgeSet: Codable, Sendable, Equatable, Identifiable {
    /// Badge set identifier (e.g., "subscriber", "moderator", "vip", "bits").
    /// Matches `set_id` in chat message badge references.
    public let setID: String

    public var id: String { setID }

    /// All versions of this badge. For subscriber badges, each version
    /// corresponds to a tenure milestone (0, 3, 6, 12 months, etc.).
    public let versions: [TwitchBadge]

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        setID: String,
        versions: [TwitchBadge]
    ) {
        self.setID = setID
        self.versions = versions
    }
}

/// A single badge version with image URLs at multiple resolutions.
///
/// In chat messages, badges reference a `set_id` + `id` pair.
/// Look up the badge set by `set_id`, then find the version by `id`
/// to get the correct image URL.
public struct TwitchBadge: Codable, Sendable, Equatable, Identifiable {
    /// Version identifier within the set (e.g., "1" for moderator, "12" for 12-month subscriber).
    public let id: String

    /// Small badge image (18x18 pixels).
    public let imageURL1x: String

    /// Medium badge image (36x36 pixels).
    public let imageURL2x: String

    /// Large badge image (72x72 pixels).
    public let imageURL4x: String

    /// Custom coding keys — the Twitch key strategy turns `image_url_1x` into `imageURL1X`
    /// (capital X), but our properties use lowercase `imageURL1x`. Since the decoder applies
    /// key conversion BEFORE matching CodingKeys, the raw values here must be what
    /// the decoder produces AFTER conversion, not the original JSON keys.
    enum CodingKeys: String, CodingKey {
        case id
        case imageURL1x = "imageURL1X"
        case imageURL2x = "imageURL2X"
        case imageURL4x = "imageURL4X"
        case title, description, clickAction, clickURL
    }

    /// Human-readable title (e.g., "Moderator", "6-Month Subscriber").
    public let title: String?

    /// Human-readable description of the badge.
    public let description: String?

    /// What happens when a viewer clicks this badge in chat.
    public let clickAction: BadgeClickAction?

    /// URL opened when the badge is clicked (if `clickAction` is `"visit_url"`).
    public let clickURL: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        imageURL1x: String,
        imageURL2x: String,
        imageURL4x: String,
        title: String? = nil,
        description: String? = nil,
        clickAction: BadgeClickAction? = nil,
        clickURL: String? = nil
    ) {
        self.id = id
        self.imageURL1x = imageURL1x
        self.imageURL2x = imageURL2x
        self.imageURL4x = imageURL4x
        self.title = title
        self.description = description
        self.clickAction = clickAction
        self.clickURL = clickURL
    }
}
