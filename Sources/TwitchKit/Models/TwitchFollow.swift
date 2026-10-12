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
    public let userId: String

    /// Login name of the user who followed.
    public let userLogin: String?

    /// Display name of the user who followed.
    public let userName: String

    /// When the follow occurred.
    public let followedAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String? = nil,
        userName: String,
        followedAt: Date
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.followedAt = followedAt
    }
}
