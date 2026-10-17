import XCTest
import Foundation
@testable import TwitchKit

/// Tests for EventSub WebSocket message parsing — the envelope that wraps all events.
final class EventSubMessageTests: XCTestCase {

    func test_decodeSessionWelcome() throws {
        let json = """
        {
            "metadata": {
                "message_id": "96a3f3b5-5dec-4eed-908e-e11ee657416c",
                "message_type": "session_welcome",
                "message_timestamp": "2023-07-19T14:56:51.634234626Z"
            },
            "payload": {
                "session": {
                    "id": "AQoQHR3s6Mb4T8GFB1l3DlPfiRIGY2VsbC1h",
                    "status": "connected",
                    "connected_at": "2023-07-19T14:56:51.616329898Z",
                    "keepalive_timeout_seconds": 10,
                    "reconnect_url": null
                }
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: json)

        XCTAssertEqual(envelope.metadata.messageType, "session_welcome")
        XCTAssertEqual(envelope.payload.session?.id, "AQoQHR3s6Mb4T8GFB1l3DlPfiRIGY2VsbC1h")
        XCTAssertEqual(envelope.payload.session?.status, "connected")
        XCTAssertEqual(envelope.payload.session?.keepaliveTimeoutSeconds, 10)
        XCTAssertEqual(envelope.payload.session?.reconnectURL, nil)
    }

    func test_decodeSessionKeepalive() throws {
        let json = """
        {
            "metadata": {
                "message_id": "keepalive-123",
                "message_type": "session_keepalive",
                "message_timestamp": "2023-07-19T15:00:00Z"
            },
            "payload": {}
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: json)

        XCTAssertEqual(envelope.metadata.messageType, "session_keepalive")
        XCTAssertNil(envelope.payload.session)
    }

    func test_decodeSessionReconnect() throws {
        let json = """
        {
            "metadata": {
                "message_id": "reconnect-456",
                "message_type": "session_reconnect",
                "message_timestamp": "2023-07-19T15:05:00Z"
            },
            "payload": {
                "session": {
                    "id": "newSession123",
                    "status": "reconnecting",
                    "keepalive_timeout_seconds": 10,
                    "reconnect_url": "wss://eventsub.wss.twitch.tv/ws?session_id=newSession123"
                }
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: json)

        XCTAssertEqual(envelope.metadata.messageType, "session_reconnect")
        XCTAssertEqual(envelope.payload.session?.reconnectURL, "wss://eventsub.wss.twitch.tv/ws?session_id=newSession123")
    }

    func test_unknownEventType() {
        let data = "some raw payload".data(using: .utf8)!
        let event = EventSubEvent.unknown(type: "channel.new_thing", payload: data)

        if case .unknown(let type, let payload) = event {
            XCTAssertEqual(type, "channel.new_thing")
            XCTAssertEqual(payload, data)
        } else {
            XCTFail("Expected .unknown case")
        }
    }

    func test_decodeNotificationEnvelopeDecodesTypedEventWithoutEventReencodingPath() throws {
        let json = """
        {
            "metadata": {
                "message_id": "notification-1",
                "message_type": "notification",
                "message_timestamp": "2023-07-19T15:00:00Z",
                "subscription_type": "stream.online"
            },
            "payload": {
                "subscription": {
                    "id": "sub-id",
                    "status": "enabled",
                    "type": "stream.online",
                    "version": "1",
                    "condition": {
                        "broadcaster_user_id": "1337"
                    },
                    "transport": {
                        "method": "websocket",
                        "session_id": "session-id"
                    },
                    "created_at": "2023-07-19T14:59:00Z",
                    "cost": 0
                },
                "event": {
                    "id": "9001",
                    "broadcaster_user_id": "1337",
                    "broadcaster_user_login": "cool_user",
                    "broadcaster_user_name": "Cool_User",
                    "type": "live",
                    "started_at": "2020-10-11T10:11:12.123Z"
                }
            }
        }
        """.data(using: .utf8)!

        let event = EventSubEvent.decodeNotification(type: "stream.online", envelope: json)

        guard case .streamOnline(let stream) = event else {
            return XCTFail("Expected .streamOnline")
        }
        XCTAssertEqual(stream.id, "9001")
        XCTAssertEqual(stream.broadcasterUserID, "1337")
    }

    func test_decodeTypedStreamOnlineEvent() throws {
        let json = """
        {
            "id": "9001",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "type": "live",
            "started_at": "2020-10-11T10:11:12.123Z"
        }
        """.data(using: .utf8)!

        let event = EventSubEvent.decode(type: "stream.online", payload: json)

        guard case .streamOnline(let stream) = event else {
            return XCTFail("Expected .streamOnline")
        }
        XCTAssertEqual(stream.id, "9001")
        XCTAssertEqual(stream.broadcasterUserID, "1337")
        XCTAssertEqual(stream.type, .live)
    }

    func test_decodeTypedChannelUpdateEvent() throws {
        let json = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "title": "Best Stream Ever",
            "language": "en",
            "category_id": "21779",
            "category_name": "Fortnite",
            "content_classification_labels": ["MatureGame"]
        }
        """.data(using: .utf8)!

        let event = EventSubEvent.decode(type: "channel.update", payload: json)

        guard case .channelUpdate(let update) = event else {
            return XCTFail("Expected .channelUpdate")
        }
        XCTAssertEqual(update.title, "Best Stream Ever")
        XCTAssertEqual(update.categoryName, "Fortnite")
        XCTAssertEqual(update.contentClassificationLabels, ["MatureGame"])
    }

    func test_decodeTypedModerationAndChannelPointsEvents() throws {
        let banJSON = """
        {
            "user_id": "1234",
            "user_login": "bad_user",
            "user_name": "Bad_User",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "moderator_user_id": "4242",
            "moderator_user_login": "mod_user",
            "moderator_user_name": "Mod_User",
            "reason": "Breaking the rules",
            "banned_at": "2020-07-15T18:16:11.17106713Z",
            "ends_at": null,
            "is_permanent": true
        }
        """.data(using: .utf8)!

        let redemptionJSON = """
        {
            "id": "redemption-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "user_id": "9001",
            "user_login": "viewer",
            "user_name": "Viewer",
            "user_input": "Hydrate",
            "status": "unfulfilled",
            "reward": {
                "id": "reward-id",
                "title": "Hydrate",
                "prompt": "Drink water",
                "cost": 100
            },
            "redeemed_at": "2020-07-15T17:16:03.17106713Z"
        }
        """.data(using: .utf8)!

        let banEvent = EventSubEvent.decode(type: "channel.ban", payload: banJSON)
        let redemptionEvent = EventSubEvent.decode(
            type: "channel.channel_points_custom_reward_redemption.add",
            payload: redemptionJSON
        )

        guard case .ban(let ban) = banEvent else {
            return XCTFail("Expected .ban")
        }
        XCTAssertTrue(ban.isPermanent)
        XCTAssertEqual(ban.reason, "Breaking the rules")

        guard case .channelPointsCustomRewardRedemptionAdd(let redemption) = redemptionEvent else {
            return XCTFail("Expected .channelPointsCustomRewardRedemptionAdd")
        }
        XCTAssertEqual(redemption.status, .unfulfilled)
        XCTAssertEqual(redemption.reward.title, "Hydrate")
        XCTAssertEqual(redemption.userInput, "Hydrate")
    }

    func test_decodeTypedChatModerationEvents() throws {
        let deleteJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "target_user_id": "1234",
            "target_user_login": "viewer",
            "target_user_name": "Viewer",
            "message_id": "message-id"
        }
        """.data(using: .utf8)!

        let settingsJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "emote_mode": false,
            "follower_mode": true,
            "follower_mode_duration_minutes": 10,
            "slow_mode": true,
            "slow_mode_wait_time_seconds": 30,
            "subscriber_mode": false,
            "unique_chat_mode": true
        }
        """.data(using: .utf8)!

        let deleteEvent = EventSubEvent.decode(type: "channel.chat.message_delete", payload: deleteJSON)
        let settingsEvent = EventSubEvent.decode(type: "channel.chat_settings.update", payload: settingsJSON)

        guard case .chatMessageDelete(let delete) = deleteEvent else {
            return XCTFail("Expected .chatMessageDelete")
        }
        XCTAssertEqual(delete.messageID, "message-id")

        guard case .chatSettingsUpdate(let settings) = settingsEvent else {
            return XCTFail("Expected .chatSettingsUpdate")
        }
        XCTAssertEqual(settings.slowModeWaitTimeSeconds, 30)
        XCTAssertTrue(settings.uniqueChatMode)
    }

    func test_decodeTypedSubscriptionAndWarningEvents() throws {
        let giftJSON = """
        {
            "user_id": null,
            "user_login": null,
            "user_name": null,
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "total": 5,
            "tier": "1000",
            "cumulative_total": 25,
            "is_anonymous": true
        }
        """.data(using: .utf8)!

        let warningJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "moderator_user_id": "4242",
            "moderator_user_login": "mod_user",
            "moderator_user_name": "Mod_User",
            "user_id": "1234",
            "user_login": "viewer",
            "user_name": "Viewer",
            "reason": "Please follow chat rules"
        }
        """.data(using: .utf8)!

        let giftEvent = EventSubEvent.decode(type: "channel.subscription.gift", payload: giftJSON)
        let warningEvent = EventSubEvent.decode(type: "channel.warning.send", payload: warningJSON)

        guard case .subscriptionGift(let gift) = giftEvent else {
            return XCTFail("Expected .subscriptionGift")
        }
        XCTAssertEqual(gift.total, 5)
        XCTAssertEqual(gift.tier, .tier1)

        guard case .warningSend(let warning) = warningEvent else {
            return XCTFail("Expected .warningSend")
        }
        XCTAssertEqual(warning.userName, "Viewer")
        XCTAssertEqual(warning.reason, "Please follow chat rules")
    }

    func test_decodeTypedCreatorEngagementEvents() throws {
        let pollJSON = """
        {
            "id": "poll-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "title": "Choose the next game",
            "choices": [
                { "id": "choice-1", "title": "Game A", "votes": 10, "channel_points_votes": 5, "bits_votes": 0 }
            ],
            "bits_voting": { "is_enabled": false, "amount_per_vote": 0 },
            "channel_points_voting": { "is_enabled": true, "amount_per_vote": 100 },
            "status": "completed",
            "duration_seconds": 120,
            "started_at": "2020-07-15T17:16:03.17106713Z",
            "ended_at": "2020-07-15T17:18:03.17106713Z"
        }
        """.data(using: .utf8)!

        let predictionJSON = """
        {
            "id": "prediction-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "title": "Will this work?",
            "outcomes": [
                {
                    "id": "outcome-1",
                    "title": "Yes",
                    "color": "blue",
                    "users": 2,
                    "channel_points": 500,
                    "top_predictors": [
                        {
                            "user_id": "9001",
                            "user_login": "viewer",
                            "user_name": "Viewer",
                            "channel_points_won": 1000,
                            "channel_points_used": 500
                        }
                    ]
                }
            ],
            "winning_outcome_id": "outcome-1",
            "status": "resolved",
            "started_at": "2020-07-15T17:16:03.17106713Z",
            "locks_at": "2020-07-15T17:20:03.17106713Z",
            "locked_at": "2020-07-15T17:20:03.17106713Z",
            "ended_at": "2020-07-15T17:30:03.17106713Z"
        }
        """.data(using: .utf8)!

        let goalJSON = """
        {
            "id": "goal-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "type": "subscription",
            "description": "Sub goal",
            "current_amount": 42,
            "target_amount": 100,
            "started_at": "2020-07-15T17:16:03.17106713Z",
            "ended_at": null,
            "is_achieved": false
        }
        """.data(using: .utf8)!

        let pollEvent = EventSubEvent.decode(type: "channel.poll.end", payload: pollJSON)
        let predictionEvent = EventSubEvent.decode(type: "channel.prediction.end", payload: predictionJSON)
        let goalEvent = EventSubEvent.decode(type: "channel.goal.progress", payload: goalJSON)

        guard case .pollEnd(let poll) = pollEvent else {
            return XCTFail("Expected .pollEnd")
        }
        XCTAssertEqual(poll.title, "Choose the next game")
        XCTAssertEqual(poll.choices.first?.title, "Game A")

        guard case .predictionEnd(let prediction) = predictionEvent else {
            return XCTFail("Expected .predictionEnd")
        }
        XCTAssertEqual(prediction.winningOutcomeID, "outcome-1")
        XCTAssertEqual(prediction.outcomes.first?.topPredictors?.first?.userName, "Viewer")

        guard case .goalProgress(let goal) = goalEvent else {
            return XCTFail("Expected .goalProgress")
        }
        XCTAssertEqual(goal.currentAmount, 42)
    }

    func test_decodeTypedChatModerationAndCharityEvents() throws {
        let notificationJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "chatter_user_id": "9001",
            "chatter_user_login": "viewer",
            "chatter_user_name": "Viewer",
            "chatter_is_anonymous": false,
            "color": "#00FF7F",
            "badges": [],
            "system_message": "Viewer subscribed.",
            "message_id": "message-id",
            "message": { "text": "Nice", "fragments": [] },
            "notice_type": "sub",
            "sub": { "sub_tier": "1000", "is_prime": false, "duration_months": 1 }
        }
        """.data(using: .utf8)!

        let moderateJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "moderator_user_id": "4242",
            "moderator_user_login": "mod_user",
            "moderator_user_name": "Mod_User",
            "action": "ban",
            "user_id": "9001",
            "user_login": "viewer",
            "user_name": "Viewer",
            "ban": {
                "user_id": "9001",
                "user_login": "viewer",
                "user_name": "Viewer",
                "reason": "Spam"
            }
        }
        """.data(using: .utf8)!

        let charityJSON = """
        {
            "id": "campaign-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "charity_name": "Nice Charity",
            "charity_description": "Helping people",
            "charity_logo": "https://static.example/logo.png",
            "charity_website": "https://example.com",
            "current_amount": { "value": 5000, "decimal_places": 2, "currency": "USD" },
            "target_amount": { "value": 10000, "decimal_places": 2, "currency": "USD" },
            "started_at": "2020-07-15T17:16:03.17106713Z",
            "stopped_at": null
        }
        """.data(using: .utf8)!

        let notificationEvent = EventSubEvent.decode(type: "channel.chat.notification", payload: notificationJSON)
        let moderateEvent = EventSubEvent.decode(type: "channel.moderate", payload: moderateJSON)
        let charityEvent = EventSubEvent.decode(type: "channel.charity_campaign.progress", payload: charityJSON)

        guard case .chatNotification(let notification) = notificationEvent else {
            return XCTFail("Expected .chatNotification")
        }
        XCTAssertEqual(notification.noticeType, "sub")
        XCTAssertEqual(notification.sub?.subTier, .tier1)

        guard case .moderate(let moderate) = moderateEvent else {
            return XCTFail("Expected .moderate")
        }
        XCTAssertEqual(moderate.action, "ban")
        XCTAssertEqual(moderate.ban?.reason, "Spam")

        guard case .charityCampaignProgress(let charity) = charityEvent else {
            return XCTFail("Expected .charityCampaignProgress")
        }
        XCTAssertEqual(charity.charityName, "Nice Charity")
        XCTAssertEqual(charity.currentAmount.value, 5000)
    }

    func test_decodeRemainingTypedEventSubFamilies() throws {
        let automodJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "user_id": "9001",
            "user_login": "viewer",
            "user_name": "Viewer",
            "message_id": "message-id",
            "message": { "text": "blocked message", "fragments": [] },
            "category": "aggression",
            "level": 2,
            "status": "PENDING",
            "held_at": "2020-07-15T17:16:03.17106713Z",
            "reason": "Automod"
        }
        """.data(using: .utf8)!

        let bitsJSON = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "user_id": "9001",
            "user_login": "viewer",
            "user_name": "Viewer",
            "bits": 100,
            "type": "cheer",
            "message": { "text": "cheer100 nice", "fragments": [] }
        }
        """.data(using: .utf8)!

        let sharedChatJSON = """
        {
            "session_id": "session-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "host_broadcaster_user_id": "1234",
            "host_broadcaster_user_login": "host",
            "host_broadcaster_user_name": "Host",
            "participants": [
                {
                    "broadcaster_user_id": "1234",
                    "broadcaster_user_login": "host",
                    "broadcaster_user_name": "Host"
                }
            ],
            "started_at": "2020-07-15T17:16:03.17106713Z"
        }
        """.data(using: .utf8)!

        let whisperJSON = """
        {
            "from_user_id": "9001",
            "from_user_login": "viewer",
            "from_user_name": "Viewer",
            "to_user_id": "1337",
            "to_user_login": "cool_user",
            "to_user_name": "Cool_User",
            "whisper_id": "whisper-id",
            "whisper": { "text": "hello" }
        }
        """.data(using: .utf8)!

        let automodEvent = EventSubEvent.decode(type: "automod.message.hold", payload: automodJSON)
        let bitsEvent = EventSubEvent.decode(type: "channel.bits.use", payload: bitsJSON)
        let sharedChatEvent = EventSubEvent.decode(type: "channel.shared_chat.begin", payload: sharedChatJSON)
        let whisperEvent = EventSubEvent.decode(type: "user.whisper.message", payload: whisperJSON)

        guard case .automodMessageHold(let automod) = automodEvent else {
            return XCTFail("Expected .automodMessageHold")
        }
        XCTAssertEqual(automod.message.text, "blocked message")

        guard case .bitsUse(let bits) = bitsEvent else {
            return XCTFail("Expected .bitsUse")
        }
        XCTAssertEqual(bits.bits, 100)

        guard case .sharedChatBegin(let sharedChat) = sharedChatEvent else {
            return XCTFail("Expected .sharedChatBegin")
        }
        XCTAssertEqual(sharedChat.sessionID, "session-id")

        guard case .userWhisperMessage(let whisper) = whisperEvent else {
            return XCTFail("Expected .userWhisperMessage")
        }
        XCTAssertEqual(whisper.whisper.text, "hello")
    }

    func test_unknownEventDecodeFallsBackToRawPayload() {
        let data = #"{"future":true}"#.data(using: .utf8)!
        let event = EventSubEvent.decode(type: "channel.future", payload: data)

        guard case .unknown(let type, let payload) = event else {
            return XCTFail("Expected .unknown")
        }
        XCTAssertEqual(type, "channel.future")
        XCTAssertEqual(payload, data)
    }

    func test_knownEventTypesDecodeToKnownFallbackWhenSpecificModelIsUnavailable() {
        let payload = #"{"type":"known"}"#.data(using: .utf8)!

        for type in EventSubKnownEventType.allCases {
            let event = EventSubEvent.decode(type: type.rawValue, payload: payload)

            if case .unknown(let unknownType, _) = event {
                XCTFail("Expected \(unknownType) to decode as a known EventSub type")
            }
        }
    }
}
