import Foundation
import XCTest
@testable import TwitchKit

/// Deleting one message and clearing the whole chat are separate calls, so a
/// missing message ID can't clear a channel's chat.
final class ChatDeletionTests: XCTestCase {
    private func makeAPI(_ transport: MockHTTPClient) -> HelixClient {
        HelixClient(
            tokenProvider: TwitchTokenProvider(
                oauthClient: TwitchOAuthClient(clientID: "client"),
                tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
            ),
            clientID: "client",
            httpClient: transport
        )
    }

    func testDeleteChatMessageSendsTheMessageID() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 204, body: "")])
        let api = makeAPI(transport)

        try await api.deleteChatMessage(broadcasterID: "b", moderatorID: "m", messageID: "msg-1")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/chat?broadcaster_id=b&moderator_id=m&message_id=msg-1"
        )
    }

    func testClearChatSendsNoMessageID() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 204, body: "")])
        let api = makeAPI(transport)

        try await api.clearChat(broadcasterID: "b", moderatorID: "m")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/chat?broadcaster_id=b&moderator_id=m"
        )
    }

    func testEmptyMessageIDIsRejectedWithoutCallingTwitch() async throws {
        let transport = MockHTTPClient(responses: [])
        let api = makeAPI(transport)

        do {
            try await api.deleteChatMessage(broadcasterID: "b", moderatorID: "m", messageID: "")
            XCTFail("Expected badRequest")
        } catch HelixError.badRequest {
            // Expected.
        }

        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty, "an empty message ID must never reach Twitch, which would clear the chat")
    }

    @available(*, deprecated)
    func testDeprecatedDeleteChatMessagesForwards() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: ""),
            .json(statusCode: 204, body: ""),
        ])
        let api = makeAPI(transport)

        try await api.deleteChatMessages(broadcasterID: "b", moderatorID: "m", messageID: "msg-1")
        try await api.deleteChatMessages(broadcasterID: "b", moderatorID: "m")

        let urls = await transport.recordedRequests().map { $0.url?.absoluteString }
        XCTAssertEqual(urls, [
            "https://api.twitch.tv/helix/moderation/chat?broadcaster_id=b&moderator_id=m&message_id=msg-1",
            "https://api.twitch.tv/helix/moderation/chat?broadcaster_id=b&moderator_id=m",
        ])
    }
}
