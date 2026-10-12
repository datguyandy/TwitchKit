import Foundation

/// A new subscription event from EventSub `channel.subscribe` v1.
///
/// Fired when a user subscribes to the channel (first-time or resub).
/// Requires `channel:read:subscriptions` scope.
///
/// - SeeAlso: [channel.subscribe EventSub](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelsubscribe)
public struct TwitchSubscription: Codable, Sendable, Equatable {
    /// ID of the subscribing user.
    public let userId: String

    /// Login name of the subscribing user.
    public let userLogin: String?

    /// Display name of the subscribing user.
    public let userName: String

    /// Subscription tier.
    public let tier: SubscriptionTier

    /// Whether this subscription was gifted by another user.
    public let isGift: Bool

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String? = nil,
        userName: String,
        tier: SubscriptionTier,
        isGift: Bool
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.tier = tier
        self.isGift = isGift
    }
}
