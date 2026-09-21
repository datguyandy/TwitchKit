import Foundation

extension HelixClient {
    /// Gets analytics report URLs for extensions.
    public func fetchExtensionAnalyticsPage(
        extensionID: String? = nil,
        type: AnalyticsReportType? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<AnalyticsReport> {
        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("extension_id", extensionID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("type", type?.rawValue), to: &queryItems)
        HelixQuery.append(startedAt.map { URLQueryItem(name: "started_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        HelixQuery.append(endedAt.map { URLQueryItem(name: "ended_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<AnalyticsReport> = try await request(
            endpoint: "analytics/extensions",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Gets analytics report URLs for games.
    public func fetchGameAnalyticsPage(
        gameID: String? = nil,
        type: AnalyticsReportType? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<AnalyticsReport> {
        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("type", type?.rawValue), to: &queryItems)
        HelixQuery.append(startedAt.map { URLQueryItem(name: "started_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        HelixQuery.append(endedAt.map { URLQueryItem(name: "ended_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<AnalyticsReport> = try await request(
            endpoint: "analytics/games",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Gets the Bits leaderboard for the authenticated broadcaster.
    public func fetchBitsLeaderboard(
        count: Int? = nil,
        period: BitsLeaderboardPeriod? = nil,
        startedAt: Date? = nil,
        userID: String? = nil
    ) async throws -> BitsLeaderboard {
        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("count", count.map(String.init)), to: &queryItems)
        HelixQuery.append(HelixQuery.item("period", period?.rawValue), to: &queryItems)
        HelixQuery.append(startedAt.map { URLQueryItem(name: "started_at", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)

        let data = try await requestRawData(
            endpoint: "bits/leaderboard",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return try JSONDecoder.twitch().decode(BitsLeaderboard.self, from: data)
    }

    /// Gets Cheermotes that users can use to cheer Bits.
    public func fetchCheermotes(broadcasterID: String? = nil) async throws -> [Cheermote] {
        let queryItems = broadcasterID.map { [URLQueryItem(name: "broadcaster_id", value: $0)] }
        let response: HelixResponse<Cheermote> = try await request(endpoint: "bits/cheermotes", queryItems: queryItems)
        return response.data
    }

    /// Gets custom Power-ups created by a broadcaster.
    public func fetchCustomPowerUps(broadcasterID: String, ids: [String] = []) async throws -> [CustomPowerUp] {
        guard ids.count <= 50 else {
            throw HelixError.badRequest(.fallback(status: 400, message: "Twitch allows up to 50 custom Power-up IDs"))
        }
        let response: HelixResponse<CustomPowerUp> = try await request(
            endpoint: "bits/custom_power_ups",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)] + HelixQuery.items("id", values: ids)
        )
        return response.data
    }

    /// Gets one page of extension Bits transactions.
    public func fetchExtensionTransactionsPage(
        extensionID: String,
        ids: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<ExtensionTransaction> {
        var queryItems = [URLQueryItem(name: "extension_id", value: extensionID)]
        queryItems += HelixQuery.items("id", values: ids)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<ExtensionTransaction> = try await request(
            endpoint: "extensions/transactions",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of extension Bits transactions.
    ///
    /// - Parameters:
    ///   - extensionID: The extension whose transactions are returned.
    ///   - ids: Optional transaction IDs. Twitch currently allows up to 100.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Extension Transactions](https://dev.twitch.tv/docs/api/reference/#get-extension-transactions)
    public func extensionTransactions(
        extensionID: String,
        ids: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<ExtensionTransaction> {
        var queryItems = [URLQueryItem(name: "extension_id", value: extensionID)]
        queryItems += HelixQuery.items("id", values: ids)
        return pagedRequest(endpoint: "extensions/transactions", queryItems: queryItems, pageSize: pageSize)
    }

}

public enum AnalyticsReportType: String, Sendable, Equatable {
    case overview
}

public struct AnalyticsReport: Decodable, Sendable, Equatable {
    public let extensionId: String?
    public let gameId: String?
    public let url: String
    public let type: String
    public let dateRange: DateRange

    public struct DateRange: Decodable, Sendable, Equatable {
        public let startedAt: Date
        public let endedAt: Date
    }
}

public enum BitsLeaderboardPeriod: String, Sendable, Equatable {
    case day
    case week
    case month
    case year
    case all
}

public struct BitsLeaderboard: Decodable, Sendable, Equatable {
    public let data: [Entry]
    public let dateRange: AnalyticsReport.DateRange
    public let total: Int

    public struct Entry: Decodable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let rank: Int
        public let score: Int
    }
}

public struct Cheermote: Decodable, Sendable, Equatable {
    public let prefix: String
    public let tiers: [Tier]
    public let type: String
    public let order: Int
    public let lastUpdated: Date
    public let isCharitable: Bool

    public struct Tier: Decodable, Sendable, Equatable {
        public let minBits: Int
        public let id: String
        public let color: String
        public let images: Images
        public let canCheer: Bool
        public let showInBitsCard: Bool
    }

    public struct Images: Decodable, Sendable, Equatable {
        public let dark: Theme
        public let light: Theme
    }

    public struct Theme: Decodable, Sendable, Equatable {
        public let animated: ImageScales
        public let staticImage: ImageScales

        enum CodingKeys: String, CodingKey {
            case animated
            case staticImage = "static"
        }
    }

    public struct ImageScales: Decodable, Sendable, Equatable {
        public let scale1: String?
        public let scale15: String?
        public let scale2: String?
        public let scale3: String?
        public let scale4: String?

        enum CodingKeys: String, CodingKey {
            case scale1 = "1"
            case scale15 = "1.5"
            case scale2 = "2"
            case scale3 = "3"
            case scale4 = "4"
        }
    }
}

public struct CustomPowerUp: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let bits: Int
    public let title: String
    public let prompt: String
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
    public let redemptionsRedeemedCurrentStream: Int?
    public let cooldownExpiresAt: Date?

    @available(*, deprecated, renamed: "bits")
    public var cost: Int { bits }
}

public struct ExtensionTransaction: Decodable, Sendable, Equatable {
    public let id: String
    public let timestamp: Date
    public let broadcasterId: String
    public let broadcasterLogin: String?
    public let broadcasterName: String?
    public let userId: String
    public let userLogin: String?
    public let userName: String?
    public let productType: String
    public let productData: ProductData

    public struct ProductData: Decodable, Sendable, Equatable {
        public let sku: String
        public let cost: Cost
        public let displayName: String
        public let inDevelopment: Bool?
        public let expiration: String?
        public let broadcast: Bool?
    }

    public struct Cost: Decodable, Sendable, Equatable {
        public let amount: Int
        public let type: String
    }
}
