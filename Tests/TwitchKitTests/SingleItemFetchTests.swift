import Foundation
import XCTest
@testable import TwitchKit

/// Lookups that can legitimately find nothing return `nil`; reads that always
/// have a result and writes throw `.emptyResponse` on empty data; `.notFound`
/// is reserved for HTTP 404.
final class SingleItemFetchTests: XCTestCase {
    private static let emptyData = #"{"data":[]}"#

    private func api(_ transport: MockHTTPClient) -> HelixClient {
        HelixClient(
            tokenProvider: TwitchTokenProvider(
                oauthClient: TwitchOAuthClient(clientID: "client"),
                tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
            ),
            clientID: "client",
            httpClient: transport,
            retryPolicy: .never
        )
    }

    func testLookupsReturnNilWhenNothingMatches() async throws {
        let transport = MockHTTPClient(responses: Array(repeating: .json(statusCode: 200, body: Self.emptyData), count: 5))
        let api = api(transport)

        let userByID = try await api.fetchUser(id: "deleted")
        let userByLogin = try await api.fetchUser(login: "nobody")
        let gameByID = try await api.fetchGame(id: "0")
        let gameByName = try await api.fetchGame(name: "Not A Game")
        let channel = try await api.fetchChannelInfo(broadcasterID: "deleted")

        XCTAssertNil(userByID)
        XCTAssertNil(userByLogin)
        XCTAssertNil(gameByID)
        XCTAssertNil(gameByName)
        XCTAssertNil(channel)
    }

    func testReadThatAlwaysHasAResultThrowsEmptyResponse() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: Self.emptyData),
            .json(statusCode: 200, body: Self.emptyData),
        ])
        let api = api(transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected emptyResponse")
        } catch HelixError.emptyResponse {
            // Expected: the token's own user always exists.
        }
        do {
            _ = try await api.fetchChatSettings(broadcasterID: "b")
            XCTFail("Expected emptyResponse")
        } catch HelixError.emptyResponse {
            // Expected.
        }
    }

    func testWriteWithEmptyDataThrowsEmptyResponse() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: Self.emptyData)])

        do {
            _ = try await api(transport).createPoll(
                PollCreateRequest(broadcasterID: "b", title: "Q", choices: [PollChoice(title: "A")], duration: 60)
            )
            XCTFail("Expected emptyResponse")
        } catch HelixError.emptyResponse {
            // Expected.
        }
    }

    func testHTTP404StillThrowsNotFound() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 404, body: #"{"error":"Not Found","status":404,"message":"not found"}"#),
        ])

        do {
            _ = try await api(transport).fetchChatSettings(broadcasterID: "b")
            XCTFail("Expected notFound")
        } catch HelixError.notFound {
            // Expected.
        }
    }

    func testEmptyResponseDescription() {
        XCTAssertEqual(HelixError.emptyResponse.errorDescription, "Twitch returned a successful response without the expected data")
    }
}
