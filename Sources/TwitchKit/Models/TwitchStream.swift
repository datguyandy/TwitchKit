import Foundation

/// A live Twitch stream returned by Helix.
///
/// - SeeAlso: [Get Streams](https://dev.twitch.tv/docs/api/reference/#get-streams)
public struct TwitchStream: Decodable, Sendable, Equatable {
    /// The stream ID.
    public let id: String

    /// The ID of the broadcaster.
    public let userID: String

    /// The broadcaster's login name.
    public let userLogin: String

    /// The broadcaster's display name.
    public let userName: String

    /// The ID of the game/category being streamed.
    public let gameID: String

    /// The name of the game/category being streamed.
    public let gameName: String

    /// The stream type. Typically `.live` for active streams.
    public let type: TwitchStreamType

    /// The stream title.
    public let title: String

    /// Tags applied to the stream.
    public let tags: [String]

    /// Current viewer count.
    public let viewerCount: Int

    /// When the stream started.
    public let startedAt: Date

    /// The stream language.
    public let language: String

    /// Template URL for the stream thumbnail.
    public let thumbnailURL: String

    /// Whether the stream is marked mature.
    public let isMature: Bool

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        userID: String,
        userLogin: String,
        userName: String,
        gameID: String,
        gameName: String,
        type: TwitchStreamType,
        title: String,
        tags: [String],
        viewerCount: Int,
        startedAt: Date,
        language: String,
        thumbnailURL: String,
        isMature: Bool
    ) {
        self.id = id
        self.userID = userID
        self.userLogin = userLogin
        self.userName = userName
        self.gameID = gameID
        self.gameName = gameName
        self.type = type
        self.title = title
        self.tags = tags
        self.viewerCount = viewerCount
        self.startedAt = startedAt
        self.language = language
        self.thumbnailURL = thumbnailURL
        self.isMature = isMature
    }

    private enum CodingKeys: String, CodingKey {
        case id, userID, userLogin, userName, gameID, gameName, type, title
        case tags, viewerCount, startedAt, language, thumbnailURL, isMature
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        userLogin = try container.decode(String.self, forKey: .userLogin)
        userName = try container.decode(String.self, forKey: .userName)
        gameID = try container.decode(String.self, forKey: .gameID)
        gameName = try container.decode(String.self, forKey: .gameName)
        type = try container.decode(TwitchStreamType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        // Twitch sends `"tags": null` for streams with no tags set — tolerate
        // both null and an absent key, defaulting to an empty array.
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        viewerCount = try container.decode(Int.self, forKey: .viewerCount)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        language = try container.decode(String.self, forKey: .language)
        thumbnailURL = try container.decode(String.self, forKey: .thumbnailURL)
        isMature = try container.decode(Bool.self, forKey: .isMature)
    }
}
