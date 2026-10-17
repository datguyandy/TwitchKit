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
    public let profileImageURL: String

    /// User's email address. Only populated if the `user:read:email` scope was granted.
    public let email: String?

    /// Broadcaster classification: `"partner"`, `"affiliate"`, or `""` (regular user).
    public let broadcasterType: String

    /// User's channel description/bio.
    public let description: String?

    /// URL to the user's offline banner image.
    public let offlineImageURL: String?

    /// Account creation date.
    public let createdAt: Date?

    /// The user's Twitch role: admin, global moderator, staff, or a normal user.
    /// `nil` when the payload omits the field.
    public let type: TwitchUserType?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        login: String,
        displayName: String,
        profileImageURL: String,
        email: String? = nil,
        broadcasterType: String,
        description: String? = nil,
        offlineImageURL: String? = nil,
        createdAt: Date? = nil,
        type: TwitchUserType? = nil
    ) {
        self.id = id
        self.login = login
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.email = email
        self.broadcasterType = broadcasterType
        self.description = description
        self.offlineImageURL = offlineImageURL
        self.createdAt = createdAt
        self.type = type
    }
}

/// A Twitch user's role, from the `type` field of Get Users.
///
/// A value Twitch adds later is kept verbatim in ``unknown(_:)``, and the enum
/// accepts a string literal (`user.type == "staff"`).
public enum TwitchUserType: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// A Twitch administrator.
    case admin
    /// A global moderator.
    case globalMod
    /// A Twitch staff member.
    case staff
    /// A normal user; Twitch sends an empty string.
    case normal
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .admin: "admin"
        case .globalMod: "global_mod"
        case .staff: "staff"
        case .normal: ""
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "admin": .admin
        case "global_mod": .globalMod
        case "staff": .staff
        case "": .normal
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
