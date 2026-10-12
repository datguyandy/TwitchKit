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
}

public struct HypeTrainContribution: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let type: String
    public let total: Int
}

public struct HypeTrainParticipant: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct HypeTrainRecord: Decodable, Sendable, Equatable {
    public let level: Int
    public let total: Int
    public let achievedAt: Date
}
