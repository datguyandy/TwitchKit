import Foundation
import XCTest
@testable import TwitchKit

final class CurrentAPICompatibilityTests: XCTestCase {
    private func api(_ transport: MockHTTPClient) -> HelixClient {
        HelixClient(tokenProvider: TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientID: "client"),
            tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "test-token"))
        ), clientID: "client", httpClient: transport)
    }

    func testGIFAndLegacyFragmentsDecode() throws {
        let fragments = try JSONDecoder.twitch().decode([ChatFragment].self, from: Data(#"[{"type":"gif","text":"hello","gif":{"gif_id":"g1","url":"https://example.com/g.gif"}},{"type":"text","text":"hello"},{"type":"future","text":"future"}]"#.utf8))
        XCTAssertEqual(fragments[0].type, .gif)
        XCTAssertEqual(fragments[0].gif?.gifID, "g1")
        XCTAssertEqual(fragments[0].gif?.url, "https://example.com/g.gif")
        XCTAssertNil(fragments[1].gif)
        XCTAssertEqual(fragments[2].type, .unknown("future"))
    }

    func testStreamOfflineAcceptsBothPayloadVersions() throws {
        for id in ["", #", "id":"stream-1""#] {
            let json = #"{"broadcaster_user_id":"1","broadcaster_user_login":"one","broadcaster_user_name":"One""# + id + "}"
            let event = try JSONDecoder.twitch().decode(EventSubStreamOffline.self, from: Data(json.utf8))
            XCTAssertEqual(event.id, id.isEmpty ? nil : "stream-1")
        }
    }

    func testBlockedLinkPreservesTermDetails() throws {
        let json = ##"""
        {
          "broadcaster_user_id": "1",
          "broadcaster_user_login": "one",
          "broadcaster_user_name": "One",
          "user_id": "2",
          "user_login": "two",
          "user_name": "Two",
          "message_id": "m",
          "message": {
            "text": "blocked.example",
            "fragments": []
          },
          "reason": "blocked_link",
          "blocked_term": {
            "terms_found": [
              {
                "term_id": "t",
                "boundary": {
                  "start_pos": 0,
                  "end_pos": 14
                },
                "owner_broadcaster_user_id": "1",
                "owner_broadcaster_user_login": "one",
                "owner_broadcaster_user_name": "One"
              }
            ]
          }
        }
        """##
        let event = try JSONDecoder.twitch().decode(EventSubAutoModMessage.self, from: Data(json.utf8))
        XCTAssertEqual(event.reason, "blocked_link")
        XCTAssertEqual(event.blockedTerm?.termsFound.first?.boundary.endPos, 14)
        XCTAssertNil(event.automod)
    }

    func testNewChatNoticesPreserveMilestoneDetails() throws {
        let json = ##"""
        {
          "broadcaster_user_id": "1",
          "broadcaster_user_login": "one",
          "broadcaster_user_name": "One",
          "chatter_user_id": "2",
          "chatter_user_login": "two",
          "chatter_user_name": "Two",
          "badges": [],
          "system_message": "milestone",
          "message_id": "m",
          "message": {
            "text": "",
            "fragments": []
          },
          "notice_type": "modiversary",
          "modiversary": {
            "months": 12
          },
          "shared_chat_modiversary": {
            "months": 6
          },
          "watch_streak": {
            "streak_count": 5,
            "channel_points_awarded": 100
          },
          "is_source_only": true
        }
        """##
        let event = try JSONDecoder.twitch().decode(EventSubChatNotification.self, from: Data(json.utf8))
        XCTAssertEqual(event.modiversary?.months, 12)
        XCTAssertEqual(event.sharedChatModiversary?.months, 6)
        XCTAssertEqual(event.watchStreak?.channelPointsAwarded, 100)
        XCTAssertEqual(event.isSourceOnly, true)
    }

    func testCustomPowerUpsUseDocumentedRouteAndPayload() async throws {
        let body = ##"""
        {
          "data": [
            {
              "id": "reward",
              "broadcaster_id": "b",
              "broadcaster_login": "b",
              "broadcaster_name": "B",
              "bits": 100,
              "title": "Effect",
              "prompt": "",
              "image": null,
              "default_image": {
                "url_1x": "one",
                "url_2x": "two",
                "url_4x": "four"
              },
              "background_color": "#000000",
              "is_enabled": true,
              "is_user_input_required": false,
              "max_per_stream_setting": {
                "is_enabled": true,
                "max_per_stream": 5
              },
              "max_per_user_per_stream_setting": {
                "is_enabled": false,
                "max_per_user_per_stream": 0
              },
              "global_cooldown_setting": {
                "is_enabled": false,
                "global_cooldown_seconds": 0
              },
              "is_paused": false,
              "is_in_stock": true,
              "redemptions_redeemed_current_stream": null,
              "cooldown_expires_at": null
            }
          ]
        }
        """##
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: body)])
        let rewards = try await api(transport).fetchCustomPowerUps(broadcasterID: "b", ids: ["reward", "other"])
        XCTAssertEqual(rewards.first?.bits, 100)
        XCTAssertEqual(rewards.first?.defaultImage.url1X, "one")
        XCTAssertEqual(rewards.first?.maxPerStreamSetting.value, 5)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.twitch.tv/helix/bits/custom_power_ups?broadcaster_id=b&id=reward&id=other")
        XCTAssertEqual(EventSubSubscription.ChannelPoints.customPowerUpRedemptionAdd(broadcasterID: "b").version, "1")
    }

    func testCustomPowerUpRedemptionDecodesDocumentedPayload() throws {
        let json = ##"""
        {
          "id": "redemption",
          "broadcaster_user_id": "1",
          "broadcaster_user_login": "one",
          "broadcaster_user_name": "One",
          "user_id": "2",
          "user_login": "two",
          "user_name": "Two",
          "user_input": "hello",
          "status": "unfulfilled",
          "custom_power_up": {
            "id": "reward",
            "title": "Effect",
            "bits": 100,
            "prompt": ""
          },
          "redeemed_at": "2026-09-21T00:00:00Z"
        }
        """##
        let event = try JSONDecoder.twitch().decode(EventSubCustomPowerUpRedemption.self, from: Data(json.utf8))
        XCTAssertEqual(event.customPowerUp.bits, 100)
        XCTAssertEqual(event.status, .unfulfilled)
        XCTAssertEqual(event.userInput, "hello")
    }

    func testPinnedChatRoutesAndEmptyResponse() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 204, body: ""), .json(statusCode: 204, body: ""), .json(statusCode: 204, body: "")
        ])
        let client = api(transport)
        let pinned = try await client.fetchPinnedChatMessage(broadcasterID: "b", moderatorID: "m")
        XCTAssertNil(pinned)
        try await client.pinChatMessage(broadcasterID: "b", moderatorID: "m", messageID: "msg", durationSeconds: 30)
        try await client.updatePinnedChatMessage(broadcasterID: "b", moderatorID: "m", messageID: "msg", durationSeconds: 1800)
        try await client.unpinChatMessage(broadcasterID: "b", moderatorID: "m", messageID: "msg")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "PUT", "PATCH", "DELETE"])
        XCTAssertTrue(requests.allSatisfy { $0.url?.path == "/helix/chat/pins" })
        XCTAssertEqual(requests[1].url?.query, "broadcaster_id=b&moderator_id=m&message_id=msg&duration_seconds=30")
        XCTAssertEqual(requests[2].url?.query, "broadcaster_id=b&moderator_id=m&message_id=msg&duration_seconds=1800")
    }

    func testSendPinAnnouncementAndClipOptions() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"message_id":"msg","is_sent":true}]}"#),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 202, body: #"{"data":[{"id":"clip","edit_url":"https://example.com"}]}"#)
        ])
        let client = api(transport)
        _ = try await client.sendChatMessage(broadcasterID: "b", senderID: "s", message: "hello", pin: true)
        try await client.sendChatAnnouncement(broadcasterID: "b", moderatorID: "m", message: "hello", forSourceOnly: true)
        _ = try await client.createClip(broadcasterID: "b", title: "A clip", duration: 5.5)
        let requests = await transport.recordedRequests()
        let pin = try JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: Any]
        let announcement = try JSONSerialization.jsonObject(with: XCTUnwrap(requests[1].httpBody)) as? [String: Any]
        XCTAssertEqual(pin?["pin"] as? Bool, true)
        XCTAssertEqual(announcement?["for_source_only"] as? Bool, true)
        XCTAssertEqual(requests[2].url?.query, "broadcaster_id=b&title=A%20clip&duration=5.5")
    }

    func testInvalidParametersDoNotSendRequests() async throws {
        let transport = MockHTTPClient(responses: [])
        let client = api(transport)
        do {
            try await client.pinChatMessage(broadcasterID: "b", moderatorID: "m", messageID: "msg", durationSeconds: 29)
            XCTFail("Expected invalid duration")
        } catch HelixError.badRequest { }
        do {
            _ = try await client.sendChatMessage(broadcasterID: "b", senderID: "s", message: "hello", forSourceOnly: false, pin: true)
            XCTFail("Expected incompatible parameters")
        } catch HelixError.badRequest { }
        for duration in [Double.nan, .infinity, 4.9, 60.1, 5.55] {
            do {
                _ = try await client.createClip(broadcasterID: "b", duration: duration)
                XCTFail("Expected invalid duration")
            } catch HelixError.badRequest { }
            do {
                _ = try await client.createClipFromVOD(broadcasterID: "b", editorID: "e", vodID: "v", vodOffset: 10, title: "Clip", duration: duration)
                XCTFail("Expected invalid VOD duration")
            } catch HelixError.badRequest { }
        }
        do {
            _ = try await client.fetchCustomPowerUps(broadcasterID: "b", ids: Array(repeating: "id", count: 51))
            XCTFail("Expected too many IDs")
        } catch HelixError.badRequest { }
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testAuthorizationUsesAppRouteAndDocumentedFields() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 200, body: #"{"data":[{"user_id":"1","user_name":"One","user_login":"one","scopes":[],"has_authorized":false}]}"#)])
        let users = try await api(transport).fetchAuthorizations(userIDs: ["1", "2"])
        XCTAssertEqual(users.first?.hasAuthorized, false)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.twitch.tv/helix/authorization/users?user_id=1&user_id=2")
    }

    func testValidationOutageDoesNotRefreshOrDeleteToken() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 503, body: "")])
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "old", refreshToken: "refresh"))
        let provider = TwitchTokenProvider(oauthClient: TwitchOAuthClient(clientID: "client", httpClient: transport), tokenStore: store)
        do {
            try await provider.validateToken()
            XCTFail("Expected server error")
        } catch HelixError.serverError(let status) { XCTAssertEqual(status, 503) }
        let requests = await transport.recordedRequests()
        let token = try await store.loadToken()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(token?.accessToken, "old")
    }

    func testOAuthTransportCancellationRemainsCancellation() async throws {
        let transport = MockHTTPClient(responses: [.failure(URLError(.cancelled))])
        let oauth = TwitchOAuthClient(clientID: "client", httpClient: transport)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await oauth.validateAccessToken("token")
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
    }

    func testRefreshServerErrorWithoutJSONStatusPreservesToken() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 503, body: #"{"error":"temporarily_unavailable"}"#)])
        let store = InMemoryTokenStore(token: OAuthToken(accessToken: "old", refreshToken: "refresh"))
        let provider = TwitchTokenProvider(oauthClient: TwitchOAuthClient(clientID: "client", httpClient: transport), tokenStore: store)
        do {
            try await provider.refreshIfNeeded()
            XCTFail("Expected OAuth error")
        } catch HelixError.oauth(let error) { XCTAssertEqual(error.status, 503) }
        let token = try await store.loadToken()
        XCTAssertEqual(token?.accessToken, "old")
    }

    func testRefreshCannotUndoLogoutOrReplaceNewLogin() async throws {
        for replacement in [false, true] {
            for status in [200, 401] {
                let gate = ResponseGate()
                let transport = MockHTTPClient(responses: [.gatedJSON(gate: gate, statusCode: status, body: status == 200 ? #"{"access_token":"stale-refresh","refresh_token":"r2"}"# : #"{"status":401,"message":"invalid refresh token"}"#)])
                let store = InMemoryTokenStore(token: OAuthToken(accessToken: "old", refreshToken: "r1"))
                let provider = TwitchTokenProvider(oauthClient: TwitchOAuthClient(clientID: "client", httpClient: transport), tokenStore: store)
                let refresh = Task { try await provider.refreshIfNeeded() }
                for _ in 0..<1000 {
                    if !(await transport.recordedRequests()).isEmpty { break }
                    try await Task.sleep(for: .milliseconds(1))
                }
                let requests = await transport.recordedRequests()
                XCTAssertEqual(requests.count, 1)
                if replacement { try await provider.setToken(OAuthToken(accessToken: "new-login")) }
                else { try await provider.logout() }
                await gate.open()
                _ = await refresh.result
                let stored = try await store.loadToken()
                XCTAssertEqual(stored?.accessToken, replacement ? "new-login" : nil)
                let authenticated = await provider.isAuthenticated()
                XCTAssertEqual(authenticated, replacement)
            }
        }
    }
}
