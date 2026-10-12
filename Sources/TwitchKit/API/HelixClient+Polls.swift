import Foundation

extension HelixClient {
    public func fetchPollsPage(
        broadcasterID: String,
        ids: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchPoll> {
        guard ids.count <= 20 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 20 poll IDs")
            )
        }

        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("id", values: ids)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchPoll> = try await request(endpoint: "polls", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of polls for a broadcaster.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - ids: Optional poll IDs. Twitch currently allows up to 20.
    ///   - pageSize: Optional page size.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Polls](https://dev.twitch.tv/docs/api/reference/#get-polls)
    public func polls(
        broadcasterID: String,
        ids: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchPoll> {
        HelixPagedSequence { cursor in
            try await fetchPollsPage(broadcasterID: broadcasterID, ids: ids, first: pageSize, after: cursor)
        }
    }

    public func createPoll(_ poll: PollCreateRequest) async throws -> TwitchPoll {
        let response: HelixResponse<TwitchPoll> = try await request(
            endpoint: "polls",
            method: "POST",
            body: try JSONEncoder.twitch().encode(poll)
        )
        guard let poll = response.data.first else { throw HelixError.emptyResponse }
        return poll
    }

    public func endPoll(broadcasterID: String, pollID: String, status: PollEndStatus) async throws -> TwitchPoll {
        let response: HelixResponse<TwitchPoll> = try await request(
            endpoint: "polls",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(PollEndRequest(broadcasterId: broadcasterID, id: pollID, status: status))
        )
        guard let poll = response.data.first else { throw HelixError.emptyResponse }
        return poll
    }

    public func fetchPredictionsPage(
        broadcasterID: String,
        ids: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchPrediction> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("id", values: ids)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchPrediction> = try await request(endpoint: "predictions", queryItems: queryItems)
        return response.page
    }

    /// Returns an async sequence of predictions for a broadcaster.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - ids: Optional prediction IDs.
    ///   - pageSize: Optional page size.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Predictions](https://dev.twitch.tv/docs/api/reference/#get-predictions)
    public func predictions(
        broadcasterID: String,
        ids: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchPrediction> {
        HelixPagedSequence { cursor in
            try await fetchPredictionsPage(broadcasterID: broadcasterID, ids: ids, first: pageSize, after: cursor)
        }
    }

    public func createPrediction(_ prediction: PredictionCreateRequest) async throws -> TwitchPrediction {
        let response: HelixResponse<TwitchPrediction> = try await request(
            endpoint: "predictions",
            method: "POST",
            body: try JSONEncoder.twitch().encode(prediction)
        )
        guard let prediction = response.data.first else { throw HelixError.emptyResponse }
        return prediction
    }

    public func endPrediction(
        broadcasterID: String,
        predictionID: String,
        status: PredictionEndStatus,
        winningOutcomeID: String? = nil
    ) async throws -> TwitchPrediction {
        let response: HelixResponse<TwitchPrediction> = try await request(
            endpoint: "predictions",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(
                PredictionEndRequest(
                    broadcasterId: broadcasterID,
                    id: predictionID,
                    status: status,
                    winningOutcomeId: winningOutcomeID
                )
            )
        )
        guard let prediction = response.data.first else { throw HelixError.emptyResponse }
        return prediction
    }
}

public struct TwitchPoll: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let title: String
    public let choices: [PollChoice]
    public let bitsVotingEnabled: Bool?
    public let bitsPerVote: Int?
    public let channelPointsVotingEnabled: Bool
    public let channelPointsPerVote: Int
    public let status: String
    public let duration: Int
    public let startedAt: Date
    public let endedAt: Date?
}

public struct PollChoice: Codable, Sendable, Equatable {
    public let id: String?
    public let title: String
    public let votes: Int?
    public let channelPointsVotes: Int?
    public let bitsVotes: Int?

    public init(id: String? = nil, title: String, votes: Int? = nil, channelPointsVotes: Int? = nil, bitsVotes: Int? = nil) {
        self.id = id
        self.title = title
        self.votes = votes
        self.channelPointsVotes = channelPointsVotes
        self.bitsVotes = bitsVotes
    }
}

public struct PollCreateRequest: Encodable, Sendable, Equatable {
    public let broadcasterId: String
    public let title: String
    public let choices: [PollChoice]
    public let channelPointsVotingEnabled: Bool?
    public let channelPointsPerVote: Int?
    public let duration: Int

    public init(
        broadcasterID broadcasterId: String,
        title: String,
        choices: [PollChoice],
        channelPointsVotingEnabled: Bool? = nil,
        channelPointsPerVote: Int? = nil,
        duration: Int
    ) {
        self.broadcasterId = broadcasterId
        self.title = title
        self.choices = choices
        self.channelPointsVotingEnabled = channelPointsVotingEnabled
        self.channelPointsPerVote = channelPointsPerVote
        self.duration = duration
    }
}

public enum PollEndStatus: String, Encodable, Sendable, Equatable {
    case terminated = "TERMINATED"
    case archived = "ARCHIVED"
}

private struct PollEndRequest: Encodable {
    let broadcasterId: String
    let id: String
    let status: PollEndStatus
}

public struct TwitchPrediction: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let title: String
    public let winningOutcomeId: String?
    public let outcomes: [PredictionOutcome]
    public let predictionWindow: Int
    public let status: String
    public let createdAt: Date
    public let endedAt: Date?
    public let lockedAt: Date?
}

public struct PredictionOutcome: Codable, Sendable, Equatable {
    public let id: String?
    public let title: String
    public let users: Int?
    public let channelPoints: Int?
    public let topPredictors: [PredictionTopPredictor]?
    public let color: String?

    public init(
        id: String? = nil,
        title: String,
        users: Int? = nil,
        channelPoints: Int? = nil,
        topPredictors: [PredictionTopPredictor]? = nil,
        color: String? = nil
    ) {
        self.id = id
        self.title = title
        self.users = users
        self.channelPoints = channelPoints
        self.topPredictors = topPredictors
        self.color = color
    }
}

public struct PredictionTopPredictor: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let channelPointsWon: Int?
    public let channelPointsUsed: Int
}

public struct PredictionCreateRequest: Encodable, Sendable, Equatable {
    public let broadcasterId: String
    public let title: String
    public let outcomes: [PredictionOutcome]
    public let predictionWindow: Int

    public init(broadcasterID broadcasterId: String, title: String, outcomes: [PredictionOutcome], predictionWindow: Int) {
        self.broadcasterId = broadcasterId
        self.title = title
        self.outcomes = outcomes
        self.predictionWindow = predictionWindow
    }
}

public enum PredictionEndStatus: String, Encodable, Sendable, Equatable {
    case resolved = "RESOLVED"
    case canceled = "CANCELED"
    case locked = "LOCKED"
}

private struct PredictionEndRequest: Encodable {
    let broadcasterId: String
    let id: String
    let status: PredictionEndStatus
    let winningOutcomeId: String?
}
