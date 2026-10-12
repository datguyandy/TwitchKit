import Foundation

extension HelixClient {
    /// Gets the broadcaster's active charity campaign.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: The active charity campaign, or `nil` if no campaign is active.
    /// - SeeAlso: [Get Charity Campaign](https://dev.twitch.tv/docs/api/reference/#get-charity-campaign)
    public func fetchCharityCampaign(broadcasterID broadcasterId: String) async throws -> CharityCampaign? {
        let response: HelixResponse<CharityCampaign> = try await request(
            endpoint: "charity/campaigns",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data.first
    }

    /// Gets one page of charity campaign donations.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of donations.
    /// - SeeAlso: [Get Charity Campaign Donations](https://dev.twitch.tv/docs/api/reference/#get-charity-campaign-donations)
    public func fetchCharityCampaignDonationsPage(
        broadcasterID broadcasterId: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<CharityDonation> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<CharityDonation> = try await request(
            endpoint: "charity/donations",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of charity campaign donations.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Charity Campaign Donations](https://dev.twitch.tv/docs/api/reference/#get-charity-campaign-donations)
    public func charityCampaignDonations(
        broadcasterID broadcasterId: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<CharityDonation> {
        pagedRequest(
            endpoint: "charity/donations",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)],
            pageSize: pageSize
        )
    }
}

public struct CharityCampaign: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let charityName: String
    public let charityDescription: String
    public let charityLogo: String
    public let charityWebsite: String
    public let currentAmount: CharityAmount
    public let targetAmount: CharityAmount
}

public struct CharityDonation: Decodable, Sendable, Equatable {
    public let id: String
    public let campaignId: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let amount: CharityAmount
}

public struct CharityAmount: Decodable, Sendable, Equatable {
    public let value: Int
    public let decimalPlaces: Int
    public let currency: String
}
