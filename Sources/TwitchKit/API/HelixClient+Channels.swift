import Foundation

extension HelixClient {
    /// Gets information about the specified channels.
    ///
    /// Returns the channel's title, game, language, tags, delay, content classification labels,
    /// and branded content status. The `delay` field requires a user access token and partner status.
    ///
    /// - Parameter broadcasterIDs: Broadcaster user IDs. Twitch currently allows up to 100.
    /// - Returns: Channel information for the requested broadcasters.
    /// - SeeAlso: [Get Channel Information](https://dev.twitch.tv/docs/api/reference/#get-channel-information)
    public func fetchChannelsInfo(broadcasterIDs: [String]) async throws -> [TwitchChannel] {
        guard !broadcasterIDs.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "At least one broadcaster ID is required")
            )
        }
        guard broadcasterIDs.count <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 100 broadcaster IDs")
            )
        }

        let response: HelixResponse<TwitchChannel> = try await request(
            endpoint: "channels",
            queryItems: HelixQuery.items("broadcaster_id", values: broadcasterIDs)
        )
        return response.data
    }

    /// Gets information about the specified channel.
    ///
    /// Returns the channel's title, game, language, tags, delay, content classification labels,
    /// and branded content status. The `delay` field requires a user access token and partner status.
    ///
    /// - Parameter broadcasterID: The broadcaster's user ID.
    /// - Returns: The channel information, or `nil` if no broadcaster has this ID.
    /// - SeeAlso: [Get Channel Information](https://dev.twitch.tv/docs/api/reference/#get-channel-information)
    public func fetchChannelInfo(broadcasterID: String) async throws -> TwitchChannel? {
        try await fetchChannelsInfo(broadcasterIDs: [broadcasterID]).first
    }
    /// Updates a channel's properties.
    ///
    /// All fields are optional, but at least one must be specified.
    /// Returns 204 No Content on success.
    ///
    /// Requires `channel:manage:broadcast` scope. The `broadcasterID` must match
    /// the authenticated user's ID.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID (must match the authenticated user).
    ///   - update: The channel fields to modify.
    ///
    /// - Throws: `HelixError.badRequest` if no fields specified, title is empty, or tags are invalid.
    ///   `HelixError.unauthorized` if scope is missing or broadcaster_id doesn't match token.
    ///   `HelixError.forbidden` for age/region-restricted CCL changes.
    ///
    /// - SeeAlso: [Modify Channel Information](https://dev.twitch.tv/docs/api/reference/#modify-channel-information)
    public func updateChannelInfo(broadcasterID: String, with update: ChannelInfoUpdate) async throws {
        let bodyData = try JSONEncoder.twitch().encode(update)

        try await requestNoContent(
            endpoint: "channels",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            body: bodyData
        )
    }
    /// Gets one page of users who follow the specified broadcaster.
    ///
    /// Requires `moderator:read:followers` scope.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - userID: Optional user ID to check whether a specific user follows the broadcaster.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of followers and the next pagination cursor, if any.
    /// - SeeAlso: [Get Channel Followers](https://dev.twitch.tv/docs/api/reference/#get-channel-followers)
    public func fetchChannelFollowersPage(
        broadcasterID: String,
        userID: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchFollow> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchFollow> = try await request(
            endpoint: "channels/followers",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of users who follow the specified broadcaster.
    ///
    /// Requires `moderator:read:followers` scope.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - userID: Optional user ID to check whether a specific user follows the broadcaster.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Channel Followers](https://dev.twitch.tv/docs/api/reference/#get-channel-followers)
    public func channelFollowers(
        broadcasterID: String,
        userID: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchFollow> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)

        return pagedRequest(
            endpoint: "channels/followers",
            queryItems: queryItems,
            pageSize: pageSize
        )
    }

    /// Gets one page of broadcasters followed by the specified user.
    ///
    /// - Parameters:
    ///   - userID: The user's ID.
    ///   - broadcasterID: Optional broadcaster ID used to check a specific follow relationship.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of followed channels.
    /// - SeeAlso: [Get Followed Channels](https://dev.twitch.tv/docs/api/reference/#get-followed-channels)
    public func fetchFollowedChannelsPage(
        userID: String,
        broadcasterID: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<FollowedChannel> {
        var queryItems = [URLQueryItem(name: "user_id", value: userID)]
        HelixQuery.append(HelixQuery.item("broadcaster_id", broadcasterID), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<FollowedChannel> = try await request(
            endpoint: "channels/followed",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of broadcasters followed by the specified user.
    ///
    /// - Parameters:
    ///   - userID: The user's ID.
    ///   - broadcasterID: Optional broadcaster ID used to check a specific follow relationship.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Followed Channels](https://dev.twitch.tv/docs/api/reference/#get-followed-channels)
    public func followedChannels(
        userID: String,
        broadcasterID: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<FollowedChannel> {
        var queryItems = [URLQueryItem(name: "user_id", value: userID)]
        HelixQuery.append(HelixQuery.item("broadcaster_id", broadcasterID), to: &queryItems)

        return pagedRequest(
            endpoint: "channels/followed",
            queryItems: queryItems,
            pageSize: pageSize
        )
    }

    /// Gets users who can edit the broadcaster's channel information.
    ///
    /// - Parameter broadcasterID: The broadcaster's user ID.
    /// - Returns: Channel editors.
    /// - SeeAlso: [Get Channel Editors](https://dev.twitch.tv/docs/api/reference/#get-channel-editors)
    public func fetchChannelEditors(broadcasterID: String) async throws -> [ChannelEditor] {
        let response: HelixResponse<ChannelEditor> = try await request(
            endpoint: "channels/editors",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        return response.data
    }

    /// Gets Twitch content classification labels.
    ///
    /// - Parameter locale: Optional BCP-47 locale string such as `"en-US"`.
    /// - Returns: Content classification labels.
    /// - SeeAlso: [Get Content Classification Labels](https://dev.twitch.tv/docs/api/reference/#get-content-classification-labels)
    public func fetchContentClassificationLabels(locale: String? = nil) async throws -> [TwitchContentClassificationLabel] {
        let queryItems = locale.map { [URLQueryItem(name: "locale", value: $0)] }
        let response: HelixResponse<TwitchContentClassificationLabel> = try await request(
            endpoint: "content_classification_labels",
            queryItems: queryItems
        )
        return response.data
    }
}

public struct FollowedChannel: Decodable, Sendable, Equatable {
    public let broadcasterID: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let followedAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterID: String,
        broadcasterLogin: String,
        broadcasterName: String,
        followedAt: Date
    ) {
        self.broadcasterID = broadcasterID
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.followedAt = followedAt
    }
}

public struct ChannelEditor: Decodable, Sendable, Equatable {
    public let userID: String
    public let userName: String
    public let createdAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userID: String,
        userName: String,
        createdAt: Date
    ) {
        self.userID = userID
        self.userName = userName
        self.createdAt = createdAt
    }
}

public struct TwitchContentClassificationLabel: Decodable, Sendable, Equatable {
    public let id: String
    public let description: String
    public let name: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        description: String,
        name: String
    ) {
        self.id = id
        self.description = description
        self.name = name
    }
}

/// A content classification label to enable or disable on a channel.
///
/// Used with `updateChannelInfo(contentClassificationLabels:)`.
public struct ContentClassificationLabel: Sendable {
    /// The label ID (e.g., `"Gambling"`, `"SexualThemes"`).
    public let id: String

    /// `true` to enable the label, `false` to remove it.
    public let isEnabled: Bool

    public init(id: String, isEnabled: Bool) {
        self.id = id
        self.isEnabled = isEnabled
    }
}

extension ContentClassificationLabel: Encodable, Equatable {}

/// Request body for modifying channel information.
public struct ChannelInfoUpdate: Encodable, Sendable, Equatable {
    public let title: String?
    public let gameID: String?
    public let broadcasterLanguage: String?
    public let delay: Int?
    public let tags: [String]?
    public let contentClassificationLabels: [ContentClassificationLabel]?
    public let isBrandedContent: Bool?

    public init(
        title: String? = nil,
        gameID: String? = nil,
        broadcasterLanguage: String? = nil,
        delay: Int? = nil,
        tags: [String]? = nil,
        contentClassificationLabels: [ContentClassificationLabel]? = nil,
        isBrandedContent: Bool? = nil
    ) {
        self.title = title
        self.gameID = gameID
        self.broadcasterLanguage = broadcasterLanguage
        self.delay = delay
        self.tags = tags
        self.contentClassificationLabels = contentClassificationLabels
        self.isBrandedContent = isBrandedContent
    }

    enum CodingKeys: String, CodingKey {
        case title
        case gameID
        case broadcasterLanguage
        case delay
        case tags
        case contentClassificationLabels
        case isBrandedContent
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(gameID, forKey: .gameID)
        try container.encodeIfPresent(broadcasterLanguage, forKey: .broadcasterLanguage)
        try container.encodeIfPresent(delay, forKey: .delay)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(contentClassificationLabels, forKey: .contentClassificationLabels)
        try container.encodeIfPresent(isBrandedContent, forKey: .isBrandedContent)
    }
}
