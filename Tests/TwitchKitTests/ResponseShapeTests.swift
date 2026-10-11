import Foundation
import XCTest
@testable import TwitchKit

/// Decodes Twitch's documented example responses for endpoints whose models
/// previously didn't match the real response shape, and checks request
/// encoding details that Twitch's servers are sensitive to.
final class ResponseShapeTests: XCTestCase {
    private func api(_ transport: MockHTTPClient) -> HelixClient {
        HelixClient(tokenProvider: TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientId: "client"),
            tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "test-token"))
        ), clientId: "client", httpClient: transport)
    }

    // MARK: - Check User Subscription

    func testCheckUserSubscriptionDecodesDocumentedResponse() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [
            {
              "broadcaster_id": "149747285",
              "broadcaster_name": "TwitchPresents",
              "broadcaster_login": "twitchpresents",
              "is_gift": false,
              "tier": "1000"
            }
          ]
        }
        """)])

        let subscription = try await api(transport).checkUserSubscription(broadcasterID: "149747285", userID: "141981764")

        let unwrapped = try XCTUnwrap(subscription)
        XCTAssertEqual(unwrapped.broadcasterId, "149747285")
        XCTAssertEqual(unwrapped.broadcasterLogin, "twitchpresents")
        XCTAssertEqual(unwrapped.broadcasterName, "TwitchPresents")
        XCTAssertFalse(unwrapped.isGift)
        XCTAssertNil(unwrapped.gifterId)
        XCTAssertEqual(unwrapped.tier, .tier1)

        let request = try await firstRequest(transport)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/subscriptions/user?broadcaster_id=149747285&user_id=141981764"
        )
    }

    func testCheckUserSubscriptionDecodesGifter() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [
            {
              "broadcaster_id": "1",
              "broadcaster_name": "One",
              "broadcaster_login": "one",
              "is_gift": true,
              "gifter_id": "2",
              "gifter_login": "two",
              "gifter_name": "Two",
              "tier": "2000"
            }
          ]
        }
        """)])

        let subscription = try await api(transport).checkUserSubscription(broadcasterID: "1", userID: "3")

        XCTAssertEqual(subscription?.isGift, true)
        XCTAssertEqual(subscription?.gifterId, "2")
        XCTAssertEqual(subscription?.gifterLogin, "two")
        XCTAssertEqual(subscription?.gifterName, "Two")
        XCTAssertEqual(subscription?.tier, .tier2)
    }

    func testCheckUserSubscriptionReturnsNilWhenNotSubscribed() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 404, body: """
        {"error":"Not Found","status":404,"message":"twitchpresents has no subscription to twitchdev"}
        """)])

        let subscription = try await api(transport).checkUserSubscription(broadcasterID: "1", userID: "2")

        XCTAssertNil(subscription)
    }

    // MARK: - Ban User

    func testBanUserDecodesPermanentBan() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [
            {
              "broadcaster_id": "1234",
              "moderator_id": "5678",
              "user_id": "9876",
              "created_at": "2021-09-28T18:22:31Z",
              "end_time": null
            }
          ]
        }
        """)])

        let ban = try await api(transport).banUser(
            broadcasterID: "1234",
            moderatorID: "5678",
            userID: "9876",
            reason: "no reason"
        )

        XCTAssertEqual(ban.broadcasterId, "1234")
        XCTAssertEqual(ban.moderatorId, "5678")
        XCTAssertEqual(ban.userId, "9876")
        XCTAssertEqual(ban.createdAt, TwitchDateParser.date(from: "2021-09-28T18:22:31Z"))
        XCTAssertNil(ban.endTime)
        XCTAssertFalse(ban.isTimeout)
    }

    func testBanUserDecodesTimeout() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [
            {
              "broadcaster_id": "1234",
              "moderator_id": "5678",
              "user_id": "9876",
              "created_at": "2021-09-28T19:27:31Z",
              "end_time": "2021-09-28T19:22:31Z"
            }
          ]
        }
        """)])

        let ban = try await api(transport).banUser(
            broadcasterID: "1234",
            moderatorID: "5678",
            userID: "9876",
            duration: 300
        )

        XCTAssertEqual(ban.endTime, TwitchDateParser.date(from: "2021-09-28T19:22:31Z"))
        XCTAssertTrue(ban.isTimeout)
    }

    // MARK: - Delete Videos

    func testDeleteVideosDecodesStringArray() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: #"{"data":["1234","9876"]}"#)])

        let deleted = try await api(transport).deleteVideos(ids: ["1234", "9876"])

        XCTAssertEqual(deleted, ["1234", "9876"])
        let request = try await firstRequest(transport)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/videos?id=1234&id=9876")
    }

    // MARK: - Query encoding

    func testPlusInQueryValuesIsPercentEncoded() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: #"{"data":[],"pagination":{}}"#)])

        _ = try await api(transport).fetchSearchCategoriesPage(query: "C++", after: "abc+def")

        let request = try await firstRequest(transport)
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.absoluteString, "https://api.twitch.tv/helix/search/categories?query=C%2B%2B&after=abc%2Bdef")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first { $0.name == "query" }?.value, "C++")
        XCTAssertEqual(components.queryItems?.first { $0.name == "after" }?.value, "abc+def")
    }

    func testPositiveUTCOffsetIsPercentEncoded() async throws {
        let transport = MockHTTPClient(responses: [.failure(MockError())])

        _ = try? await api(transport).fetchChannelStreamSchedulePage(forBroadcasterID: "1", utcOffset: "+05:30")

        let request = try await firstRequest(transport)
        let url = try XCTUnwrap(request.url)
        XCTAssertTrue(url.absoluteString.contains("utc_offset=%2B05:30"), url.absoluteString)
    }

    func testAuthorizationURLPercentEncodesPlusInState() throws {
        let client = TwitchOAuthClient(clientId: "client")

        let url = client.implicitGrantURL(scopes: [.userReadChat], state: "a+b")

        XCTAssertTrue(url.absoluteString.contains("state=a%2Bb"), url.absoluteString)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first { $0.name == "state" }?.value, "a+b")
    }

    // MARK: - Bits leaderboard and analytics

    func testBitsLeaderboardWithoutStartDateDecodesEmptyDates() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [
            {"user_id": "158010205", "user_login": "tundracowboy", "user_name": "TundraCowboy", "rank": 1, "score": 12543}
          ],
          "date_range": {"started_at": "", "ended_at": ""},
          "total": 1
        }
        """)])

        let leaderboard = try await api(transport).fetchBitsLeaderboard()

        XCTAssertEqual(leaderboard.data.first?.score, 12543)
        XCTAssertNil(leaderboard.dateRange.startedAt)
        XCTAssertNil(leaderboard.dateRange.endedAt)
        XCTAssertEqual(leaderboard.total, 1)
    }

    func testBitsLeaderboardDecodesDocumentedDateRange() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [],
          "date_range": {"started_at": "2018-02-05T08:00:00Z", "ended_at": "2018-02-12T08:00:00Z"},
          "total": 0
        }
        """)])

        let leaderboard = try await api(transport).fetchBitsLeaderboard(
            count: 2,
            period: .week,
            startedAt: TwitchDateParser.date(from: "2018-02-05T08:00:00Z")
        )

        XCTAssertEqual(leaderboard.dateRange.startedAt, TwitchDateParser.date(from: "2018-02-05T08:00:00Z"))
        XCTAssertEqual(leaderboard.dateRange.endedAt, TwitchDateParser.date(from: "2018-02-12T08:00:00Z"))
    }

    func testBitsLeaderboardDecodeFailureIsHelixError() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: #"{"data":"unexpected"}"#)])

        do {
            _ = try await api(transport).fetchBitsLeaderboard()
            XCTFail("Expected decoding failure")
        } catch HelixError.decodingFailed {
            // Expected.
        }
    }

    func testAnalyticsReportDecodesUppercaseURLAndSendsOverviewV2() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: """
        {
          "data": [
            {
              "game_id": "493057",
              "URL": "https://twitch-piper-reports.s3-us-west-2.amazonaws.com/games/66170/overview/15183",
              "type": "overview_v2",
              "date_range": {"started_at": "2018-01-01T00:00:00Z", "ended_at": "2018-03-01T00:00:00Z"}
            }
          ],
          "pagination": {}
        }
        """)])

        let page = try await api(transport).fetchGameAnalyticsPage(gameID: "493057", type: .overviewV2)

        XCTAssertEqual(page.data.first?.gameId, "493057")
        XCTAssertEqual(page.data.first?.url, "https://twitch-piper-reports.s3-us-west-2.amazonaws.com/games/66170/overview/15183")
        XCTAssertEqual(page.data.first?.type, "overview_v2")
        XCTAssertNil(page.nextCursor)
        let request = try await firstRequest(transport)
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.absoluteString, "https://api.twitch.tv/helix/analytics/games?game_id=493057&type=overview_v2")
    }

    // MARK: - Pagination

    func testEmptyCursorDecodesAsNoNextPage() throws {
        let pagination = try JSONDecoder.twitch().decode(Pagination.self, from: Data(#"{"cursor":""}"#.utf8))

        XCTAssertNil(pagination.cursor)
        XCTAssertNil(Pagination(cursor: "").cursor)
    }

    func testPagedSequenceStopsOnEmptyCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"id":"1","name":"One","box_art_url":"","igdb_id":""}],"pagination":{"cursor":""}}"#),
        ])

        var names: [String] = []
        for try await game in api(transport).searchCategories(query: "one") {
            names.append(game.name)
        }

        XCTAssertEqual(names, ["One"])
        let requestCount = await transport.recordedRequests().count
        XCTAssertEqual(requestCount, 1)
    }

    func testPagedSequenceStopsWhenCursorRepeats() async throws {
        let counter = PageCounter()
        let sequence = HelixPagedSequence<Int>(startingAfter: "same") { _ in
            let page = await counter.next()
            return HelixPage(data: [page], pagination: Pagination(cursor: "same"))
        }

        var values: [Int] = []
        for try await value in sequence {
            values.append(value)
        }

        XCTAssertEqual(values, [1])
    }
}

private struct MockError: Error, Sendable {}

private func firstRequest(_ transport: MockHTTPClient) async throws -> URLRequest {
    let requests = await transport.recordedRequests()
    return try XCTUnwrap(requests.first)
}

private actor PageCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}
