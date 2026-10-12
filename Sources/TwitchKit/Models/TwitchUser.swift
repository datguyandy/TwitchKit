import Foundation

/// Authenticated Twitch user profile.
///
/// Returned by `GET /helix/users` (no query params = authenticated user).
/// Requires `user:read:email` scope for the `email` field.
///
/// - SeeAlso: [Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)
public struct TwitchUser: Codable, Sendable, Equatable, Identifiable {
    /// Unique user ID (numeric string, e.g., "141981764").
    public let id: String

    /// Lowercase login name used in URLs (e.g., "twitchdev").
    public let login: String

    /// Display name with original casing (e.g., "TwitchDev").
    public let displayName: String

    /// URL to the user's profile image (300x300).
    public let profileImageUrl: String

    /// User's email address. Only populated if the `user:read:email` scope was granted.
    public let email: String?

    /// Broadcaster classification: `"partner"`, `"affiliate"`, or `""` (regular user).
    public let broadcasterType: String

    /// User's channel description/bio.
    public let description: String?

    /// URL to the user's offline banner image.
    public let offlineImageUrl: String?

    /// Account creation date.
    public let createdAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        login: String,
        displayName: String,
        profileImageUrl: String,
        email: String? = nil,
        broadcasterType: String,
        description: String? = nil,
        offlineImageUrl: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.login = login
        self.displayName = displayName
        self.profileImageUrl = profileImageUrl
        self.email = email
        self.broadcasterType = broadcasterType
        self.description = description
        self.offlineImageUrl = offlineImageUrl
        self.createdAt = createdAt
    }
}
