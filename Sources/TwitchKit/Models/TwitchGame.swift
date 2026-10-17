import Foundation

/// A Twitch game or category returned by Helix.
///
/// - SeeAlso: [Get Games](https://dev.twitch.tv/docs/api/reference/#get-games)
public struct TwitchGame: Decodable, Sendable, Equatable {
    /// The game/category ID.
    public let id: String

    /// The game/category name.
    public let name: String

    /// Template URL for box art.
    public let boxArtURL: String

    /// The matching IGDB ID, when Twitch provides one.
    public let igdbID: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        name: String,
        boxArtURL: String,
        igdbID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.boxArtURL = boxArtURL
        self.igdbID = igdbID
    }
}
