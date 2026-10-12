import Foundation
import XCTest
@testable import TwitchKit

/// Statuses without a dedicated `HelixError` case keep their status and
/// Twitch's message instead of reading as a server error.
final class UnexpectedStatusTests: XCTestCase {
    private func makeAPI(_ transport: MockHTTPClient) -> HelixClient {
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

    func testGoneKeepsStatusAndTwitchMessage() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 410, body: #"{"error":"Gone","status":410,"message":"The tags API has been removed"}"#),
        ])

        do {
            _ = try await makeAPI(transport).fetchUser()
            XCTFail("Expected unexpectedStatus")
        } catch HelixError.unexpectedStatus(let status, let apiError) {
            XCTAssertEqual(status, 410)
            XCTAssertEqual(apiError?.message, "The tags API has been removed")
            XCTAssertEqual(
                HelixError.unexpectedStatus(status: status, apiError).errorDescription,
                "Unexpected HTTP 410: The tags API has been removed"
            )
        }
    }

    func testUnexpectedStatusWithoutBody() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 405, body: "")])

        do {
            _ = try await makeAPI(transport).fetchUser()
            XCTFail("Expected unexpectedStatus")
        } catch HelixError.unexpectedStatus(let status, let apiError) {
            XCTAssertEqual(status, 405)
            XCTAssertNil(apiError)
        }
    }

    func testFiveHundredsAreStillServerErrors() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 502, body: "")])

        do {
            _ = try await makeAPI(transport).fetchUser()
            XCTFail("Expected serverError")
        } catch HelixError.serverError(let status) {
            XCTAssertEqual(status, 502)
        }
    }
}
