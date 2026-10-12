import Foundation
import XCTest
@testable import TwitchKit

/// The pre-rename argument labels must keep compiling and forward to the new
/// declarations. Marked deprecated so calling the old spellings doesn't warn.
final class DeprecatedLabelTests: XCTestCase {
    @available(*, deprecated)
    func testOldClientLabelsStillBuildClients() {
        let client = TwitchClient(clientId: "client-id", tokenStore: InMemoryTokenStore())
        XCTAssertEqual(client.clientId, "client-id")
        XCTAssertEqual(client.clientID, "client-id")

        let auth = TwitchAuth(clientId: "client-id", redirectUri: "myapp://oauth")
        let url = auth.implicitGrantURL(scopes: [.userReadChat])
        XCTAssertTrue(url.absoluteString.contains("redirect_uri=myapp://oauth"), url.absoluteString)
        XCTAssertEqual(TwitchAuth.redirectUri, TwitchAuth.redirectURI)
    }

    @available(*, deprecated)
    func testOldRequestInitializerLabelsForward() {
        XCTAssertEqual(ChannelInfoUpdate(gameId: "509658").gameId, "509658")
        XCTAssertEqual(PollCreateRequest(broadcasterId: "b", title: "Q", choices: [], duration: 60).broadcasterId, "b")
        XCTAssertEqual(AutoModMessage(msgId: "m", msgText: "t").msgId, "m")
    }

    func testDefaultedInitializersAreNotAmbiguous() {
        // Only the new initializers match when the renamed parameter is omitted.
        XCTAssertNil(ChannelInfoUpdate(title: "Title").gameId)
        XCTAssertNil(ChannelStreamScheduleSegmentUpdate(title: "Stream").categoryId)
    }

    @available(*, deprecated)
    func testOldMethodLabelsForward() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"message_id":"m1","is_sent":true}]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
        ])
        let api = HelixClient(
            tokenProvider: TwitchTokenProvider(
                oauthClient: TwitchOAuthClient(clientId: "client"),
                tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
            ),
            clientId: "client",
            httpClient: transport
        )

        let sent = try await api.sendChatMessage(broadcasterId: "b", senderId: "s", message: "hi")
        let stream = try await api.fetchStream(forUserID: "u")

        XCTAssertTrue(sent.isSent)
        XCTAssertNil(stream)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map { $0.value(forHTTPHeaderField: "Client-Id") }, ["client", "client"])
        XCTAssertEqual(requests.last?.url?.absoluteString, "https://api.twitch.tv/helix/streams?user_id=u&first=1")
    }
}
