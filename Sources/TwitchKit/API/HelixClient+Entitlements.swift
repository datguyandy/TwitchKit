import Foundation

extension HelixClient {
    /// Gets one page of Drops entitlements for an organization/game/user filter.
    public func fetchDropsEntitlementsPage(
        ids: [String] = [],
        userID: String? = nil,
        gameID: String? = nil,
        fulfillmentStatus: DropsEntitlementFulfillmentStatus? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<DropsEntitlement> {
        var queryItems = HelixQuery.items("id", values: ids)
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("fulfillment_status", fulfillmentStatus?.rawValue), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<DropsEntitlement> = try await request(
            endpoint: "entitlements/drops",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Returns an async sequence of Drops entitlements for an organization/game/user filter.
    ///
    /// - Parameters:
    ///   - ids: Optional entitlement IDs. Twitch currently allows up to 100.
    ///   - userID: Optional user ID filter.
    ///   - gameID: Optional game ID filter.
    ///   - fulfillmentStatus: Optional fulfillment status filter.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Drops Entitlements](https://dev.twitch.tv/docs/api/reference/#get-drops-entitlements)
    public func dropsEntitlements(
        ids: [String] = [],
        userID: String? = nil,
        gameID: String? = nil,
        fulfillmentStatus: DropsEntitlementFulfillmentStatus? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<DropsEntitlement> {
        HelixPagedSequence { cursor in
            try await fetchDropsEntitlementsPage(
                ids: ids,
                userID: userID,
                gameID: gameID,
                fulfillmentStatus: fulfillmentStatus,
                first: pageSize,
                after: cursor
            )
        }
    }

    /// Updates Drops entitlement fulfillment status.
    public func updateDropsEntitlements(
        entitlementIDs: [String],
        fulfillmentStatus: DropsEntitlementFulfillmentStatus
    ) async throws -> [DropsEntitlementUpdateResult] {
        guard entitlementIDs.count <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "Twitch allows up to 100 entitlement IDs")
            )
        }

        let response: HelixResponse<DropsEntitlementUpdateResult> = try await request(
            endpoint: "entitlements/drops",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(DropsEntitlementUpdateRequest(
                entitlementIds: entitlementIDs,
                fulfillmentStatus: fulfillmentStatus.rawValue
            ))
        )
        return response.data
    }
}

private struct DropsEntitlementUpdateRequest: Encodable {
    let entitlementIds: [String]
    let fulfillmentStatus: String
}

public struct DropsEntitlement: Decodable, Sendable, Equatable {
    public let id: String
    public let benefitId: String
    public let timestamp: Date
    public let userId: String
    public let gameId: String
    public let fulfillmentStatus: DropsEntitlementFulfillmentStatus
    public let lastUpdated: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        benefitId: String,
        timestamp: Date,
        userId: String,
        gameId: String,
        fulfillmentStatus: DropsEntitlementFulfillmentStatus,
        lastUpdated: Date
    ) {
        self.id = id
        self.benefitId = benefitId
        self.timestamp = timestamp
        self.userId = userId
        self.gameId = gameId
        self.fulfillmentStatus = fulfillmentStatus
        self.lastUpdated = lastUpdated
    }
}

public struct DropsEntitlementUpdateResult: Decodable, Sendable, Equatable {
    public let status: DropsEntitlementUpdateStatus
    public let ids: [String]

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        status: DropsEntitlementUpdateStatus,
        ids: [String]
    ) {
        self.status = status
        self.ids = ids
    }
}
