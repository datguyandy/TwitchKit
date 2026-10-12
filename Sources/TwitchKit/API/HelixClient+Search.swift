import Foundation

extension HelixClient {
    /// Gets one page of categories matching a search query.
    ///
    /// - Parameters:
    ///   - query: Search query.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of matching categories.
    /// - SeeAlso: [Search Categories](https://dev.twitch.tv/docs/api/reference/#search-categories)
    public func fetchSearchCategoriesPage(
        query: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchGame> {
        var queryItems = [URLQueryItem(name: "query", value: query)]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchGame> = try await request(
            endpoint: "search/categories",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of categories matching a search query.
    ///
    /// - Parameters:
    ///   - query: Search query.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Search Categories](https://dev.twitch.tv/docs/api/reference/#search-categories)
    public func searchCategories(query: String, pageSize: Int? = nil) -> HelixPagedSequence<TwitchGame> {
        pagedRequest(
            endpoint: "search/categories",
            queryItems: [URLQueryItem(name: "query", value: query)],
            pageSize: pageSize
        )
    }

    /// Gets one page of channels matching a search query.
    ///
    /// - Parameters:
    ///   - query: Search query.
    ///   - liveOnly: Whether to include only live channels.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of matching channels.
    /// - SeeAlso: [Search Channels](https://dev.twitch.tv/docs/api/reference/#search-channels)
    public func fetchSearchChannelsPage(
        query: String,
        liveOnly: Bool? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<SearchChannel> {
        var queryItems = [URLQueryItem(name: "query", value: query)]
        HelixQuery.append(liveOnly.map { URLQueryItem(name: "live_only", value: String($0)) }, to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<SearchChannel> = try await request(
            endpoint: "search/channels",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of channels matching a search query.
    ///
    /// - Parameters:
    ///   - query: Search query.
    ///   - liveOnly: Whether to include only live channels.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Search Channels](https://dev.twitch.tv/docs/api/reference/#search-channels)
    public func searchChannels(
        query: String,
        liveOnly: Bool? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<SearchChannel> {
        var queryItems = [URLQueryItem(name: "query", value: query)]
        HelixQuery.append(liveOnly.map { URLQueryItem(name: "live_only", value: String($0)) }, to: &queryItems)

        return pagedRequest(
            endpoint: "search/channels",
            queryItems: queryItems,
            pageSize: pageSize
        )
    }
}

public struct SearchChannel: Decodable, Sendable, Equatable {
    public let broadcasterLanguage: String
    public let broadcasterLogin: String
    public let displayName: String
    public let gameId: String
    public let gameName: String
    public let id: String
    public let isLive: Bool
    public let tagIds: [String]
    public let tags: [String]
    public let thumbnailUrl: String
    public let title: String
    public let startedAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterLanguage: String,
        broadcasterLogin: String,
        displayName: String,
        gameId: String,
        gameName: String,
        id: String,
        isLive: Bool,
        tagIds: [String],
        tags: [String],
        thumbnailUrl: String,
        title: String,
        startedAt: Date? = nil
    ) {
        self.broadcasterLanguage = broadcasterLanguage
        self.broadcasterLogin = broadcasterLogin
        self.displayName = displayName
        self.gameId = gameId
        self.gameName = gameName
        self.id = id
        self.isLive = isLive
        self.tagIds = tagIds
        self.tags = tags
        self.thumbnailUrl = thumbnailUrl
        self.title = title
        self.startedAt = startedAt
    }

    private enum CodingKeys: String, CodingKey {
        case broadcasterLanguage, broadcasterLogin, displayName, gameId
        case gameName, id, isLive, tagIds, tags, thumbnailUrl, title, startedAt
    }

    /// Custom decoding solely for `startedAt`: Twitch sends
    /// `"started_at": ""` — an empty string, not null — when the channel
    /// is offline ("The string is empty if the broadcaster is not
    /// streaming live"). The key is present, so `Date?` + the date
    /// strategy would try to parse "" and throw, failing the whole
    /// search page whenever any result is offline. Decode the raw string
    /// and map non-parsing values (incl. empty) to nil instead.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        broadcasterLanguage = try container.decode(String.self, forKey: .broadcasterLanguage)
        broadcasterLogin = try container.decode(String.self, forKey: .broadcasterLogin)
        displayName = try container.decode(String.self, forKey: .displayName)
        gameId = try container.decode(String.self, forKey: .gameId)
        gameName = try container.decode(String.self, forKey: .gameName)
        id = try container.decode(String.self, forKey: .id)
        isLive = try container.decode(Bool.self, forKey: .isLive)
        // tag_ids is deprecated upstream; tolerate it disappearing.
        tagIds = try container.decodeIfPresent([String].self, forKey: .tagIds) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        thumbnailUrl = try container.decode(String.self, forKey: .thumbnailUrl)
        title = try container.decode(String.self, forKey: .title)
        let rawStartedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
        startedAt = rawStartedAt.flatMap(TwitchDateParser.date(from:))
    }
}
