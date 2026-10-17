import Foundation

extension HelixClient {
    public func createClip(broadcasterID: String, hasDelay: Bool? = nil, title: String? = nil, duration: Double? = nil) async throws -> ClipCreate {
        try validateClipDuration(duration)
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        HelixQuery.append(HelixQuery.item("title", title), to: &queryItems)
        HelixQuery.append(duration.map { URLQueryItem(name: "duration", value: String($0)) }, to: &queryItems)
        HelixQuery.append(hasDelay.map { URLQueryItem(name: "has_delay", value: String($0)) }, to: &queryItems)

        let response: HelixResponse<ClipCreate> = try await request(
            endpoint: "clips",
            method: "POST",
            queryItems: queryItems
        )
        guard let clip = response.data.first else { throw HelixError.emptyResponse }
        return clip
    }

    public func createClipFromVOD(
        broadcasterID: String,
        editorID: String,
        vodID: String,
        vodOffset: Int,
        title: String,
        duration: Double? = nil
    ) async throws -> ClipCreate {
        try validateClipDuration(duration)
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "editor_id", value: editorID),
            URLQueryItem(name: "vod_id", value: vodID),
            URLQueryItem(name: "vod_offset", value: String(vodOffset)),
            URLQueryItem(name: "title", value: title)
        ]
        HelixQuery.append(duration.map { URLQueryItem(name: "duration", value: String($0)) }, to: &queryItems)

        let response: HelixResponse<ClipCreate> = try await request(
            endpoint: "videos/clips",
            method: "POST",
            queryItems: queryItems
        )
        guard let clip = response.data.first else { throw HelixError.emptyResponse }
        return clip
    }

    public func fetchClipsPage(
        broadcasterID: String? = nil,
        gameID: String? = nil,
        ids: [String] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        first: Int? = nil,
        after cursor: String? = nil,
        before previousCursor: String? = nil
    ) async throws -> HelixPage<TwitchClip> {
        let filterCount = [broadcasterID != nil, gameID != nil, !ids.isEmpty].filter { $0 }.count
        guard filterCount == 1 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Exactly one of broadcaster ID, game ID, or clip IDs must be specified")
            )
        }

        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("broadcaster_id", broadcasterID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        queryItems += HelixQuery.items("id", values: ids)
        HelixQuery.append(startedAt.map { URLQueryItem(name: "started_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        HelixQuery.append(endedAt.map { URLQueryItem(name: "ended_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, before: previousCursor)

        let response: HelixResponse<TwitchClip> = try await request(endpoint: "clips", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of clips.
    ///
    /// Exactly one of `broadcasterID`, `gameID`, or `ids` must be specified;
    /// the ID filters are mutually exclusive.
    ///
    /// - Parameters:
    ///   - broadcasterID: Optional broadcaster whose clips are returned.
    ///   - gameID: Optional game/category whose clips are returned.
    ///   - ids: Optional clip IDs. Twitch currently allows up to 100.
    ///   - startedAt: Optional start of the date range filter.
    ///   - endedAt: Optional end of the date range filter.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Clips](https://dev.twitch.tv/docs/api/reference/#get-clips)
    public func clips(
        broadcasterID: String? = nil,
        gameID: String? = nil,
        ids: [String] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchClip> {
        HelixPagedSequence { cursor in
            try await fetchClipsPage(
                broadcasterID: broadcasterID,
                gameID: gameID,
                ids: ids,
                startedAt: startedAt,
                endedAt: endedAt,
                first: pageSize,
                after: cursor
            )
        }
    }

    public func fetchClipDownloads(broadcasterID: String, editorID: String, clipIDs: [String]) async throws -> [ClipDownload] {
        guard !clipIDs.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "At least one clip ID is required")
            )
        }
        guard clipIDs.count <= 10 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 10 clip IDs")
            )
        }

        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "editor_id", value: editorID)
        ]
        queryItems += HelixQuery.items("clip_id", values: clipIDs)

        let response: HelixResponse<ClipDownload> = try await request(
            endpoint: "clips/downloads",
            queryItems: queryItems
        )
        return response.data
    }

    public func fetchVideosPage(
        ids: [String] = [],
        userID: String? = nil,
        gameID: String? = nil,
        language: String? = nil,
        period: String? = nil,
        sort: String? = nil,
        type: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil,
        before previousCursor: String? = nil
    ) async throws -> HelixPage<TwitchVideo> {
        let filterCount = [!ids.isEmpty, userID != nil, gameID != nil].filter { $0 }.count
        guard filterCount == 1 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Exactly one of video IDs, user ID, or game ID must be specified")
            )
        }

        var queryItems = HelixQuery.items("id", values: ids)
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("language", language), to: &queryItems)
        HelixQuery.append(HelixQuery.item("period", period), to: &queryItems)
        HelixQuery.append(HelixQuery.item("sort", sort), to: &queryItems)
        HelixQuery.append(HelixQuery.item("type", type), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, before: previousCursor)

        let response: HelixResponse<TwitchVideo> = try await request(endpoint: "videos", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of videos.
    ///
    /// Exactly one of `ids`, `userID`, or `gameID` must be specified;
    /// the ID filters are mutually exclusive.
    ///
    /// - Parameters:
    ///   - ids: Optional video IDs. Twitch currently allows up to 100.
    ///   - userID: Optional user whose videos are returned.
    ///   - gameID: Optional game/category whose videos are returned.
    ///   - language: Optional language filter (used only with `gameID`).
    ///   - period: Optional period filter such as `"day"` or `"month"`.
    ///   - sort: Optional sort order such as `"time"` or `"views"`.
    ///   - type: Optional video type such as `"archive"` or `"highlight"`.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Videos](https://dev.twitch.tv/docs/api/reference/#get-videos)
    public func videos(
        ids: [String] = [],
        userID: String? = nil,
        gameID: String? = nil,
        language: String? = nil,
        period: String? = nil,
        sort: String? = nil,
        type: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchVideo> {
        HelixPagedSequence { cursor in
            try await fetchVideosPage(
                ids: ids,
                userID: userID,
                gameID: gameID,
                language: language,
                period: period,
                sort: sort,
                type: type,
                first: pageSize,
                after: cursor
            )
        }
    }

    public func deleteVideos(ids: [String]) async throws -> [String] {
        guard !ids.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "At least one video ID is required")
            )
        }
        guard ids.count <= 5 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 5 video IDs per delete request")
            )
        }

        // Twitch returns the deleted IDs as a plain string array
        // (`"data": ["1234", "9876"]`), not as objects.
        let response: HelixResponse<String> = try await request(
            endpoint: "videos",
            method: "DELETE",
            queryItems: HelixQuery.items("id", values: ids)
        )
        return response.data
    }

}

public struct ClipCreate: Decodable, Sendable, Equatable {
    public let id: String
    public let editURL: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        editURL: String
    ) {
        self.id = id
        self.editURL = editURL
    }
}

public struct TwitchClip: Decodable, Sendable, Equatable {
    public let id: String
    public let url: String
    public let embedURL: String
    public let broadcasterID: String
    public let broadcasterName: String
    public let creatorID: String
    public let creatorName: String
    public let videoID: String
    public let gameID: String
    public let language: String
    public let title: String
    public let viewCount: Int
    public let createdAt: Date
    public let thumbnailURL: String
    public let duration: Double
    public let vodOffset: Int?
    public let isFeatured: Bool?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        url: String,
        embedURL: String,
        broadcasterID: String,
        broadcasterName: String,
        creatorID: String,
        creatorName: String,
        videoID: String,
        gameID: String,
        language: String,
        title: String,
        viewCount: Int,
        createdAt: Date,
        thumbnailURL: String,
        duration: Double,
        vodOffset: Int? = nil,
        isFeatured: Bool? = nil
    ) {
        self.id = id
        self.url = url
        self.embedURL = embedURL
        self.broadcasterID = broadcasterID
        self.broadcasterName = broadcasterName
        self.creatorID = creatorID
        self.creatorName = creatorName
        self.videoID = videoID
        self.gameID = gameID
        self.language = language
        self.title = title
        self.viewCount = viewCount
        self.createdAt = createdAt
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.vodOffset = vodOffset
        self.isFeatured = isFeatured
    }
}

public struct ClipDownload: Decodable, Sendable, Equatable {
    public let clipID: String
    public let landscapeDownloadURL: String?
    public let portraitDownloadURL: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        clipID: String,
        landscapeDownloadURL: String? = nil,
        portraitDownloadURL: String? = nil
    ) {
        self.clipID = clipID
        self.landscapeDownloadURL = landscapeDownloadURL
        self.portraitDownloadURL = portraitDownloadURL
    }
}

public struct TwitchVideo: Decodable, Sendable, Equatable {
    public let id: String
    public let streamID: String?
    public let userID: String
    public let userLogin: String
    public let userName: String
    public let title: String
    public let description: String
    public let createdAt: Date
    public let publishedAt: Date
    public let url: String
    public let thumbnailURL: String
    public let viewable: String
    public let viewCount: Int
    public let language: String
    public let type: String
    public let duration: String
    public let mutedSegments: [MutedVideoSegment]?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        streamID: String? = nil,
        userID: String,
        userLogin: String,
        userName: String,
        title: String,
        description: String,
        createdAt: Date,
        publishedAt: Date,
        url: String,
        thumbnailURL: String,
        viewable: String,
        viewCount: Int,
        language: String,
        type: String,
        duration: String,
        mutedSegments: [MutedVideoSegment]? = nil
    ) {
        self.id = id
        self.streamID = streamID
        self.userID = userID
        self.userLogin = userLogin
        self.userName = userName
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.viewable = viewable
        self.viewCount = viewCount
        self.language = language
        self.type = type
        self.duration = duration
        self.mutedSegments = mutedSegments
    }
}

public struct MutedVideoSegment: Decodable, Sendable, Equatable {
    public let duration: Int
    public let offset: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        duration: Int,
        offset: Int
    ) {
        self.duration = duration
        self.offset = offset
    }
}

private func validateClipDuration(_ duration: Double?) throws {
    guard let duration else { return }
    // Allow floating-point representation noise, but not sub-tenth precision.
    guard duration.isFinite, (5...60).contains(duration),
          abs(duration * 10 - (duration * 10).rounded()) < 1e-8 else {
        throw HelixError.badRequest(.fallback(status: 400, message: "Clip duration must be 5–60 seconds in 0.1-second increments"))
    }
}
