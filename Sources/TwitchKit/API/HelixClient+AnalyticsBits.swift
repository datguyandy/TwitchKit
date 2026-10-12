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
        // Bits Leaderboard has no paginated `data` envelope of its own, so it
        // bypasses `request(...)`; keep decode failures inside `HelixError`.
        do {
            return try JSONDecoder.twitch().decode(BitsLeaderboard.self, from: data)
        } catch {
            throw HelixError.decodingFailed(String(describing: error))
        }
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
    /// The overview report. Twitch documents this as the only valid report type.
    case overviewV2 = "overview_v2"

    /// The retired v1 overview report; Twitch rejects this value.
    @available(*, deprecated, renamed: "overviewV2", message: "Twitch only accepts overview_v2")
    case overview
}

public struct AnalyticsReport: Decodable, Sendable, Equatable {
    public let extensionId: String?
    public let gameId: String?
    public let url: String
    public let type: String
    public let dateRange: DateRange

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        extensionId: String? = nil,
        gameId: String? = nil,
        url: String,
        type: String,
        dateRange: DateRange
    ) {
        self.extensionId = extensionId
        self.gameId = gameId
        self.url = url
        self.type = type
        self.dateRange = dateRange
    }

    public struct DateRange: Decodable, Sendable, Equatable {
        public let startedAt: Date
        public let endedAt: Date

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            startedAt: Date,
            endedAt: Date
        ) {
            self.startedAt = startedAt
            self.endedAt = endedAt
        }
    }

    private enum CodingKeys: String, CodingKey {
        case extensionId, gameId, type, dateRange
        // Twitch sends the download link as uppercase `URL`, which
        // `.convertFromSnakeCase` leaves untouched, so a synthesized `url`
        // key never matches. Accept a lowercase `url` as well.
        case uppercaseURL = "URL"
        case url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extensionId = try container.decodeIfPresent(String.self, forKey: .extensionId)
        gameId = try container.decodeIfPresent(String.self, forKey: .gameId)
        url = try container.decodeIfPresent(String.self, forKey: .uppercaseURL)
            ?? container.decode(String.self, forKey: .url)
        type = try container.decode(String.self, forKey: .type)
        dateRange = try container.decode(DateRange.self, forKey: .dateRange)
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
    public let dateRange: DateRange
    public let total: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        data: [Entry],
        dateRange: DateRange,
        total: Int
    ) {
        self.data = data
        self.dateRange = dateRange
        self.total = total
    }

    /// The leaderboard's reporting window.
    ///
    /// Twitch sends empty strings for both dates when the request omits
    /// `started_at` (for example `period: .all`, or no arguments at all), so
    /// both dates are optional.
    public struct DateRange: Decodable, Sendable, Equatable {
        public let startedAt: Date?
        public let endedAt: Date?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            startedAt: Date? = nil,
            endedAt: Date? = nil
        ) {
            self.startedAt = startedAt
            self.endedAt = endedAt
        }

        private enum CodingKeys: String, CodingKey {
            case startedAt, endedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
                .flatMap(TwitchDateParser.date(from:))
            endedAt = try container.decodeIfPresent(String.self, forKey: .endedAt)
                .flatMap(TwitchDateParser.date(from:))
        }
    }

    public struct Entry: Decodable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let rank: Int
        public let score: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            rank: Int,
            score: Int
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.rank = rank
            self.score = score
        }
    }
}

public struct Cheermote: Decodable, Sendable, Equatable {
    public let prefix: String
    public let tiers: [Tier]
    public let type: String
    public let order: Int
    public let lastUpdated: Date
    public let isCharitable: Bool

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        prefix: String,
        tiers: [Tier],
        type: String,
        order: Int,
        lastUpdated: Date,
        isCharitable: Bool
    ) {
        self.prefix = prefix
        self.tiers = tiers
        self.type = type
        self.order = order
        self.lastUpdated = lastUpdated
        self.isCharitable = isCharitable
    }

    public struct Tier: Decodable, Sendable, Equatable {
        public let minBits: Int
        public let id: String
        public let color: String
        public let images: Images
        public let canCheer: Bool
        public let showInBitsCard: Bool

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            minBits: Int,
            id: String,
            color: String,
            images: Images,
            canCheer: Bool,
            showInBitsCard: Bool
        ) {
            self.minBits = minBits
            self.id = id
            self.color = color
            self.images = images
            self.canCheer = canCheer
            self.showInBitsCard = showInBitsCard
        }
    }

    public struct Images: Decodable, Sendable, Equatable {
        public let dark: Theme
        public let light: Theme

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            dark: Theme,
            light: Theme
        ) {
            self.dark = dark
            self.light = light
        }
    }

    public struct Theme: Decodable, Sendable, Equatable {
        public let animated: ImageScales
        public let staticImage: ImageScales

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            animated: ImageScales,
            staticImage: ImageScales
        ) {
            self.animated = animated
            self.staticImage = staticImage
        }

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

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            scale1: String? = nil,
            scale15: String? = nil,
            scale2: String? = nil,
            scale3: String? = nil,
            scale4: String? = nil
        ) {
            self.scale1 = scale1
            self.scale15 = scale15
            self.scale2 = scale2
            self.scale3 = scale3
            self.scale4 = scale4
        }

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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterId: String,
        broadcasterLogin: String,
        broadcasterName: String,
        bits: Int,
        title: String,
        prompt: String,
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
        redemptionsRedeemedCurrentStream: Int? = nil,
        cooldownExpiresAt: Date? = nil,
        cost: Int { bits }
    ) {
        self.id = id
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.bits = bits
        self.title = title
        self.prompt = prompt
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
        self.redemptionsRedeemedCurrentStream = redemptionsRedeemedCurrentStream
        self.cooldownExpiresAt = cooldownExpiresAt
        self.cost = cost
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        timestamp: Date,
        broadcasterId: String,
        broadcasterLogin: String? = nil,
        broadcasterName: String? = nil,
        userId: String,
        userLogin: String? = nil,
        userName: String? = nil,
        productType: String,
        productData: ProductData
    ) {
        self.id = id
        self.timestamp = timestamp
        self.broadcasterId = broadcasterId
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.productType = productType
        self.productData = productData
    }

    public struct ProductData: Decodable, Sendable, Equatable {
        public let sku: String
        public let cost: Cost
        public let displayName: String
        public let inDevelopment: Bool?
        public let expiration: String?
        public let broadcast: Bool?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            sku: String,
            cost: Cost,
            displayName: String,
            inDevelopment: Bool? = nil,
            expiration: String? = nil,
            broadcast: Bool? = nil
        ) {
            self.sku = sku
            self.cost = cost
            self.displayName = displayName
            self.inDevelopment = inDevelopment
            self.expiration = expiration
            self.broadcast = broadcast
        }
    }

    public struct Cost: Decodable, Sendable, Equatable {
        public let amount: Int
        public let type: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            amount: Int,
            type: String
        ) {
            self.amount = amount
            self.type = type
        }
    }
}
