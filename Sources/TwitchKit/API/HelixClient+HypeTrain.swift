import Foundation

extension HelixClient {
    /// Gets the current Hype Train status for a broadcaster.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Hype Train status, or `nil` if no status is returned.
    /// - SeeAlso: [Get Hype Train Status](https://dev.twitch.tv/docs/api/reference/#get-hype-train-status)
    public func fetchHypeTrainStatus(broadcasterID broadcasterId: String) async throws -> HypeTrainStatus? {
        let response: HelixResponse<HypeTrainStatus> = try await request(
            endpoint: "hypetrain/status",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data.first
    }
}

public struct HypeTrainStatus: Decodable, Sendable, Equatable {
    public let current: HypeTrainCurrent?
    public let allTimeHigh: HypeTrainRecord?
    public let sharedAllTimeHigh: HypeTrainRecord?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        current: HypeTrainCurrent? = nil,
        allTimeHigh: HypeTrainRecord? = nil,
        sharedAllTimeHigh: HypeTrainRecord? = nil
    ) {
        self.current = current
        self.allTimeHigh = allTimeHigh
        self.sharedAllTimeHigh = sharedAllTimeHigh
    }
}

public struct HypeTrainCurrent: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let total: Int
    public let progress: Int
    public let goal: Int
    public let topContributions: [HypeTrainContribution]
    public let level: Int
    public let startedAt: Date
    public let expiresAt: Date
    public let type: String
    public let isSharedTrain: Bool
    public let sharedTrainParticipants: [HypeTrainParticipant]?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        total: Int,
        progress: Int,
        goal: Int,
        topContributions: [HypeTrainContribution],
        level: Int,
        startedAt: Date,
        expiresAt: Date,
        type: String,
        isSharedTrain: Bool,
        sharedTrainParticipants: [HypeTrainParticipant]? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.total = total
        self.progress = progress
        self.goal = goal
        self.topContributions = topContributions
        self.level = level
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.type = type
        self.isSharedTrain = isSharedTrain
        self.sharedTrainParticipants = sharedTrainParticipants
    }
}

public struct HypeTrainContribution: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let type: String
    public let total: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        type: String,
        total: Int
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.type = type
        self.total = total
    }
}

public struct HypeTrainParticipant: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
    }
}

public struct HypeTrainRecord: Decodable, Sendable, Equatable {
    public let level: Int
    public let total: Int
    public let achievedAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        level: Int,
        total: Int,
        achievedAt: Date
    ) {
        self.level = level
        self.total = total
        self.achievedAt = achievedAt
    }
}
