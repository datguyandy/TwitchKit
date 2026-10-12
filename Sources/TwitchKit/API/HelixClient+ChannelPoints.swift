import Foundation

extension HelixClient {
    public func fetchCustomRewards(
        broadcasterID: String,
        ids: [String] = [],
        onlyManageableRewards: Bool? = nil
    ) async throws -> [CustomReward] {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("id", values: ids)
        HelixQuery.append(onlyManageableRewards.map { URLQueryItem(name: "only_manageable_rewards", value: String($0)) }, to: &queryItems)

        let response: HelixResponse<CustomReward> = try await request(
            endpoint: "channel_points/custom_rewards",
            queryItems: queryItems
        )
        return response.data
    }

    public func createCustomReward(broadcasterID: String, request create: CustomRewardCreateRequest) async throws -> CustomReward {
        let response: HelixResponse<CustomReward> = try await request(
            endpoint: "channel_points/custom_rewards",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            body: try JSONEncoder.twitch().encode(create)
        )
        guard let reward = response.data.first else { throw HelixError.emptyResponse }
        return reward
    }

    public func updateCustomReward(
        broadcasterID: String,
        rewardID: String,
        with update: CustomRewardUpdateRequest
    ) async throws -> CustomReward {
        let response: HelixResponse<CustomReward> = try await request(
            endpoint: "channel_points/custom_rewards",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "id", value: rewardID)
            ],
            body: try JSONEncoder.twitch().encode(update)
        )
        guard let reward = response.data.first else { throw HelixError.emptyResponse }
        return reward
    }

    public func deleteCustomReward(broadcasterID: String, rewardID: String) async throws {
        try await requestNoContent(
            endpoint: "channel_points/custom_rewards",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "id", value: rewardID)
            ]
        )
    }

    public func fetchCustomRewardRedemptionsPage(
        broadcasterID: String,
        rewardID: String,
        ids: [String] = [],
        status: ChannelPointsRedemptionStatus? = nil,
        sort: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<CustomRewardRedemption> {
        guard ids.count <= 50 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 50 redemption IDs")
            )
        }
        guard !ids.isEmpty || status != nil else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "A redemption status is required when no redemption IDs are specified")
            )
        }

        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "reward_id", value: rewardID)
        ]
        queryItems += HelixQuery.items("id", values: ids)
        HelixQuery.append(HelixQuery.item("status", status?.rawValue), to: &queryItems)
        HelixQuery.append(HelixQuery.item("sort", sort), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, validRange: 1...50)

        let response: HelixResponse<CustomRewardRedemption> = try await request(
            endpoint: "channel_points/custom_rewards/redemptions",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of custom reward redemptions.
    ///
    /// Get Custom Reward Redemption caps its page size below the usual Helix
    /// limit: `pageSize` may be between 1 and 50.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - rewardID: The custom reward whose redemptions are returned.
    ///   - ids: Optional redemption IDs. Twitch currently allows up to 50.
    ///   - status: Redemption status filter. Required when `ids` is empty.
    ///   - sort: Optional sort order (`OLDEST` or `NEWEST`).
    ///   - pageSize: Optional page size. Twitch currently allows up to 50 for redemptions.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Custom Reward Redemption](https://dev.twitch.tv/docs/api/reference/#get-custom-reward-redemption)
    public func customRewardRedemptions(
        broadcasterID: String,
        rewardID: String,
        ids: [String] = [],
        status: ChannelPointsRedemptionStatus? = nil,
        sort: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<CustomRewardRedemption> {
        HelixPagedSequence { cursor in
            try await fetchCustomRewardRedemptionsPage(
                broadcasterID: broadcasterID,
                rewardID: rewardID,
                ids: ids,
                status: status,
                sort: sort,
                first: pageSize,
                after: cursor
            )
        }
    }

    public func updateCustomRewardRedemptionStatus(
        broadcasterID: String,
        rewardID: String,
        redemptionIDs: [String],
        status: ChannelPointsRedemptionStatus
    ) async throws -> [CustomRewardRedemption] {
        guard !redemptionIDs.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "At least one redemption ID is required")
            )
        }
        guard redemptionIDs.count <= 50 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 50 redemption IDs")
            )
        }

        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "reward_id", value: rewardID)
        ]
        queryItems += HelixQuery.items("id", values: redemptionIDs)

        let response: HelixResponse<CustomRewardRedemption> = try await request(
            endpoint: "channel_points/custom_rewards/redemptions",
            method: "PATCH",
            queryItems: queryItems,
            body: try JSONEncoder.twitch().encode(["status": status.rawValue])
        )
        return response.data
    }
}

public struct CustomReward: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let id: String
    public let title: String
    public let prompt: String
    public let cost: Int
    public let image: CustomRewardImage?
    public let defaultImage: CustomRewardImage
    public let backgroundColor: String
    public let isEnabled: Bool
    public let isUserInputRequired: Bool
    public let maxPerStreamSetting: CustomRewardLimitSetting
    public let maxPerUserPerStreamSetting: CustomRewardLimitSetting
    public let globalCooldownSetting: CustomRewardCooldownSetting
    public let isPaused: Bool
    public let isInStock: Bool
    public let shouldRedemptionsSkipRequestQueue: Bool
    public let redemptionsRedeemedCurrentStream: Int?
    public let cooldownExpiresAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        broadcasterLogin: String,
        broadcasterName: String,
        id: String,
        title: String,
        prompt: String,
        cost: Int,
        image: CustomRewardImage? = nil,
        defaultImage: CustomRewardImage,
        backgroundColor: String,
        isEnabled: Bool,
        isUserInputRequired: Bool,
        maxPerStreamSetting: CustomRewardLimitSetting,
        maxPerUserPerStreamSetting: CustomRewardLimitSetting,
        globalCooldownSetting: CustomRewardCooldownSetting,
        isPaused: Bool,
        isInStock: Bool,
        shouldRedemptionsSkipRequestQueue: Bool,
        redemptionsRedeemedCurrentStream: Int? = nil,
        cooldownExpiresAt: Date? = nil
    ) {
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.id = id
        self.title = title
        self.prompt = prompt
        self.cost = cost
        self.image = image
        self.defaultImage = defaultImage
        self.backgroundColor = backgroundColor
        self.isEnabled = isEnabled
        self.isUserInputRequired = isUserInputRequired
        self.maxPerStreamSetting = maxPerStreamSetting
        self.maxPerUserPerStreamSetting = maxPerUserPerStreamSetting
        self.globalCooldownSetting = globalCooldownSetting
        self.isPaused = isPaused
        self.isInStock = isInStock
        self.shouldRedemptionsSkipRequestQueue = shouldRedemptionsSkipRequestQueue
        self.redemptionsRedeemedCurrentStream = redemptionsRedeemedCurrentStream
        self.cooldownExpiresAt = cooldownExpiresAt
    }
}

public struct CustomRewardImage: Decodable, Sendable, Equatable {
    // `.convertFromSnakeCase` turns the wire keys `url_1x`/`url_2x`/`url_4x` into
    // `url1X`/`url2X`/`url4X`, which match these property names — no CodingKeys needed.
    public let url1X: String
    public let url2X: String
    public let url4X: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        url1X: String,
        url2X: String,
        url4X: String
    ) {
        self.url1X = url1X
        self.url2X = url2X
        self.url4X = url4X
    }
}

public struct CustomRewardLimitSetting: Codable, Sendable, Equatable {
    public let isEnabled: Bool
    public let value: Int?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        isEnabled: Bool,
        value: Int? = nil
    ) {
        self.isEnabled = isEnabled
        self.value = value
    }

    // Twitch carries the limit under an endpoint-specific key (`max_per_stream` or
    // `max_per_user_per_stream`) depending on which setting this is, so accept either.
    enum CodingKeys: String, CodingKey {
        case isEnabled
        case value
        case maxPerStream
        case maxPerUserPerStream
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        value = try container.decodeIfPresent(Int.self, forKey: .maxPerStream)
            ?? container.decodeIfPresent(Int.self, forKey: .maxPerUserPerStream)
            ?? container.decodeIfPresent(Int.self, forKey: .value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(value, forKey: .value)
    }
}

public struct CustomRewardCooldownSetting: Codable, Sendable, Equatable {
    public let isEnabled: Bool
    public let globalCooldownSeconds: Int?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        isEnabled: Bool,
        globalCooldownSeconds: Int? = nil
    ) {
        self.isEnabled = isEnabled
        self.globalCooldownSeconds = globalCooldownSeconds
    }
}

public struct CustomRewardCreateRequest: Encodable, Sendable, Equatable {
    public let title: String
    public let cost: Int
    public let prompt: String?
    public let isEnabled: Bool?
    public let backgroundColor: String?
    public let isUserInputRequired: Bool?
    public let isMaxPerStreamEnabled: Bool?
    public let maxPerStream: Int?
    public let isMaxPerUserPerStreamEnabled: Bool?
    public let maxPerUserPerStream: Int?
    public let isGlobalCooldownEnabled: Bool?
    public let globalCooldownSeconds: Int?
    public let shouldRedemptionsSkipRequestQueue: Bool?

    public init(
        title: String,
        cost: Int,
        prompt: String? = nil,
        isEnabled: Bool? = nil,
        backgroundColor: String? = nil,
        isUserInputRequired: Bool? = nil,
        isMaxPerStreamEnabled: Bool? = nil,
        maxPerStream: Int? = nil,
        isMaxPerUserPerStreamEnabled: Bool? = nil,
        maxPerUserPerStream: Int? = nil,
        isGlobalCooldownEnabled: Bool? = nil,
        globalCooldownSeconds: Int? = nil,
        shouldRedemptionsSkipRequestQueue: Bool? = nil
    ) {
        self.title = title
        self.cost = cost
        self.prompt = prompt
        self.isEnabled = isEnabled
        self.backgroundColor = backgroundColor
        self.isUserInputRequired = isUserInputRequired
        self.isMaxPerStreamEnabled = isMaxPerStreamEnabled
        self.maxPerStream = maxPerStream
        self.isMaxPerUserPerStreamEnabled = isMaxPerUserPerStreamEnabled
        self.maxPerUserPerStream = maxPerUserPerStream
        self.isGlobalCooldownEnabled = isGlobalCooldownEnabled
        self.globalCooldownSeconds = globalCooldownSeconds
        self.shouldRedemptionsSkipRequestQueue = shouldRedemptionsSkipRequestQueue
    }
}

public struct CustomRewardUpdateRequest: Encodable, Sendable, Equatable {
    public let title: String?
    public let cost: Int?
    public let prompt: String?
    public let isEnabled: Bool?
    public let backgroundColor: String?
    public let isUserInputRequired: Bool?
    public let isMaxPerStreamEnabled: Bool?
    public let maxPerStream: Int?
    public let isMaxPerUserPerStreamEnabled: Bool?
    public let maxPerUserPerStream: Int?
    public let isGlobalCooldownEnabled: Bool?
    public let globalCooldownSeconds: Int?
    public let isPaused: Bool?
    public let shouldRedemptionsSkipRequestQueue: Bool?

    public init(
        title: String? = nil,
        cost: Int? = nil,
        prompt: String? = nil,
        isEnabled: Bool? = nil,
        backgroundColor: String? = nil,
        isUserInputRequired: Bool? = nil,
        isMaxPerStreamEnabled: Bool? = nil,
        maxPerStream: Int? = nil,
        isMaxPerUserPerStreamEnabled: Bool? = nil,
        maxPerUserPerStream: Int? = nil,
        isGlobalCooldownEnabled: Bool? = nil,
        globalCooldownSeconds: Int? = nil,
        isPaused: Bool? = nil,
        shouldRedemptionsSkipRequestQueue: Bool? = nil
    ) {
        self.title = title
        self.cost = cost
        self.prompt = prompt
        self.isEnabled = isEnabled
        self.backgroundColor = backgroundColor
        self.isUserInputRequired = isUserInputRequired
        self.isMaxPerStreamEnabled = isMaxPerStreamEnabled
        self.maxPerStream = maxPerStream
        self.isMaxPerUserPerStreamEnabled = isMaxPerUserPerStreamEnabled
        self.maxPerUserPerStream = maxPerUserPerStream
        self.isGlobalCooldownEnabled = isGlobalCooldownEnabled
        self.globalCooldownSeconds = globalCooldownSeconds
        self.isPaused = isPaused
        self.shouldRedemptionsSkipRequestQueue = shouldRedemptionsSkipRequestQueue
    }
}

public struct CustomRewardRedemption: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let id: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let userInput: String
    public let status: ChannelPointsRedemptionStatus
    public let redeemedAt: Date
    public let reward: RedemptionReward

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterId: String,
        broadcasterLogin: String,
        broadcasterName: String,
        id: String,
        userId: String,
        userLogin: String,
        userName: String,
        userInput: String,
        status: ChannelPointsRedemptionStatus,
        redeemedAt: Date,
        reward: RedemptionReward
    ) {
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.id = id
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.userInput = userInput
        self.status = status
        self.redeemedAt = redeemedAt
        self.reward = reward
    }

    public struct RedemptionReward: Decodable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let prompt: String
        public let cost: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            id: String,
            title: String,
            prompt: String,
            cost: Int
        ) {
            self.id = id
            self.title = title
            self.prompt = prompt
            self.cost = cost
        }
    }
}
