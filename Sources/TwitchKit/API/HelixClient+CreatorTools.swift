import Foundation

extension HelixClient {
    public func fetchCreatorGoals(broadcasterID broadcasterId: String) async throws -> [CreatorGoal] {
        let response: HelixResponse<CreatorGoal> = try await request(
            endpoint: "goals",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data
    }

    public func startRaid(fromBroadcasterID fromBroadcasterId: String, toBroadcasterID toBroadcasterId: String) async throws -> RaidStart {
        let response: HelixResponse<RaidStart> = try await request(
            endpoint: "raids",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "from_broadcaster_id", value: fromBroadcasterId),
                URLQueryItem(name: "to_broadcaster_id", value: toBroadcasterId)
            ]
        )
        guard let raid = response.data.first else { throw HelixError.emptyResponse }
        return raid
    }

    public func cancelRaid(broadcasterID: String) async throws {
        try await requestNoContent(
            endpoint: "raids",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
    }

    public func createStreamMarker(userID: String, description: String? = nil) async throws -> StreamMarker {
        let response: HelixResponse<StreamMarker> = try await request(
            endpoint: "streams/markers",
            method: "POST",
            body: try JSONEncoder.twitch().encode(StreamMarkerCreateRequest(userId: userID, description: description))
        )
        guard let marker = response.data.first else { throw HelixError.emptyResponse }
        return marker
    }

    /// Gets one page of stream markers.
    ///
    /// Exactly one of `userID` or `videoID` must be specified.
    public func fetchStreamMarkersPage(
        userID: String? = nil,
        videoID: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<StreamMarkersByVideo> {
        guard (userID != nil) != (videoID != nil) else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Exactly one of user ID or video ID must be specified")
            )
        }

        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("video_id", videoID), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<StreamMarkersByVideo> = try await request(
            endpoint: "streams/markers",
            queryItems: queryItems
        )
        return response.page
    }
}

public struct CreatorGoal: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterId: String
    public let broadcasterName: String
    public let broadcasterLogin: String
    public let type: String
    public let description: String
    public let currentAmount: Int
    public let targetAmount: Int
    public let createdAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterId: String,
        broadcasterName: String,
        broadcasterLogin: String,
        type: String,
        description: String,
        currentAmount: Int,
        targetAmount: Int,
        createdAt: Date
    ) {
        self.id = id
        self.broadcasterId = broadcasterId
        self.broadcasterName = broadcasterName
        self.broadcasterLogin = broadcasterLogin
        self.type = type
        self.description = description
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
        self.createdAt = createdAt
    }
}

public struct RaidStart: Decodable, Sendable, Equatable {
    public let createdAt: Date
    public let isMature: Bool

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        createdAt: Date,
        isMature: Bool
    ) {
        self.createdAt = createdAt
        self.isMature = isMature
    }
}

private struct StreamMarkerCreateRequest: Encodable {
    let userId: String
    let description: String?
}

public struct StreamMarker: Decodable, Sendable, Equatable {
    public let id: String
    public let createdAt: Date
    public let description: String
    public let positionSeconds: Int
    public let url: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        createdAt: Date,
        description: String,
        positionSeconds: Int,
        url: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.description = description
        self.positionSeconds = positionSeconds
        self.url = url
    }
}

public struct StreamMarkersByVideo: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let videos: [VideoMarkers]

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        videos: [VideoMarkers]
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.videos = videos
    }

    public struct VideoMarkers: Decodable, Sendable, Equatable {
        public let videoId: String
        public let markers: [StreamMarker]

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            videoId: String,
            markers: [StreamMarker]
        ) {
            self.videoId = videoId
            self.markers = markers
        }
    }
}
