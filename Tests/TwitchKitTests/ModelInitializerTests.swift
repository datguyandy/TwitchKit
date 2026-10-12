import Foundation
import XCTest
@testable import TwitchKit

/// Response models can be built directly, for test fixtures and SwiftUI previews,
/// without decoding JSON.
final class ModelInitializerTests: XCTestCase {
    func testOptionalFieldsDefaultToNil() {
        let user = TwitchUser(
            id: "1",
            login: "twitchdev",
            displayName: "TwitchDev",
            profileImageUrl: "https://example.com/p.png",
            broadcasterType: "partner"
        )

        XCTAssertEqual(user.id, "1")
        XCTAssertNil(user.email)
        XCTAssertNil(user.createdAt)
    }

    func testCodableModelRoundTripsThroughTwitchJSON() throws {
        let user = TwitchUser(
            id: "1",
            login: "twitchdev",
            displayName: "TwitchDev",
            profileImageUrl: "https://example.com/p.png",
            email: "dev@example.com",
            broadcasterType: "partner",
            description: "Hello",
            offlineImageUrl: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder.twitch().encode(user)
        let decoded = try JSONDecoder.twitch().decode(TwitchUser.self, from: data)

        XCTAssertEqual(decoded, user)
    }

    func testBuildsAPreviewPage() {
        let stream = TwitchStream(
            id: "s1",
            userId: "1",
            userLogin: "twitchdev",
            userName: "TwitchDev",
            gameId: "509658",
            gameName: "Just Chatting",
            type: .live,
            title: "Building TwitchKit",
            tags: ["English"],
            viewerCount: 42,
            startedAt: .now,
            language: "en",
            thumbnailUrl: "https://example.com/{width}x{height}.jpg",
            isMature: false
        )
        let page = HelixPage(data: [stream], pagination: Pagination(cursor: nil))

        XCTAssertEqual(page.data.first?.viewerCount, 42)
        XCTAssertNil(page.nextCursor)
    }

    func testBuildsModelsWithCustomDecoding() {
        let ban = BanUserResponse(broadcasterId: "b", moderatorId: "m", userId: "u", createdAt: .now)
        let leaderboard = BitsLeaderboard(
            data: [BitsLeaderboard.Entry(userId: "1", userLogin: "a", userName: "A", rank: 1, score: 100)],
            dateRange: BitsLeaderboard.DateRange(),
            total: 1
        )

        XCTAssertFalse(ban.isTimeout)
        XCTAssertNil(leaderboard.dateRange.startedAt)
        XCTAssertEqual(leaderboard.data.first?.score, 100)
    }
}
