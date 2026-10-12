import Foundation
import XCTest
@testable import TwitchKit

final class HTTPClientTests: XCTestCase {
    func test_fetchUserSendsAuthorizationAndClientHeaders() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/users")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Client-Id"), "client-id")
    }

    func test_helixRequestUsesConfiguredTimeout() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(
            auth: auth,
            clientID: "client-id",
            httpClient: transport,
            requestConfiguration: HelixRequestConfiguration(timeoutInterval: 12)
        )

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.timeoutInterval, 12)
    }

    func test_helixRequestPreservesCancellation() async throws {
        let transport = MockHTTPClient(responses: [.cancellation])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func test_fetchUsersUsesRepeatedIdAndLoginQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                },
                {
                  "id": "2",
                  "login": "anotherdev",
                  "display_name": "AnotherDev",
                  "profile_image_url": "https://example.com/profile2.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let users = try await api.fetchUsers(ids: ["1"], logins: ["anotherdev"])

        XCTAssertEqual(users.map(\.login), ["twitchdev", "anotherdev"])

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/users?id=1&login=anotherdev"
        )
    }

    func test_fetchUserByLoginReturnsFirstMatch() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let fetchedUser = try await api.fetchUser(login: "twitchdev")
        let user = try XCTUnwrap(fetchedUser)

        XCTAssertEqual(user.id, "1")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.twitch.tv/helix/users?login=twitchdev")
    }

    func test_fetchUsersRequiresAtLeastOneIdentifier() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchUsers()
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "At least one user ID or login is required")
        }
    }

    func test_fetchStreamsPageUsesFilterAndPaginationQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "stream-1",
                  "user_id": "1",
                  "user_login": "twitchdev",
                  "user_name": "TwitchDev",
                  "game_id": "493057",
                  "game_name": "PUBG: BATTLEGROUNDS",
                  "type": "live",
                  "title": "Building TwitchKit",
                  "tags": ["Swift"],
                  "viewer_count": 42,
                  "started_at": "2024-01-01T00:00:00Z",
                  "language": "en",
                  "thumbnail_url": "https://example.com/{width}x{height}.jpg",
                  "is_mature": false
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchStreamsPage(
            userIDs: ["1"],
            gameIDs: ["493057"],
            languages: ["en"],
            type: .live,
            first: 25,
            after: "cursor",
            before: "previous-cursor"
        )

        XCTAssertEqual(page.data.first?.userLogin, "twitchdev")
        XCTAssertEqual(page.nextCursor, "next-cursor")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/streams?user_id=1&game_id=493057&language=en&type=live&first=25&after=cursor&before=previous-cursor"
        )
    }

    func test_fetchStreamForOfflineUserReturnsNil() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let stream = try await api.fetchStream(userID: "offline-user")

        XCTAssertNil(stream)
    }

    func test_fetchGamesUsesRepeatedIdentifierQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "493057",
                  "name": "PUBG: BATTLEGROUNDS",
                  "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/493057-{width}x{height}.jpg",
                  "igdb_id": "27789"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let games = try await api.fetchGames(ids: ["493057"], names: ["Just Chatting"], igdbIDs: ["27789"])

        XCTAssertEqual(games.first?.name, "PUBG: BATTLEGROUNDS")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/games?id=493057&name=Just%20Chatting&igdb_id=27789"
        )
    }

    func test_fetchTopGamesPageUsesPaginationQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "493057",
                  "name": "PUBG: BATTLEGROUNDS",
                  "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/493057-{width}x{height}.jpg",
                  "igdb_id": "27789"
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchTopGamesPage(first: 10, after: "cursor")

        XCTAssertEqual(page.data.first?.id, "493057")
        XCTAssertEqual(page.nextCursor, "next-cursor")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/games/top?first=10&after=cursor"
        )
    }

    func test_sendChatMessageEncodesTypedRequestBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "message_id": "message-1",
                  "is_sent": true
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let result = try await api.sendChatMessage(
            broadcasterID: "broadcaster-id",
            senderID: "sender-id",
            message: "Hello from TwitchKit",
            replyParentMessageID: "parent-message-id",
            forSourceOnly: true
        )

        XCTAssertEqual(result.messageId, "message-1")
        XCTAssertTrue(result.isSent)

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/chat/messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(object["broadcaster_id"] as? String, "broadcaster-id")
        XCTAssertEqual(object["sender_id"] as? String, "sender-id")
        XCTAssertEqual(object["message"] as? String, "Hello from TwitchKit")
        XCTAssertEqual(object["reply_parent_message_id"] as? String, "parent-message-id")
        XCTAssertEqual(object["for_source_only"] as? Bool, true)
        XCTAssertNil(object["pin"])
    }

    func test_sendChatMessageReturnsDropReasonWhenMessageIsNotSent() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "message_id": "",
                  "is_sent": false,
                  "drop_reason": {
                    "code": "automod_held",
                    "message": "Your message has been held for review by AutoMod."
                  }
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let result = try await api.sendChatMessage(
            broadcasterID: "broadcaster-id",
            senderID: "sender-id",
            message: "Held message"
        )

        XCTAssertFalse(result.isSent)
        XCTAssertEqual(result.dropReason?.code, "automod_held")
    }

    func test_fetchChattersPageUsesBroadcasterModeratorAndPagination() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "1", "user_login": "viewer", "user_name": "Viewer" }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchChattersPage(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            first: 50,
            after: "cursor"
        )

        XCTAssertEqual(page.data.first?.userLogin, "viewer")
        let request = try await firstRecordedRequest(from: transport)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/chatters?broadcaster_id=broadcaster&moderator_id=moderator&first=50&after=cursor"
        )
    }

    func test_updateChatSettingsEncodesOnlyProvidedFields() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "broadcaster",
                  "emote_mode": false,
                  "follower_mode": true,
                  "follower_mode_duration": 10,
                  "slow_mode": true,
                  "slow_mode_wait_time": 30,
                  "subscriber_mode": false,
                  "unique_chat_mode": false
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.updateChatSettings(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            with: ChatSettingsUpdate(slowMode: true, slowModeWaitTime: 30)
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/settings?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(object["slow_mode"] as? Bool, true)
        XCTAssertEqual(object["slow_mode_wait_time"] as? Int, 30)
        XCTAssertNil(object["subscriber_mode"])
    }

    func test_sendAnnouncementUsesQueryParametersAndJSONBody() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 204, body: "")])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        try await api.sendChatAnnouncement(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            message: "hello",
            color: .purple
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/announcements?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(object["message"] as? String, "hello")
        XCTAssertEqual(object["color"] as? String, "purple")
    }

    func test_banUserEncodesNestedDataBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "broadcaster",
                  "moderator_id": "moderator",
                  "user_id": "target",
                  "created_at": "2025-01-01T00:00:00Z",
                  "end_time": "2025-01-01T00:01:00Z"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.banUser(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            userID: "target",
            duration: 60,
            reason: "test"
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(data["user_id"] as? String, "target")
        XCTAssertEqual(data["duration"] as? Int, 60)
        XCTAssertEqual(data["reason"] as? String, "test")
    }

    func test_fetchModeratorsPageUsesRepeatedUserIDs() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "1", "user_login": "mod", "user_name": "Mod" }
              ],
              "pagination": {}
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchModeratorsPage(broadcasterID: "broadcaster", userIDs: ["1", "2"])

        let request = try await firstRecordedRequest(from: transport)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/moderators?broadcaster_id=broadcaster&user_id=1&user_id=2"
        )
    }

    func test_warnChatUserEncodesNestedDataBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "broadcaster",
                  "user_id": "target",
                  "moderator_id": "moderator",
                  "reason": "stop"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.warnChatUser(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            userID: "target",
            reason: "stop"
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [String: Any])
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/warnings?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(data["user_id"] as? String, "target")
        XCTAssertEqual(data["reason"] as? String, "stop")
    }

    func test_fetchUserRefreshesTokenAndRetriesOnceAfterUnauthorized() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"access_token":"refreshed-token","refresh_token":"next-refresh","expires_in":3600,"token_type":"bearer"}"#),
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """),
        ])
        let auth = makeAuth(clientSecret: "secret", httpClient: transport)
        try await auth.setToken(OAuthToken(accessToken: "expired-token", refreshToken: "refresh-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
        XCTAssertEqual(requests[1].url?.absoluteString, "https://id.twitch.tv/oauth2/token")
        XCTAssertEqual(String(data: requests[1].httpBody ?? Data(), encoding: .utf8)?.contains("grant_type=refresh_token"), true)
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
    }

    func test_authorizationCodeExchangeUsesInjectedHTTPClient() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"access_token":"access-token","refresh_token":"refresh-token","expires_in":3600,"token_type":"bearer"}"#)
        ])
        let auth = makeAuth(clientSecret: "secret", httpClient: transport)

        try await auth.authenticate(withAuthorizationCode: "auth-code")

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(request.url?.absoluteString, "https://id.twitch.tv/oauth2/token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(body?.contains("grant_type=authorization_code"), true)
        XCTAssertEqual(body?.contains("code=auth-code"), true)
        XCTAssertEqual(body?.contains("client_secret=secret"), true)
    }

    func test_authorizationCodeExchangePreservesOAuthErrorBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"error":"invalid_grant","error_description":"Invalid authorization code"}"#)
        ])
        let auth = makeAuth(clientSecret: "secret", httpClient: transport)

        do {
            try await auth.authenticate(withAuthorizationCode: "bad-code")
            XCTFail("Expected OAuth error")
        } catch let error as HelixError {
            guard case .oauth(let oauthError) = error else {
                return XCTFail("Expected oauth error, got \(error)")
            }
            XCTAssertEqual(oauthError.error, "invalid_grant")
            XCTAssertEqual(oauthError.message, "Invalid authorization code")
            XCTAssertEqual(oauthError.errorDescription, "Invalid authorization code")
        }
    }

    func test_pollDeviceCodeWaitsThroughPendingStateAndReturnsToken() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 400, body: #"{"error":"authorization_pending","error_description":"Still waiting"}"#),
            .json(statusCode: 200, body: #"{"access_token":"device-token","refresh_token":"refresh-token","expires_in":3600,"token_type":"bearer"}"#),
        ])
        let oauthClient = TwitchOAuthClient(clientID: "client-id", httpClient: transport)

        let token = try await oauthClient.pollDeviceCode(
            deviceCode: "device-code",
            rawScopes: ["user:read:email"],
            interval: 0,
            expiresIn: 60
        )

        XCTAssertEqual(token.accessToken, "device-token")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(String(data: requests[0].httpBody ?? Data(), encoding: .utf8)?.contains("device_code=device-code"), true)
    }

    func test_nonHTTPResponseThrowsInvalidResponseInsteadOfCrashing() async throws {
        let transport = MockHTTPClient(responses: [
            .nonHTTP(body: Data())
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected invalid response")
        } catch let error as HelixError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    func test_rateLimitPreservesRateLimitHeaders() async throws {
        let resetAt = Date.now.addingTimeInterval(30)
        let resetEpoch = Int(resetAt.timeIntervalSince1970)
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 429,
                body: #"{"error":"Too Many Requests","status":429,"message":"Rate limit exceeded"}"#,
                headers: [
                    "Ratelimit-Limit": "800",
                    "Ratelimit-Remaining": "0",
                    "Ratelimit-Reset": "\(resetEpoch)",
                    "Retry-After": "17",
                ]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        // Retries disabled: this test checks how the 429 is surfaced.
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport, retryPolicy: .never)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected rate limit error")
        } catch let error as HelixError {
            guard case .rateLimited(let rateLimit) = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
            XCTAssertEqual(rateLimit.limit, 800)
            XCTAssertEqual(rateLimit.remaining, 0)
            XCTAssertEqual(rateLimit.resetAt, Date(timeIntervalSince1970: TimeInterval(resetEpoch)))
            XCTAssertEqual(rateLimit.retryAfter, 17)
            XCTAssertEqual(rateLimit.recommendedRetryDelay, 17)
        }
    }

    func test_rateLimitFallsBackToResetHeaderForRetryDelay() async throws {
        let resetAt = Date.now.addingTimeInterval(30)
        let resetEpoch = Int(resetAt.timeIntervalSince1970)
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 429,
                body: #"{"error":"Too Many Requests","status":429,"message":"Rate limit exceeded"}"#,
                headers: ["Ratelimit-Reset": "\(resetEpoch)"]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        // Retries disabled: this test checks how the 429 is surfaced.
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport, retryPolicy: .never)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected rate limit error")
        } catch let error as HelixError {
            guard case .rateLimited(let rateLimit) = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
            XCTAssertEqual(rateLimit.retryAfter, nil)
            XCTAssertNotNil(rateLimit.resetAt)
            XCTAssertGreaterThanOrEqual(rateLimit.recommendedRetryDelay ?? 0, 0)
        }
    }

    func test_successfulPageResponseIncludesRateLimitMetadata() async throws {
        let resetEpoch = 1_770_000_000
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 200,
                body: """
                {
                  "data": [
                    {
                      "id": "509658",
                      "name": "Just Chatting",
                      "box_art_url": "https://example.com/box-{width}x{height}.jpg",
                      "igdb_id": "0"
                    }
                  ],
                  "pagination": { "cursor": "next-cursor" }
                }
                """,
                headers: [
                    "Ratelimit-Limit": "800",
                    "Ratelimit-Remaining": "799",
                    "Ratelimit-Reset": "\(resetEpoch)",
                ]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchTopGamesPage(first: 1)

        XCTAssertEqual(page.data.first?.id, "509658")
        XCTAssertEqual(page.nextCursor, "next-cursor")
        XCTAssertEqual(page.metadata?.statusCode, 200)
        XCTAssertEqual(page.metadata?.rateLimit.limit, 800)
        XCTAssertEqual(page.metadata?.rateLimit.remaining, 799)
        XCTAssertEqual(page.metadata?.rateLimit.resetAt, Date(timeIntervalSince1970: TimeInterval(resetEpoch)))
    }

    func test_responseMetadataHandlerReceivesSuccessfulResponseMetadata() async throws {
        let recorder = MetadataRecorder()
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 200,
                body: """
                {
                  "data": [
                    {
                      "id": "1",
                      "login": "twitchdev",
                      "display_name": "TwitchDev",
                      "profile_image_url": "https://example.com/profile.png",
                      "broadcaster_type": ""
                    }
                  ]
                }
                """,
                headers: ["Ratelimit-Remaining": "798"]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(
            auth: auth,
            clientID: "client-id",
            httpClient: transport,
            responseMetadataHandler: { metadata in
                Task { await recorder.append(metadata) }
            }
        )

        _ = try await api.fetchUser()

        let metadata = try await recorder.waitForFirst()
        XCTAssertEqual(metadata.statusCode, 200)
        XCTAssertEqual(metadata.rateLimit.remaining, 798)
    }

    func test_serviceUnavailableRetriesOnceByDefault() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: #"{"error":"Service Unavailable","status":503,"message":"Try again"}"#),
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let user = try await api.fetchUser()

        XCTAssertEqual(user.id, "1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func test_serviceUnavailableRetryCanBeDisabled() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: #"{"error":"Service Unavailable","status":503,"message":"Try again"}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(
            auth: auth,
            clientID: "client-id",
            httpClient: transport,
            retryPolicy: .never
        )

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected server error")
        } catch let error as HelixError {
            guard case .serverError(let status) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }
            XCTAssertEqual(status, 503)
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func test_twitchErrorResponsePreservesStatusAndErrorName() async throws {
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 400,
                body: #"{"error":"Bad Request","status":400,"message":"Missing broadcaster_id"}"#
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.error, "Bad Request")
            XCTAssertEqual(apiError.status, 400)
            XCTAssertEqual(apiError.message, "Missing broadcaster_id")
        }
    }

    func test_updateChannelInfoAcceptsNoContentResponse() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: "")
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        try await api.updateChannelInfo(
            broadcasterID: "broadcaster-id",
            with: ChannelInfoUpdate(title: "New title")
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/channels?broadcaster_id=broadcaster-id")
    }

    func test_eventSubSubscriptionAcceptsAcceptedResponse() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[{"id":"subscription-1","status":"enabled","type":"channel.chat.message","version":"1","condition":{"broadcaster_user_id":"broadcaster-id","user_id":"user-id"},"transport":{"method":"websocket","session_id":"session-id"},"created_at":"2024-01-01T00:00:00Z","cost":0}]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let subscription = try await api.createEventSubSubscription(
            type: "channel.chat.message",
            version: "1",
            condition: ["broadcaster_user_id": "broadcaster-id", "user_id": "user-id"],
            sessionID: "session-id"
        )

        XCTAssertEqual(subscription.id, "subscription-1")
        XCTAssertEqual(subscription.transport.method, .websocket)

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/eventsub/subscriptions")
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let transportBody = try XCTUnwrap(object["transport"] as? [String: Any])
        XCTAssertEqual(transportBody["method"] as? String, "websocket")
        XCTAssertEqual(transportBody["session_id"] as? String, "session-id")
    }

    func test_eventSubSubscriptionSupportsWebhookTransport() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[{"id":"subscription-1","status":"enabled","type":"drop.entitlement.grant","version":"1","condition":{"organization_id":"organization"},"transport":{"method":"webhook","callback":"https://example.com/eventsub"},"created_at":"2024-01-01T00:00:00Z","cost":0}]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        try await api.createEventSubSubscription(
            type: "user.update",
            version: "1",
            condition: ["user_id": "1234"],
            transport: .webhook(callback: URL(string: "https://example.com/eventsub")!, secret: "secret")
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let transportBody = try XCTUnwrap(object["transport"] as? [String: Any])
        XCTAssertEqual(transportBody["method"] as? String, "webhook")
        XCTAssertEqual(transportBody["callback"] as? String, "https://example.com/eventsub")
        XCTAssertEqual(transportBody["secret"] as? String, "secret")
    }

    func test_eventSubSubscriptionSupportsBatchingFlag() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[{"id":"subscription-1","status":"enabled","type":"drop.entitlement.grant","version":"1","condition":{"organization_id":"organization"},"transport":{"method":"webhook","callback":"https://example.com/eventsub"},"created_at":"2024-01-01T00:00:00Z","cost":0}]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        try await api.createEventSubSubscription(
            type: "drop.entitlement.grant",
            version: "1",
            condition: ["organization_id": "organization"],
            transport: .webhook(callback: URL(string: "https://example.com/eventsub")!, secret: "secret"),
            isBatchingEnabled: true
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["is_batching_enabled"] as? Bool, true)
    }

    func test_fetchEventSubSubscriptionsPageDecodesCostMetadataAndFilter() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "id": "subscription-1",
                  "status": "enabled",
                  "type": "stream.online",
                  "version": "1",
                  "condition": {
                    "broadcaster_user_id": "1234"
                  },
                  "created_at": "2020-11-10T20:08:33.12345678Z",
                  "transport": {
                    "method": "websocket",
                    "session_id": "session-id",
                    "connected_at": "2020-11-10T20:08:30Z"
                  },
                  "cost": 1
                }
              ],
              "total_cost": 1,
              "max_total_cost": 10000,
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchEventSubSubscriptionsPage(
            filter: .status(.enabled),
            after: "cursor"
        )

        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.totalCost, 1)
        XCTAssertEqual(page.maxTotalCost, 10000)
        XCTAssertEqual(page.nextCursor, "next-cursor")
        XCTAssertEqual(page.data.first?.id, "subscription-1")
        XCTAssertEqual(page.data.first?.status, .enabled)
        XCTAssertEqual(page.data.first?.transport.method, .websocket)
        XCTAssertEqual(page.data.first?.transport.sessionId, "session-id")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/eventsub/subscriptions?status=enabled&after=cursor"
        )
    }

    func test_fetchEventSubSubscriptionsPageSupportsSubscriptionFilter() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 1,
              "data": [
                {
                  "id": "subscription-1",
                  "status": "webhook_callback_verification_pending",
                  "type": "user.update",
                  "version": "1",
                  "condition": {
                    "user_id": "1234"
                  },
                  "created_at": "2020-11-10T14:32:18.730260295Z",
                  "transport": {
                    "method": "webhook",
                    "callback": "https://example.com/eventsub"
                  },
                  "cost": 0
                }
              ],
              "pagination": {}
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchEventSubSubscriptionsPage(filter: .subscriptionID("subscription-1"))

        XCTAssertEqual(page.data.first?.status, .webhookCallbackVerificationPending)
        XCTAssertEqual(page.data.first?.transport.callback?.absoluteString, "https://example.com/eventsub")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/eventsub/subscriptions?subscription_id=subscription-1"
        )
    }

    func test_fetchEventSubSubscriptionsPageRejectsEmptyFilterValue() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchEventSubSubscriptionsPage(filter: .subscriptionID(""))
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "EventSub subscription filter value is required")
        }
    }

    func test_deleteEventSubSubscriptionUsesDeleteMethodAndIdQuery() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: "")
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        try await api.deleteEventSubSubscription(id: "subscription-1")

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/eventsub/subscriptions?id=subscription-1"
        )
    }

    func test_deleteEventSubSubscriptionRejectsEmptyID() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            try await api.deleteEventSubSubscription(id: "")
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "EventSub subscription ID is required")
        }
    }

    func test_deleteAllEventSubSubscriptionsDeletesMatchingPagedResults() async throws {
        // Two pages exist on the server. Deleting shifts the remaining items forward, so the
        // client must re-fetch a fresh first page after each round instead of following the
        // pre-deletion cursor: subscription-3 appears on the next first-page fetch.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"id":"subscription-1","status":"enabled","type":"stream.online","version":"1","condition":{"broadcaster_user_id":"1234"},"transport":{"method":"websocket","session_id":"session-id"},"created_at":"2024-01-01T00:00:00Z","cost":1},{"id":"subscription-2","status":"enabled","type":"stream.offline","version":"1","condition":{"broadcaster_user_id":"1234"},"transport":{"method":"websocket","session_id":"session-id"},"created_at":"2024-01-01T00:00:00Z","cost":1}],"pagination":{"cursor":"stale-cursor"}}"#),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 200, body: #"{"data":[{"id":"subscription-3","status":"enabled","type":"channel.follow","version":"2","condition":{"broadcaster_user_id":"1234"},"transport":{"method":"websocket","session_id":"session-id"},"created_at":"2024-01-01T00:00:00Z","cost":1}],"pagination":{}}"#),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 200, body: #"{"data":[],"pagination":{}}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let deletedCount = try await api.deleteAllEventSubSubscriptions(filter: .status(.enabled))

        XCTAssertEqual(deletedCount, 3)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "DELETE", "DELETE", "GET", "DELETE", "GET"])
        XCTAssertEqual(
            requests.map { $0.url?.absoluteString },
            [
                "https://api.twitch.tv/helix/eventsub/subscriptions?status=enabled",
                "https://api.twitch.tv/helix/eventsub/subscriptions?id=subscription-1",
                "https://api.twitch.tv/helix/eventsub/subscriptions?id=subscription-2",
                "https://api.twitch.tv/helix/eventsub/subscriptions?status=enabled",
                "https://api.twitch.tv/helix/eventsub/subscriptions?id=subscription-3",
                "https://api.twitch.tv/helix/eventsub/subscriptions?status=enabled"
            ]
        )
    }

    func test_deleteAllEventSubSubscriptionsToleratesConcurrentlyDeletedSubscription() async throws {
        // A 404 on one delete means another client (or Twitch) already removed
        // that subscription — the cleanup must skip it and keep draining
        // instead of aborting the whole run and losing the count.
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"id":"subscription-1","status":"enabled","type":"stream.online","version":"1","condition":{"broadcaster_user_id":"1234"},"transport":{"method":"websocket","session_id":"session-id"},"created_at":"2024-01-01T00:00:00Z","cost":1},{"id":"subscription-2","status":"enabled","type":"stream.offline","version":"1","condition":{"broadcaster_user_id":"1234"},"transport":{"method":"websocket","session_id":"session-id"},"created_at":"2024-01-01T00:00:00Z","cost":1}],"pagination":{}}"#),
            .json(statusCode: 404, body: #"{"error":"Not Found","status":404,"message":"subscription not found"}"#),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 200, body: #"{"data":[],"pagination":{}}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let deletedCount = try await api.deleteAllEventSubSubscriptions(filter: .status(.enabled))

        // Only subscription-2 was deleted by THIS call; subscription-1 was already gone.
        XCTAssertEqual(deletedCount, 1)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "DELETE", "DELETE", "GET"])
    }

    func test_fetchChannelsInfoUsesRepeatedBroadcasterIDs() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "1",
                  "broadcaster_login": "twitchdev",
                  "broadcaster_name": "TwitchDev",
                  "broadcaster_language": "en",
                  "game_id": "509658",
                  "game_name": "Just Chatting",
                  "title": "Building TwitchKit",
                  "delay": 0,
                  "tags": ["Swift"],
                  "content_classification_labels": [],
                  "is_branded_content": false
                },
                {
                  "broadcaster_id": "2",
                  "broadcaster_login": "twitch",
                  "broadcaster_name": "Twitch",
                  "broadcaster_language": "en",
                  "game_id": "509658",
                  "game_name": "Just Chatting",
                  "title": "Live",
                  "delay": 0,
                  "tags": [],
                  "content_classification_labels": [],
                  "is_branded_content": false
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let channels = try await api.fetchChannelsInfo(broadcasterIDs: ["1", "2"])

        XCTAssertEqual(channels.map(\.broadcasterName), ["TwitchDev", "Twitch"])
        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/channels?broadcaster_id=1&broadcaster_id=2"
        )
    }

    func test_fetchChannelFollowersPageReturnsPaginationCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "user_id": "1",
                  "user_login": "viewer1",
                  "user_name": "Viewer1",
                  "followed_at": "2024-01-01T00:00:00Z"
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchChannelFollowersPage(
            broadcasterID: "broadcaster-id",
            first: 1
        )

        XCTAssertEqual(page.data.map(\.userName), ["Viewer1"])
        XCTAssertEqual(page.nextCursor, "next-cursor")
        XCTAssertEqual(page.total, 2)

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/channels/followers?broadcaster_id=broadcaster-id&first=1"
        )
    }

    func test_channelFollowersSequenceFetchesNextPageUsingCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "user_id": "1",
                  "user_login": "viewer1",
                  "user_name": "Viewer1",
                  "followed_at": "2024-01-01T00:00:00Z"
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """),
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "user_id": "2",
                  "user_login": "viewer2",
                  "user_name": "Viewer2",
                  "followed_at": "2024-01-02T00:00:00Z"
                }
              ],
              "pagination": {}
            }
            """),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        var followers: [String] = []
        for try await follower in api.channelFollowers(broadcasterID: "broadcaster-id", pageSize: 1) {
            followers.append(follower.userName)
        }

        XCTAssertEqual(followers, ["Viewer1", "Viewer2"])

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            "https://api.twitch.tv/helix/channels/followers?broadcaster_id=broadcaster-id&first=1"
        )
        XCTAssertEqual(
            requests[1].url?.absoluteString,
            "https://api.twitch.tv/helix/channels/followers?broadcaster_id=broadcaster-id&first=1&after=next-cursor"
        )
    }

    func test_moderatorsSequenceFetchesNextPageUsingCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "1", "user_login": "mod1", "user_name": "Mod1" }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """),
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "2", "user_login": "mod2", "user_name": "Mod2" }
              ],
              "pagination": {}
            }
            """),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        var moderators: [String] = []
        for try await moderator in api.moderators(broadcasterID: "broadcaster-id", pageSize: 1) {
            moderators.append(moderator.userName)
        }

        XCTAssertEqual(moderators, ["Mod1", "Mod2"])

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/moderators?broadcaster_id=broadcaster-id&first=1"
        )
        XCTAssertEqual(
            requests[1].url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/moderators?broadcaster_id=broadcaster-id&first=1&after=next-cursor"
        )
    }

    func test_fetchChattersPageAcceptsPageSizeAboveDefaultHelixLimit() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "1", "user_login": "viewer", "user_name": "Viewer" }
              ],
              "pagination": {}
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchChattersPage(broadcasterID: "broadcaster", moderatorID: "moderator", first: 1000)

        let request = try await firstRecordedRequest(from: transport)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/chatters?broadcaster_id=broadcaster&moderator_id=moderator&first=1000"
        )
    }

    func test_fetchChannelStreamSchedulePageRejectsPageSizeOverScheduleLimit() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchChannelStreamSchedulePage(broadcasterID: "broadcaster", first: 26)
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Page size must be between 1 and 25")
        }
    }

    func test_fetchCustomRewardRedemptionsPageRequiresStatusWhenNoIDsSpecified() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchCustomRewardRedemptionsPage(broadcasterID: "broadcaster", rewardID: "reward")
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "A redemption status is required when no redemption IDs are specified")
        }
    }

    func test_fetchEmoteSetsRejectsMoreThanTwentyFiveIDs() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchEmoteSets(ids: (1...26).map(String.init))
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Twitch allows up to 25 emote set IDs")
        }
    }

    func test_deleteVideosRejectsEmptyIDs() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.deleteVideos(ids: [])
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "At least one video ID is required")
        }
    }

    func test_fetchClipsPageRequiresExactlyOneFilter() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchClipsPage()
            XCTFail("Expected bad request for zero filters")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Exactly one of broadcaster ID, game ID, or clip IDs must be specified")
        }

        do {
            _ = try await api.fetchClipsPage(broadcasterID: "broadcaster", gameID: "game")
            XCTFail("Expected bad request for multiple filters")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Exactly one of broadcaster ID, game ID, or clip IDs must be specified")
        }
    }

    func test_fetchStreamsPageRejectsMoreThanOneHundredUserIDs() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchStreamsPage(userIDs: (1...101).map(String.init))
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Twitch allows up to 100 user IDs")
        }
    }

    func test_fetchTeamsRequiresExactlyOneOfNameOrID() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchTeams(name: "team", id: "1")
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Exactly one of team name or team ID must be specified")
        }
    }

    func test_groupTwoHelixEndpointsUseExpectedPathsAndQueries() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: "BEGIN:VCALENDAR"),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchFollowedChannelsPage(userID: "user", broadcasterID: "broadcaster", first: 10, after: "cursor")
        _ = try await api.fetchChannelEditors(broadcasterID: "broadcaster")
        _ = try await api.fetchContentClassificationLabels(locale: "en-US")
        _ = try await api.fetchSearchChannelsPage(query: "swift", liveOnly: true, first: 5)
        _ = try await api.fetchChannelICalendar(broadcasterID: "broadcaster")
        _ = try await api.fetchCharityCampaign(broadcasterID: "broadcaster")
        _ = try await api.fetchHypeTrainStatus(broadcasterID: "broadcaster")

        let urls = await transport.recordedRequests().map { $0.url?.absoluteString }
        XCTAssertEqual(urls[0], "https://api.twitch.tv/helix/channels/followed?user_id=user&broadcaster_id=broadcaster&first=10&after=cursor")
        XCTAssertEqual(urls[1], "https://api.twitch.tv/helix/channels/editors?broadcaster_id=broadcaster")
        XCTAssertEqual(urls[2], "https://api.twitch.tv/helix/content_classification_labels?locale=en-US")
        XCTAssertEqual(urls[3], "https://api.twitch.tv/helix/search/channels?query=swift&live_only=true&first=5")
        XCTAssertEqual(urls[4], "https://api.twitch.tv/helix/schedule/icalendar?broadcaster_id=broadcaster")
        XCTAssertEqual(urls[5], "https://api.twitch.tv/helix/charity/campaigns?broadcaster_id=broadcaster")
        XCTAssertEqual(urls[6], "https://api.twitch.tv/helix/hypetrain/status?broadcaster_id=broadcaster")
    }

    func test_creatorHelixEndpointsUseExpectedPathsAndQueries() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"data":[]}"#),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchPollsPage(broadcasterID: "broadcaster", ids: ["poll"], first: 1)
        _ = try await api.fetchPredictionsPage(broadcasterID: "broadcaster", ids: ["prediction"], after: "cursor")
        try await api.cancelRaid(broadcasterID: "broadcaster")
        _ = try await api.fetchStreamMarkersPage(userID: "user", first: 2)
        _ = try await api.fetchCreatorGoals(broadcasterID: "broadcaster")
        _ = try await api.fetchCustomRewards(broadcasterID: "broadcaster", ids: ["reward"], onlyManageableRewards: true)
        _ = try await api.fetchBroadcasterSubscriptionsPage(broadcasterID: "broadcaster", userIDs: ["user"])
        _ = try await api.fetchClipsPage(broadcasterID: "broadcaster", first: 3)
        _ = try await api.fetchClipDownloads(broadcasterID: "broadcaster", editorID: "editor", clipIDs: ["clip"])
        _ = try await api.fetchVideosPage(userID: "user", type: "archive", first: 4)

        let urls = await transport.recordedRequests().map { $0.url?.absoluteString }
        XCTAssertEqual(urls[0], "https://api.twitch.tv/helix/polls?broadcaster_id=broadcaster&id=poll&first=1")
        XCTAssertEqual(urls[1], "https://api.twitch.tv/helix/predictions?broadcaster_id=broadcaster&id=prediction&after=cursor")
        XCTAssertEqual(urls[2], "https://api.twitch.tv/helix/raids?broadcaster_id=broadcaster")
        XCTAssertEqual(urls[3], "https://api.twitch.tv/helix/streams/markers?user_id=user&first=2")
        XCTAssertEqual(urls[4], "https://api.twitch.tv/helix/goals?broadcaster_id=broadcaster")
        XCTAssertEqual(urls[5], "https://api.twitch.tv/helix/channel_points/custom_rewards?broadcaster_id=broadcaster&id=reward&only_manageable_rewards=true")
        XCTAssertEqual(urls[6], "https://api.twitch.tv/helix/subscriptions?broadcaster_id=broadcaster&user_id=user")
        XCTAssertEqual(urls[7], "https://api.twitch.tv/helix/clips?broadcaster_id=broadcaster&first=3")
        XCTAssertEqual(urls[8], "https://api.twitch.tv/helix/clips/downloads?broadcaster_id=broadcaster&editor_id=editor&clip_id=clip")
        XCTAssertEqual(urls[9], "https://api.twitch.tv/helix/videos?user_id=user&type=archive&first=4")
    }

    func test_scheduleAndPollRequestsEncodeTypedBodies() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: ""),
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "poll",
                  "broadcaster_id": "broadcaster",
                  "broadcaster_login": "streamer",
                  "broadcaster_name": "Streamer",
                  "title": "Question?",
                  "choices": [{ "id": "choice", "title": "Yes", "votes": 0, "channel_points_votes": 0, "bits_votes": 0 }],
                  "bits_voting_enabled": false,
                  "bits_per_vote": 0,
                  "channel_points_voting_enabled": false,
                  "channel_points_per_vote": 0,
                  "status": "ACTIVE",
                  "duration": 60,
                  "started_at": "2024-01-01T00:00:00Z"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)
        let date = Date(timeIntervalSince1970: 1_704_067_200)

        try await api.updateChannelStreamSchedule(
            broadcasterID: "broadcaster",
            with: ChannelStreamScheduleSettingsUpdate(
                isVacationEnabled: true,
                vacationStartTime: date,
                vacationEndTime: date,
                timezone: "Australia/Sydney"
            )
        )
        _ = try await api.createPoll(
            PollCreateRequest(
                broadcasterID: "broadcaster",
                title: "Question?",
                choices: [PollChoice(title: "Yes")],
                duration: 60
            )
        )

        let requests = await transport.recordedRequests()
        // Update Channel Stream Schedule takes its settings as query parameters, not a body.
        let scheduleRequest = requests[0]
        XCTAssertEqual(scheduleRequest.httpMethod, "PATCH")
        XCTAssertNil(scheduleRequest.httpBody)
        let scheduleURL = try XCTUnwrap(scheduleRequest.url)
        let scheduleComponents = try XCTUnwrap(URLComponents(url: scheduleURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(scheduleComponents.path, "/helix/schedule/settings")
        let scheduleQuery = Dictionary(
            uniqueKeysWithValues: (scheduleComponents.queryItems ?? []).map { ($0.name, $0.value) }
        )
        XCTAssertEqual(scheduleQuery["broadcaster_id"], "broadcaster")
        XCTAssertEqual(scheduleQuery["is_vacation_enabled"], "true")
        XCTAssertEqual(scheduleQuery["vacation_start_time"], TwitchDateParser.string(from: date))
        XCTAssertEqual(scheduleQuery["vacation_end_time"], TwitchDateParser.string(from: date))
        XCTAssertEqual(scheduleQuery["timezone"], "Australia/Sydney")

        let pollBody = try XCTUnwrap(requests[1].httpBody)
        let pollObject = try XCTUnwrap(JSONSerialization.jsonObject(with: pollBody) as? [String: Any])
        XCTAssertEqual(pollObject["broadcaster_id"] as? String, "broadcaster")
        XCTAssertEqual(pollObject["duration"] as? Int, 60)
    }

    /// Schedule endpoints return `data` as a single OBJECT, not the usual
    /// Helix `data` array, so they need the dedicated envelope decode path.
    func test_fetchChannelStreamScheduleDecodesSingleObjectEnvelope() async throws {
        let scheduleBody = """
        {
          "data": {
            "segments": [
              {
                "id": "segment-1",
                "start_time": "2024-07-01T18:00:00Z",
                "end_time": "2024-07-01T19:00:00Z",
                "title": "Weekly stream",
                "canceled_until": null,
                "category": { "id": "509670", "name": "Science & Technology" },
                "is_recurring": true
              }
            ],
            "broadcaster_id": "141981764",
            "broadcaster_name": "TwitchDev",
            "broadcaster_login": "twitchdev",
            "vacation": null
          },
          "pagination": { "cursor": "next-cursor" }
        }
        """
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: scheduleBody),
            .json(statusCode: 200, body: scheduleBody),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchChannelStreamSchedulePage(broadcasterID: "141981764")

        XCTAssertEqual(page.schedule.broadcasterId, "141981764")
        XCTAssertEqual(page.schedule.broadcasterLogin, "twitchdev")
        XCTAssertEqual(page.schedule.segments.map(\.id), ["segment-1"])
        XCTAssertEqual(page.schedule.segments.first?.isRecurring, true)
        XCTAssertNil(page.schedule.vacation)
        XCTAssertEqual(page.nextCursor, "next-cursor")

        let created = try await api.createChannelStreamScheduleSegment(
            broadcasterID: "141981764",
            segment: ChannelStreamScheduleSegmentCreate(
                startTime: Date(timeIntervalSince1970: 1_704_067_200),
                timezone: "America/New_York",
                isRecurring: true
            )
        )
        XCTAssertEqual(created.segments.first?.title, "Weekly stream")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/schedule?broadcaster_id=141981764"
        )
        XCTAssertEqual(requests.last?.httpMethod, "POST")
    }

    func test_newHelixCoverageUsesExpectedAdsBitsAndDiscoveryEndpoints() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"length":60,"message":"ok","retry_after":480}]}"#),
            .json(statusCode: 200, body: #"{"data":[{"prefix":"Cheer","tiers":[],"type":"global_first_party","order":1,"last_updated":"2024-01-01T00:00:00Z","is_charitable":false}]}"#),
            .json(statusCode: 200, body: #"{"data":[],"pagination":{"cursor":"next"}}"#),
            .json(statusCode: 204, body: ""),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.startCommercial(broadcasterID: "broadcaster", length: 60)
        _ = try await api.fetchCheermotes(broadcasterID: "broadcaster")
        _ = try await api.fetchAllStreamTags(tagIDs: ["tag"], first: 10, after: "cursor")
        try await api.sendWhisper(fromUserID: "from", toUserID: "to", message: "hello")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].url?.absoluteString, "https://api.twitch.tv/helix/channels/commercial")
        XCTAssertEqual(requests[1].url?.absoluteString, "https://api.twitch.tv/helix/bits/cheermotes?broadcaster_id=broadcaster")
        XCTAssertEqual(requests[2].url?.absoluteString, "https://api.twitch.tv/helix/tags/streams?tag_id=tag&first=10&after=cursor")
        XCTAssertEqual(requests[3].httpMethod, "POST")
        XCTAssertEqual(requests[3].url?.absoluteString, "https://api.twitch.tv/helix/whispers?from_user_id=from&to_user_id=to")
    }

    func test_newHelixCoverageUsesExpectedConduitAndEntitlementEndpoints() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"id":"conduit","shard_count":2}]}"#),
            .json(statusCode: 200, body: #"{"data":[],"pagination":{"cursor":"next"}}"#),
            .json(statusCode: 200, body: #"{"data":[{"status":"SUCCESS","ids":["entitlement"]}]}"#),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.createConduit(shardCount: 2)
        _ = try await api.fetchDropsEntitlementsPage(gameID: "game", fulfillmentStatus: .claimed, first: 5, after: "cursor")
        _ = try await api.updateDropsEntitlements(entitlementIDs: ["entitlement"], fulfillmentStatus: .fulfilled)

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].url?.absoluteString, "https://api.twitch.tv/helix/eventsub/conduits")
        XCTAssertEqual(requests[1].url?.absoluteString, "https://api.twitch.tv/helix/entitlements/drops?game_id=game&fulfillment_status=CLAIMED&first=5&after=cursor")
        XCTAssertEqual(requests[2].httpMethod, "PATCH")
        XCTAssertEqual(requests[2].url?.absoluteString, "https://api.twitch.tv/helix/entitlements/drops")
    }

    func test_newHelixCoverageUsesExpectedExtensionAndUserExtensionEndpoints() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"id":"ext","name":"Extension"}]}"#),
            .json(statusCode: 204, body: ""),
            .json(statusCode: 200, body: #"{"data":{"panel":{},"overlay":{},"component":{}}}"#),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        _ = try await api.fetchExtensions(extensionID: "ext", extensionVersion: "1.0.0")
        try await api.setExtensionRequiredConfiguration(
            broadcasterID: "broadcaster",
            extensionID: "ext",
            extensionVersion: "1.0.0",
            requiredConfiguration: "{}"
        )
        _ = try await api.fetchUserActiveExtensions(userID: "user")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests[0].url?.absoluteString, "https://api.twitch.tv/helix/extensions?extension_id=ext&extension_version=1.0.0")
        XCTAssertEqual(requests[1].httpMethod, "PUT")
        XCTAssertEqual(requests[1].url?.absoluteString, "https://api.twitch.tv/helix/extensions/required_configuration?broadcaster_id=broadcaster")
        XCTAssertEqual(requests[2].url?.absoluteString, "https://api.twitch.tv/helix/users/extensions?user_id=user")
    }

    func test_newHelixCoverageUsesExpectedGuestStarEndpoints() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: ""),
            .json(statusCode: 204, body: ""),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        try await api.sendGuestStarInvite(broadcasterID: "broadcaster", moderatorID: "moderator", sessionID: "session", guestID: "guest")
        try await api.updateGuestStarSlotSettings(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            sessionID: "session",
            slotID: "1",
            update: GuestStarSlotSettingsUpdate(isAudioEnabled: true, isLive: false, volume: 75)
        )

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].url?.absoluteString, "https://api.twitch.tv/helix/guest_star/invites?broadcaster_id=broadcaster&moderator_id=moderator&session_id=session&guest_id=guest")
        XCTAssertEqual(requests[1].httpMethod, "PATCH")
        XCTAssertEqual(requests[1].url?.absoluteString, "https://api.twitch.tv/helix/guest_star/slot_settings?broadcaster_id=broadcaster&moderator_id=moderator&session_id=session&slot_id=1&is_audio_enabled=true&is_live=false&volume=75")
    }

    // MARK: - Transport errors

    func test_urlErrorSurfacesAsTransportWithOriginalCode() async throws {
        let transport = MockHTTPClient(responses: [
            .failure(URLError(.notConnectedToInternet))
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected transport error")
        } catch let error as HelixError {
            guard case .transport(let urlError) = error else {
                return XCTFail("Expected HelixError.transport, got \(error)")
            }
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        }
    }

    func test_nonURLTransportErrorStillSurfacesAsNetworkError() async throws {
        let transport = MockHTTPClient(responses: [
            .failure(MockTransportError())
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected network error")
        } catch let error as HelixError {
            guard case .networkError = error else {
                return XCTFail("Expected HelixError.networkError, got \(error)")
            }
        }
    }

    // MARK: - Conduit shard updates

    func test_updateConduitShardsSurfacesPerShardErrors() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[{"id":"0","status":"enabled","transport":{"method":"webhook","callback":"https://example.com/callback"}}],"errors":[{"id":"1","message":"The shard id is outside the conduit's range","code":"invalid_parameter"}]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let result = try await api.updateConduitShards(
            conduitID: "conduit-1",
            shards: [
                EventSubConduitShardUpdate(
                    id: "0",
                    transport: EventSubConduitShardTransport(
                        method: .webhook,
                        callback: URL(string: "https://example.com/callback"),
                        secret: "s3cre7"
                    )
                )
            ]
        )

        XCTAssertEqual(result.updated.map(\.id), ["0"])
        XCTAssertEqual(result.updated.first?.status, "enabled")
        XCTAssertEqual(
            result.errors,
            [
                ConduitShardUpdateError(
                    id: "1",
                    message: "The shard id is outside the conduit's range",
                    code: "invalid_parameter"
                )
            ]
        )
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.httpMethod, "PATCH")
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.twitch.tv/helix/eventsub/conduits/shards")
    }

    func test_updateConduitShardsDefaultsToNoErrorsWhenErrorsKeyIsAbsent() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[{"id":"0","status":"enabled","transport":{"method":"websocket","session_id":"session-id"}}]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let result = try await api.updateConduitShards(
            conduitID: "conduit-1",
            shards: [
                EventSubConduitShardUpdate(
                    id: "0",
                    transport: EventSubConduitShardTransport(method: .websocket, sessionID: "session-id")
                )
            ]
        )

        XCTAssertEqual(result.updated.map(\.id), ["0"])
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Extension live channels pagination

    func test_fetchExtensionLiveChannelsPageDecodesStringPaginationCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"broadcaster_id":"1","broadcaster_name":"TwitchDev","game_name":"Just Chatting","game_id":"509658","title":"Building TwitchKit"}],"pagination":"cursor-value"}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchExtensionLiveChannelsPage(extensionID: "ext", first: 2)

        XCTAssertEqual(page.data.map(\.broadcasterName), ["TwitchDev"])
        XCTAssertEqual(page.pagination?.cursor, "cursor-value")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/extensions/live?extension_id=ext&first=2"
        )
    }

    func test_fetchExtensionLiveChannelsPageTreatsEmptyStringPaginationAsEnd() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[{"broadcaster_id":"1","broadcaster_name":"TwitchDev","game_name":"Just Chatting","game_id":"509658","title":"Building TwitchKit"}],"pagination":""}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientID: "client-id", httpClient: transport)

        let page = try await api.fetchExtensionLiveChannelsPage(extensionID: "ext", after: "cursor-value")

        XCTAssertEqual(page.data.map(\.broadcasterId), ["1"])
        XCTAssertNil(page.pagination)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/extensions/live?extension_id=ext&after=cursor-value"
        )
    }

    func test_extensionLiveChannelsPageStillDecodesObjectAndAbsentPagination() throws {
        let objectForm = Data(#"{"data":[],"pagination":{"cursor":"object-cursor"}}"#.utf8)
        let objectPage = try JSONDecoder.twitch().decode(ExtensionLiveChannelsPage.self, from: objectForm)
        XCTAssertEqual(objectPage.pagination?.cursor, "object-cursor")

        let absentForm = Data(#"{"data":[]}"#.utf8)
        let absentPage = try JSONDecoder.twitch().decode(ExtensionLiveChannelsPage.self, from: absentForm)
        XCTAssertNil(absentPage.pagination)

        let nullForm = Data(#"{"data":[],"pagination":null}"#.utf8)
        let nullPage = try JSONDecoder.twitch().decode(ExtensionLiveChannelsPage.self, from: nullForm)
        XCTAssertNil(nullPage.pagination)
    }
}

actor MockHTTPClient: HTTPClient {
    enum Response {
        case json(statusCode: Int, body: String, headers: [String: String] = [:])
        /// Parks the request until `gate.open()` — for tests that need to
        /// interleave other calls while this one is deterministically in flight.
        case gatedJSON(gate: ResponseGate, statusCode: Int, body: String)
        case nonHTTP(body: Data)
        case cancellation
        case failure(any Error & Sendable)
    }

    private var responses: [Response]
    private(set) var requests: [URLRequest] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw HelixError.networkError("No mock response queued")
        }

        switch responses.removeFirst() {
        case .json(let statusCode, let body, let headers):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            return (Data(body.utf8), response)

        case .gatedJSON(let gate, let statusCode, let body):
            await gate.wait()
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (Data(body.utf8), response)

        case .nonHTTP(let body):
            return (body, URLResponse(url: request.url ?? URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: body.count, textEncodingName: nil))

        case .cancellation:
            throw CancellationError()

        case .failure(let error):
            throw error
        }
    }
}

/// Holds a `gatedJSON` mock response in flight until `open()` is called.
actor ResponseGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private struct MockTransportError: Error, Sendable {}

actor MetadataRecorder {
    private var metadata: [HelixResponseMetadata] = []

    func append(_ value: HelixResponseMetadata) {
        metadata.append(value)
    }

    func waitForFirst() async throws -> HelixResponseMetadata {
        for _ in 0..<20 {
            if let first = metadata.first {
                return first
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw HelixError.invalidResponse
    }
}

private func makeAuth(
    clientID: String = "client-id",
    clientSecret: String? = nil,
    httpClient: any HTTPClient = URLSessionHTTPClient()
) -> TwitchAuth {
    TwitchAuth(
        oauthClient: TwitchOAuthClient(
            clientID: clientID,
            clientSecret: clientSecret,
            httpClient: httpClient
        ),
        tokenStore: InMemoryTokenStore()
    )
}

private func firstRecordedRequest(from transport: MockHTTPClient) async throws -> URLRequest {
    let requests = await transport.recordedRequests()
    return try XCTUnwrap(requests.first)
}
