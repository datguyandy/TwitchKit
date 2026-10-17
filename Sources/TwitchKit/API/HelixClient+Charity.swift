import Foundation

extension HelixClient {
    /// Gets the broadcaster's active charity campaign.
    ///
    /// - Parameter broadcasterID: The broadcaster's user ID.
    /// - Returns: The active charity campaign, or `nil` if no campaign is active.
    /// - SeeAlso: [Get Charity Campaign](https://dev.twitch.tv/docs/api/reference/#get-charity-campaign)
    public func fetchCharityCampaign(broadcasterID: String) async throws -> CharityCampaign? {
        let response: HelixResponse<CharityCampaign> = try await request(
            endpoint: "charity/campaigns",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        return response.data.first
    }

    /// Gets one page of charity campaign donations.
    ///
    /// - Parameters:
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of donations.
    /// - SeeAlso: [Get Charity Campaign Donations](https://dev.twitch.tv/docs/api/reference/#get-charity-campaign-donations)
    public func fetchCharityCampaignDonationsPage(
        broadcasterID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<CharityDonation> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
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
    ///   - broadcasterID: The broadcaster's user ID.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Charity Campaign Donations](https://dev.twitch.tv/docs/api/reference/#get-charity-campaign-donations)
    public func charityCampaignDonations(
        broadcasterID: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<CharityDonation> {
        pagedRequest(
            endpoint: "charity/donations",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            pageSize: pageSize
        )
    }
}

public struct CharityCampaign: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterID: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let charityName: String
    public let charityDescription: String
    public let charityLogo: String
    public let charityWebsite: String
    public let currentAmount: CharityAmount
    public let targetAmount: CharityAmount

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterID: String,
        broadcasterLogin: String,
        broadcasterName: String,
        charityName: String,
        charityDescription: String,
        charityLogo: String,
        charityWebsite: String,
        currentAmount: CharityAmount,
        targetAmount: CharityAmount
    ) {
        self.id = id
        self.broadcasterID = broadcasterID
        self.broadcasterLogin = broadcasterLogin
        self.broadcasterName = broadcasterName
        self.charityName = charityName
        self.charityDescription = charityDescription
        self.charityLogo = charityLogo
        self.charityWebsite = charityWebsite
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
    }
}

public struct CharityDonation: Decodable, Sendable, Equatable {
    public let id: String
    public let campaignID: String
    public let userID: String
    public let userLogin: String
    public let userName: String
    public let amount: CharityAmount

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        campaignID: String,
        userID: String,
        userLogin: String,
        userName: String,
        amount: CharityAmount
    ) {
        self.id = id
        self.campaignID = campaignID
        self.userID = userID
        self.userLogin = userLogin
        self.userName = userName
        self.amount = amount
    }
}

public struct CharityAmount: Decodable, Sendable, Equatable {
    public let value: Int
    public let decimalPlaces: Int
    public let currency: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        value: Int,
        decimalPlaces: Int,
        currency: String
    ) {
        self.value = value
        self.decimalPlaces = decimalPlaces
        self.currency = currency
    }
}
