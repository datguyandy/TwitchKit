import Foundation

extension HelixClient {
    public func fetchBroadcasterSubscriptionsPage(
        broadcasterID: String,
        userIDs: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchSubscription> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchSubscription> = try await request(
            endpoint: "subscriptions",
            queryItems: queryItems
        )
        return response.page
    }

    public func broadcasterSubscriptions(
        broadcasterID: String,
        userIDs: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchSubscription> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        return pagedRequest(endpoint: "subscriptions", queryItems: queryItems, pageSize: pageSize)
    }

    /// Checks whether a user subscribes to a broadcaster's channel.
    ///
    /// Requires a user access token with the `user:read:subscriptions` scope
    /// for the user in `userID`.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - userID: The user ID to check. Must match the user in the access token.
    /// - Returns: The user's subscription, or `nil` when the user doesn't
    ///   subscribe to the broadcaster (Twitch answers that case with a 404).
    /// - SeeAlso: [Check User Subscription](https://dev.twitch.tv/docs/api/reference/#check-user-subscription)
    public func checkUserSubscription(broadcasterID: String, userID: String) async throws -> UserSubscription? {
        do {
            let response: HelixResponse<UserSubscription> = try await request(
                endpoint: "subscriptions/user",
                queryItems: [
                    URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                    URLQueryItem(name: "user_id", value: userID)
                ]
            )
            return response.data.first
        } catch HelixError.notFound {
            return nil
        }
    }
}

/// A user's subscription to a broadcaster, returned by Check User Subscription.
///
/// Unlike the broadcaster-side subscription list, this response describes the
/// broadcaster being subscribed to rather than the subscribing user.
public struct UserSubscription: Decodable, Sendable, Equatable {
    /// The broadcaster's user ID.
    public let broadcasterId: String

    /// The broadcaster's login name.
    public let broadcasterLogin: String

    /// The broadcaster's display name.
    public let broadcasterName: String

    /// Whether the subscription was gifted.
    public let isGift: Bool

    /// The gifter's user ID. Present only when `isGift` is `true`.
    public let gifterId: String?

    /// The gifter's login name. Present only when `isGift` is `true`.
    public let gifterLogin: String?

    /// The gifter's display name. Present only when `isGift` is `true`.
    public let gifterName: String?

    /// The subscription tier.
    public let tier: SubscriptionTier

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        broadcasterLogin: String,
        broadcasterName: String,
        isGift: Bool,
        gifterId: String? = nil,
        gifterLogin: String? = nil,
        gifterName: String? = nil,
        tier: SubscriptionTier
    ) {
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.isGift = isGift
        self.gifterId = gifterId
        self.gifterLogin = gifterLogin
        self.gifterName = gifterName
        self.tier = tier
    }
}
