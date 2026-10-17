import Foundation
import XCTest
@testable import TwitchKit

/// The pre-rename argument labels must keep compiling and forward to the new
/// declarations. Marked deprecated so calling the old spellings doesn't warn.
final class DeprecatedLabelTests: XCTestCase {
    @available(*, deprecated)
    func testOldClientLabelsStillBuildClients() {
        let client = TwitchClient(clientID: "client-id", tokenStore: InMemoryTokenStore())
        XCTAssertEqual(client.clientID, "client-id")
        XCTAssertEqual(client.clientID, "client-id")

        let auth = TwitchAuth(clientID: "client-id", redirectURI: "myapp://oauth")
        let url = auth.implicitGrantURL(scopes: [.userReadChat])
        XCTAssertTrue(url.absoluteString.contains("redirect_uri=myapp://oauth"), url.absoluteString)
        XCTAssertEqual(TwitchAuth.redirectURI, TwitchAuth.redirectURI)
    }

    @available(*, deprecated)
    func testOldRequestInitializerLabelsForward() {
        XCTAssertEqual(ChannelInfoUpdate(gameID: "509658").gameID, "509658")
        XCTAssertEqual(PollCreateRequest(broadcasterID: "b", title: "Q", choices: [], duration: 60).broadcasterID, "b")
        XCTAssertEqual(AutoModMessage(msgID: "m", msgText: "t").msgID, "m")
    }

    func testDefaultedInitializersAreNotAmbiguous() {
        // Only the new initializers match when the renamed parameter is omitted.
        XCTAssertNil(ChannelInfoUpdate(title: "Title").gameID)
        XCTAssertNil(ChannelStreamScheduleSegmentUpdate(title: "Stream").categoryID)
    }

    @available(*, deprecated)
    func testOldIsLiveLabelStillBuildsClients() {
        let api = HelixClient(
            tokenProvider: TwitchTokenProvider(
                oauthClient: TwitchOAuthClient(clientID: "client"),
                tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
            ),
            clientID: "client",
            httpClient: MockHTTPClient(responses: [])
        )
        let eventSub = EventSubClient(api: api, isLive: { true }, pathMonitor: MockNetworkPathMonitor())
        XCTAssertEqual(eventSub.currentConnectionState, .disconnected)

        let client = TwitchClient(
            clientID: "client-id",
            tokenStore: InMemoryTokenStore(),
            isLive: { true },
            pathMonitor: MockNetworkPathMonitor()
        )
        XCTAssertEqual(client.clientID, "client-id")

        let oldClient = TwitchClient(
            clientID: "client-id",
            tokenStore: InMemoryTokenStore(),
            isLive: { true },
            pathMonitor: MockNetworkPathMonitor()
        )
        XCTAssertEqual(oldClient.clientID, "client-id")
    }

    func testShouldKeepReconnectingDefaultIsNotAmbiguous() {
        // Omitting the reconnect closure matches only the new initializer.
        let client = TwitchClient(clientID: "client-id", tokenStore: InMemoryTokenStore(), pathMonitor: MockNetworkPathMonitor())
        XCTAssertEqual(client.clientID, "client-id")
    }

    @available(*, deprecated)
    func testOldMethodLabelsForward() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"message_id":"m1","is_sent":true}]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
        ])
        let api = HelixClient(
            tokenProvider: TwitchTokenProvider(
                oauthClient: TwitchOAuthClient(clientID: "client"),
                tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "token"))
            ),
            clientID: "client",
            httpClient: transport
        )

        let sent = try await api.sendChatMessage(broadcasterID: "b", senderID: "s", message: "hi")
        let stream = try await api.fetchStream(forUserID: "u")
        // The old spelling keeps its original contract: a missing channel throws.
        do {
            _ = try await api.fetchChannelInfo(forBroadcasterID: "deleted")
            XCTFail("Expected notFound")
        } catch HelixError.notFound {
            // Expected.
        }

        XCTAssertTrue(sent.isSent)
        XCTAssertNil(stream)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map { $0.value(forHTTPHeaderField: "Client-Id") }, ["client", "client", "client"])
        XCTAssertEqual(requests[1].url?.absoluteString, "https://api.twitch.tv/helix/streams?user_id=u&first=1")
    }
}
