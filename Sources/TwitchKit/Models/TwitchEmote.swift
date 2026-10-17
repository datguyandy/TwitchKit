import Foundation

/// A Twitch emote — global, channel, or emote set.
///
/// Used by both the global emotes endpoint (`GET /chat/emotes/global`) and
/// channel emotes endpoint (`GET /chat/emotes?broadcaster_id=`).
/// Channel emotes include extra fields (`tier`, `emoteType`, `emoteSetID`)
/// that are absent from global emotes.
///
/// Use the `template` URL with `id`, `format`, `scale`, and `themeMode`
/// to construct CDN URLs for rendering.
///
/// CDN URL format: `https://static-cdn.jtvnw.net/emoticons/v2/{id}/{format}/{theme_mode}/{scale}`
///
/// - SeeAlso: [Get Global Emotes](https://dev.twitch.tv/docs/api/reference/#get-global-emotes)
/// - SeeAlso: [Get Channel Emotes](https://dev.twitch.tv/docs/api/reference/#get-channel-emotes)
/// - SeeAlso: [Emote CDN URL format](https://dev.twitch.tv/docs/irc/emotes/#cdn-template)
public struct TwitchEmote: Codable, Sendable, Equatable, Identifiable {
    /// Unique emote ID used in CDN URLs and chat fragment references.
    public let id: String

    /// The name viewers type in chat to display this emote (e.g., "Kappa", "LUL").
    public let name: String

    /// Static image URLs at fixed sizes. Prefer `template` for dynamic URL construction.
    /// These always return a static PNG with a light background.
    public let images: EmoteImages?

    /// Available formats: `"static"` (PNG) and/or `"animated"` (GIF).
    /// If both are present, the emote has an animated variant.
    public let format: [String]

    /// Available sizes: `"1.0"` (28px), `"2.0"` (56px), `"3.0"` (112px).
    public let scale: [String]

    /// Background themes: `"dark"` and/or `"light"`.
    public let themeMode: [String]

    /// CDN URL template. Replace `{{id}}`, `{{format}}`, `{{theme_mode}}`, `{{scale}}`
    /// with actual values to construct the emote image URL.
    ///
    /// Example: `https://static-cdn.jtvnw.net/emoticons/v2/{{id}}/{{format}}/{{theme_mode}}/{{scale}}`
    public let template: String?

    // MARK: - Channel emote fields (nil for global emotes)

    /// Subscriber tier required to unlock this emote: `"1000"` (Tier 1), `"2000"`, `"3000"`.
    /// Only present when `emoteType` is `"subscriptions"`. Empty string otherwise.
    public let tier: String?

    /// Type of channel emote:
    /// - `"bitstier"` — unlocked by cheering Bits
    /// - `"follower"` — available to followers (can only be used in the channel's chat)
    /// - `"subscriptions"` — unlocked by subscribing
    ///
    /// Nil for global emotes.
    public let emoteType: String?

    /// ID of the emote set this emote belongs to. Nil for global emotes.
    public let emoteSetID: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        name: String,
        images: EmoteImages? = nil,
        format: [String],
        scale: [String],
        themeMode: [String],
        template: String? = nil,
        tier: String? = nil,
        emoteType: String? = nil,
        emoteSetID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.images = images
        self.format = format
        self.scale = scale
        self.themeMode = themeMode
        self.template = template
        self.tier = tier
        self.emoteType = emoteType
        self.emoteSetID = emoteSetID
    }

    /// Constructs a CDN URL for this emote with the given display preferences.
    ///
    /// Uses the `template` field if available, otherwise falls back to the standard CDN pattern.
    ///
    /// - Parameters:
    ///   - format: `"static"` or `"animated"`. Falls back to `"static"` if animated not available.
    ///   - theme: `"dark"` or `"light"`.
    ///   - scale: `"1.0"`, `"2.0"`, or `"3.0"`.
    /// - Returns: A fully resolved CDN URL.
    public func imageURL(format: String = "static", theme: String = "dark", scale: String = "3.0") -> URL? {
        let base = template ?? "https://static-cdn.jtvnw.net/emoticons/v2/{{id}}/{{format}}/{{theme_mode}}/{{scale}}"
        let urlString = base
            .replacing("{{id}}", with: id)
            .replacing("{{format}}", with: format)
            .replacing("{{theme_mode}}", with: theme)
            .replacing("{{scale}}", with: scale)
        return URL(string: urlString)
    }
}

/// Static emote image URLs at fixed sizes.
/// These are provided for convenience but the `template` field is preferred
/// for constructing URLs with specific format/theme/scale combinations.
public struct EmoteImages: Codable, Sendable, Equatable {
    /// Small emote (28x28 pixels).
    public let url1x: String

    /// Medium emote (56x56 pixels).
    public let url2x: String

    /// Large emote (112x112 pixels).
    public let url4x: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        url1x: String,
        url2x: String,
        url4x: String
    ) {
        self.url1x = url1x
        self.url2x = url2x
        self.url4x = url4x
    }

    /// Custom coding keys — `.convertFromSnakeCase` turns `url_1x` into `url1X` (capital X),
    /// but our properties use lowercase `url1x`.
    enum CodingKeys: String, CodingKey {
        case url1x = "url1X"
        case url2x = "url2X"
        case url4x = "url4X"
    }
}
