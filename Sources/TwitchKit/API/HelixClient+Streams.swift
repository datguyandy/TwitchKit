import Foundation

extension HelixClient {
    /// Gets one page of live streams.
    ///
    /// - Parameters:
    ///   - userIDs: User IDs used to filter live streams.
    ///   - userLogins: User login names used to filter live streams.
    ///   - gameIDs: Game/category IDs used to filter live streams.
    ///   - languages: Stream languages to include.
    ///   - type: Optional stream type filter.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    ///   - previousCursor: Optional cursor for fetching the previous page.
    /// - Returns: A page of live streams.
    /// - SeeAlso: [Get Streams](https://dev.twitch.tv/docs/api/reference/#get-streams)
    public func fetchStreamsPage(
        userIDs: [String] = [],
        userLogins: [String] = [],
        gameIDs: [String] = [],
        languages: [String] = [],
        type: TwitchStreamType? = nil,
        first: Int? = nil,
        after cursor: String? = nil,
        before previousCursor: String? = nil
    ) async throws -> HelixPage<TwitchStream> {
        guard userIDs.count <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 100 user IDs")
            )
        }
        guard userLogins.count <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 100 user logins")
            )
        }
        guard gameIDs.count <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 100 game IDs")
            )
        }

        var queryItems =
            HelixQuery.items("user_id", values: userIDs)
            + HelixQuery.items("user_login", values: userLogins)
            + HelixQuery.items("game_id", values: gameIDs)
            + HelixQuery.items("language", values: languages)
        HelixQuery.append(HelixQuery.item("type", type?.rawValue), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, before: previousCursor)

        let response: HelixResponse<TwitchStream> = try await request(
            endpoint: "streams",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Returns an async sequence of live streams.
    ///
    /// - Parameters:
    ///   - userIDs: User IDs used to filter live streams.
    ///   - userLogins: User login names used to filter live streams.
    ///   - gameIDs: Game/category IDs used to filter live streams.
    ///   - languages: Stream languages to include.
    ///   - type: Optional stream type filter.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Streams](https://dev.twitch.tv/docs/api/reference/#get-streams)
    public func streams(
        userIDs: [String] = [],
        userLogins: [String] = [],
        gameIDs: [String] = [],
        languages: [String] = [],
        type: TwitchStreamType? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchStream> {
        var queryItems =
            HelixQuery.items("user_id", values: userIDs)
            + HelixQuery.items("user_login", values: userLogins)
            + HelixQuery.items("game_id", values: gameIDs)
            + HelixQuery.items("language", values: languages)
        HelixQuery.append(HelixQuery.item("type", type?.rawValue), to: &queryItems)

        return pagedRequest(
            endpoint: "streams",
            queryItems: queryItems,
            pageSize: pageSize
        )
    }

    /// Gets a user's live stream, if the user is currently broadcasting.
    ///
    /// - Parameter userId: The broadcaster's user ID.
    /// - Returns: The live stream or `nil` when the user is offline.
    /// - SeeAlso: [Get Streams](https://dev.twitch.tv/docs/api/reference/#get-streams)
    public func fetchStream(userID userId: String) async throws -> TwitchStream? {
        try await fetchStreamsPage(userIDs: [userId], first: 1).data.first
    }

    /// Gets the stream key for the specified broadcaster.
    ///
    /// The stream key is used in the RTMP URL to authenticate the stream.
    /// Requires `channel:read:stream_key` scope.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: The stream key string.
    /// - SeeAlso: [Get Stream Key](https://dev.twitch.tv/docs/api/reference/#get-stream-key)
    public func fetchStreamKey(broadcasterID broadcasterId: String) async throws -> String {
        let response: HelixResponse<StreamKeyResponse> = try await request(
            endpoint: "streams/key",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        guard let key = response.data.first?.streamKey else { throw HelixError.emptyResponse }
        return key
    }

    /// Gets one page of followed live streams for a user.
    public func fetchFollowedStreamsPage(
        userID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchStream> {
        var queryItems = [URLQueryItem(name: "user_id", value: userID)]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchStream> = try await request(
            endpoint: "streams/followed",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of followed live streams for a user.
    public func followedStreams(userID: String, pageSize: Int? = nil) -> HelixPagedSequence<TwitchStream> {
        pagedRequest(
            endpoint: "streams/followed",
            queryItems: [URLQueryItem(name: "user_id", value: userID)],
            pageSize: pageSize
        )
    }
}

private struct StreamKeyResponse: Decodable, Sendable {
    let streamKey: String
}
