import Foundation

/// A new follower event from EventSub `channel.follow` v2.
///
/// Requires `moderator:read:followers` scope.
/// Condition: `{ "broadcaster_user_id": "<id>", "moderator_user_id": "<id>" }`
/// (both are your own ID when monitoring your own channel).
///
/// - SeeAlso: [channel.follow EventSub](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelfollow)
public struct TwitchFollow: Codable, Sendable, Equatable {
    /// ID of the user who followed.
    public let userID: String

    /// Login name of the user who followed.
    public let userLogin: String?

    /// Display name of the user who followed.
    public let userName: String

    /// ID of the broadcaster who was followed.
    public let broadcasterUserID: String?

    /// Login name of the broadcaster who was followed.
    public let broadcasterUserLogin: String?

    /// Display name of the broadcaster who was followed.
    public let broadcasterUserName: String?

    /// When the follow occurred.
    public let followedAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userID: String,
        userLogin: String? = nil,
        userName: String,
        followedAt: Date,
        broadcasterUserID: String? = nil,
        broadcasterUserLogin: String? = nil,
        broadcasterUserName: String? = nil
    ) {
        self.userID = userID
        self.userLogin = userLogin
        self.userName = userName
        self.followedAt = followedAt
        self.broadcasterUserID = broadcasterUserID
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
    }
}
