import Foundation

extension HelixClient {
    /// Gets games/categories by Twitch ID, name, or IGDB ID.
    ///
    /// Twitch supports up to 100 combined identifiers.
    ///
    /// - Parameters:
    ///   - ids: Twitch game/category IDs.
    ///   - names: Game/category names.
    ///   - igdbIDs: IGDB IDs.
    /// - Returns: Matching games. Twitch omits games that do not exist.
    /// - SeeAlso: [Get Games](https://dev.twitch.tv/docs/api/reference/#get-games)
    public func fetchGames(ids: [String] = [], names: [String] = [], igdbIDs: [String] = []) async throws -> [TwitchGame] {
        let requestedCount = ids.count + names.count + igdbIDs.count
        guard requestedCount > 0 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "At least one game ID, name, or IGDB ID is required")
            )
        }
        guard requestedCount <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "A maximum of 100 game IDs, names, and IGDB IDs may be requested")
            )
        }

        let queryItems =
            HelixQuery.items("id", values: ids)
            + HelixQuery.items("name", values: names)
            + HelixQuery.items("igdb_id", values: igdbIDs)
        let response: HelixResponse<TwitchGame> = try await request(endpoint: "games", queryItems: queryItems)
        return response.data
    }

    /// Gets one game/category by Twitch ID.
    ///
    /// - Parameter id: The Twitch game/category ID.
    /// - Returns: The matching game/category, or `nil` if no category has this ID.
    /// - SeeAlso: [Get Games](https://dev.twitch.tv/docs/api/reference/#get-games)
    public func fetchGame(id: String) async throws -> TwitchGame? {
        try await fetchGames(ids: [id]).first
    }

    /// Gets one game/category by name.
    ///
    /// - Parameter name: The game/category name.
    /// - Returns: The matching game/category, or `nil` if no category has this name.
    /// - SeeAlso: [Get Games](https://dev.twitch.tv/docs/api/reference/#get-games)
    public func fetchGame(name: String) async throws -> TwitchGame? {
        try await fetchGames(names: [name]).first
    }

    /// Gets one page of top Twitch games/categories.
    ///
    /// - Parameters:
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    ///   - previousCursor: Optional cursor used to get the previous page.
    /// - Returns: A page of top games sorted by current popularity.
    /// - SeeAlso: [Get Top Games](https://dev.twitch.tv/docs/api/reference/#get-top-games)
    public func fetchTopGamesPage(
        first: Int? = nil,
        after cursor: String? = nil,
        before previousCursor: String? = nil
    ) async throws -> HelixPage<TwitchGame> {
        var queryItems: [URLQueryItem] = []
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, before: previousCursor)

        let response: HelixResponse<TwitchGame> = try await request(
            endpoint: "games/top",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Returns an async sequence of top Twitch games/categories.
    ///
    /// - Parameter pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Top Games](https://dev.twitch.tv/docs/api/reference/#get-top-games)
    public func topGames(pageSize: Int? = nil) -> HelixPagedSequence<TwitchGame> {
        pagedRequest(endpoint: "games/top", pageSize: pageSize)
    }
}
