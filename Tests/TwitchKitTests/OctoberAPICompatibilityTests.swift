import Foundation
import XCTest
@testable import TwitchKit

/// Decoding checks against the payload shapes in Twitch's EventSub reference,
/// subscription-type examples and Get Users reference as of the 2026-10-01 changelog.
final class OctoberAPICompatibilityTests: XCTestCase {
    private func event(_ type: String, _ json: String) -> EventSubEvent {
        EventSubEvent.decode(type: type, payload: Data(json.utf8))
    }

    // MARK: - channel.chat.notification

    /// The "Shared Chat Notification Example" from the channel.chat.notification docs,
    /// including its `sub_plan` tier key and missing `is_prime`.
    func testSharedChatNotificationDocsExampleDecodes() throws {
        let json = """
        {
            "broadcaster_user_id": "1971641",
            "broadcaster_user_login": "streamer",
            "broadcaster_user_name": "streamer",
            "chatter_user_id": "49912639",
            "chatter_user_login": "viewer23",
            "chatter_user_name": "viewer23",
            "chatter_is_anonymous": false,
            "color": "",
            "badges": [],
            "system_message": "viewer23 subscribed at Tier 1. They've subscribed for 10 months!",
            "message_id": "d62235c8-47ff-a4f4--84e8-5a29a65a9c03",
            "message": { "text": "", "fragments": [] },
            "notice_type": "shared_chat_resub",
            "sub": null, "resub": null, "sub_gift": null, "community_sub_gift": null,
            "gift_paid_upgrade": null, "prime_paid_upgrade": null, "pay_it_forward": null,
            "raid": null, "unraid": null, "announcement": null, "bits_badge_tier": null,
            "charity_donation": null, "watch_streak": null, "modiversary": null,
            "gifted_drops_summary": null,
            "shared_chat_sub": null,
            "shared_chat_resub": {
                "cumulative_months": 10,
                "duration_months": 0,
                "streak_months": null,
                "sub_plan": "1000",
                "is_gift": false,
                "gifter_is_anonymous": null,
                "gifter_user_id": null,
                "gifter_user_name": null,
                "gifter_user_login": null
            },
            "shared_chat_sub_gift": null, "shared_chat_community_sub_gift": null,
            "shared_chat_gift_paid_upgrade": null, "shared_chat_prime_paid_upgrade": null,
            "shared_chat_pay_it_forward": null, "shared_chat_raid": null,
            "shared_chat_unraid": null, "shared_chat_announcement": null,
            "shared_chat_bits_badge_tier": null, "shared_chat_charity_donation": null,
            "shared_chat_modiversary": null, "shared_chat_gifted_drops_summary": null,
            "source_broadcaster_user_id": "112233",
            "source_broadcaster_user_login": "streamer33",
            "source_broadcaster_user_name": "streamer33",
            "source_message_id": "2be7193d-0366-4453-b6ec-b288ce9f2c39",
            "source_badges": [{ "set_id": "subscriber", "id": "3", "info": "3" }],
            "is_source_only": true
        }
        """
        guard case .chatNotification(let notification) = event("channel.chat.notification", json) else {
            return XCTFail("Expected .chatNotification")
        }
        XCTAssertEqual(notification.noticeType, .sharedChatResub)
        XCTAssertEqual(notification.noticeType.rawValue, "shared_chat_resub")
        XCTAssertNil(notification.resub)
        XCTAssertEqual(notification.sharedChatResub?.cumulativeMonths, 10)
        XCTAssertEqual(notification.sharedChatResub?.subTier, .tier1)
        XCTAssertNil(notification.sharedChatResub?.isPrime)
        XCTAssertEqual(notification.sourceBroadcasterUserID, "112233")
        XCTAssertEqual(notification.sourceBroadcasterUserLogin, "streamer33")
        XCTAssertEqual(notification.sourceBroadcasterUserName, "streamer33")
        XCTAssertEqual(notification.sourceMessageID, "2be7193d-0366-4453-b6ec-b288ce9f2c39")
        XCTAssertEqual(notification.sourceBadges, [ChatBadge(setID: "subscriber", id: "3", info: "3")])
        XCTAssertEqual(notification.isSourceOnly, true)
    }

    func testGiftedDropsSummaryNoticesDecode() throws {
        for (noticeType, key) in [
            ("gifted_drops_summary", "gifted_drops_summary"),
            ("shared_chat_gifted_drops_summary", "shared_chat_gifted_drops_summary"),
        ] {
            let json = """
            {
                "broadcaster_user_id": "1971641",
                "broadcaster_user_login": "streamer",
                "broadcaster_user_name": "streamer",
                "chatter_user_id": "49912639",
                "chatter_user_login": "viewer23",
                "chatter_user_name": "viewer23",
                "badges": [],
                "system_message": "viewer23 gifted Drops to 25 viewers!",
                "message_id": "d62235c8-47ff-a4f4-84e8-5a29a65a9c03",
                "message": { "text": "", "fragments": [] },
                "notice_type": "\(noticeType)",
                "\(key)": { "recipient_count": 25 }
            }
            """
            guard case .chatNotification(let notification) = event("channel.chat.notification", json) else {
                return XCTFail("Expected .chatNotification for \(noticeType)")
            }
            XCTAssertEqual(notification.noticeType.rawValue, noticeType)
            if noticeType == "gifted_drops_summary" {
                XCTAssertEqual(notification.noticeType, .giftedDropsSummary)
                XCTAssertEqual(notification.giftedDropsSummary, .init(recipientCount: 25))
                XCTAssertNil(notification.sharedChatGiftedDropsSummary)
            } else {
                XCTAssertEqual(notification.noticeType, .sharedChatGiftedDropsSummary)
                XCTAssertEqual(notification.sharedChatGiftedDropsSummary?.recipientCount, 25)
                XCTAssertNil(notification.giftedDropsSummary)
            }
        }
    }

    /// A minimal payload without any of the new fields still decodes; `is_prime` may be absent.
    func testChatNotificationMinimalPayloadOmitsNewFields() throws {
        let json = """
        {
            "broadcaster_user_id": "1", "broadcaster_user_login": "b", "broadcaster_user_name": "B",
            "chatter_user_id": "2", "chatter_user_login": "c", "chatter_user_name": "C",
            "badges": [], "system_message": "C resubscribed", "message_id": "m",
            "message": { "text": "", "fragments": [] },
            "notice_type": "resub",
            "resub": { "cumulative_months": 3, "duration_months": 1, "sub_tier": "2000", "is_gift": false }
        }
        """
        guard case .chatNotification(let notification) = event("channel.chat.notification", json) else {
            return XCTFail("Expected .chatNotification")
        }
        XCTAssertEqual(notification.noticeType, "resub")
        XCTAssertEqual(notification.resub?.subTier, .tier2)
        XCTAssertNil(notification.resub?.isPrime)
        XCTAssertNil(notification.giftedDropsSummary)
        XCTAssertNil(notification.sourceBroadcasterUserID)
        XCTAssertNil(notification.sourceBadges)
        XCTAssertNil(notification.sharedChatSub)
        XCTAssertNil(notification.sharedChatRaid)
    }

    func testChatNoticeTypePreservesUnknownValues() throws {
        XCTAssertEqual(EventSubChatNoticeType(rawValue: "future_notice"), .unknown("future_notice"))
        XCTAssertEqual(EventSubChatNoticeType(rawValue: "future_notice").rawValue, "future_notice")
        // Twitch documents a literal `unknown` notice type; it round-trips through `.unknown`.
        XCTAssertEqual(EventSubChatNoticeType(rawValue: "unknown"), .unknown("unknown"))
        let decoded = try JSONDecoder().decode([EventSubChatNoticeType].self, from: Data(#"["shared_chat_pay_it_forward","x"]"#.utf8))
        XCTAssertEqual(decoded, [.sharedChatPayItForward, .unknown("x")])
        let encoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), #"["shared_chat_pay_it_forward","x"]"#)
    }

    // MARK: - channel.bits.use

    /// The channel.bits.use notification example from the docs.
    func testBitsUseDocsExampleDecodes() throws {
        let json = """
        {
            "user_id": "1234", "user_login": "cool_user", "user_name": "Cool_User",
            "broadcaster_user_id": "1337", "broadcaster_user_login": "cooler_user", "broadcaster_user_name": "Cooler_User",
            "bits": 2,
            "type": "cheer",
            "power_up": null,
            "custom_power_up": null,
            "message": {
                "text": "cheer1 hi cheer1",
                "fragments": [
                    { "type": "cheermote", "text": "cheer1", "cheermote": { "prefix": "cheer", "bits": 1, "tier": 1 }, "emote": null },
                    { "type": "text", "text": " hi ", "cheermote": null, "emote": null },
                    { "type": "cheermote", "text": "cheer1", "cheermote": { "prefix": "cheer", "bits": 1, "tier": 1 }, "emote": null }
                ]
            }
        }
        """
        guard case .bitsUse(let bits) = event("channel.bits.use", json) else {
            return XCTFail("Expected .bitsUse")
        }
        XCTAssertEqual(bits.type, .cheer)
        XCTAssertEqual(bits.type, "cheer")
        XCTAssertNil(bits.powerUp)
        XCTAssertNil(bits.customPowerUp)
        XCTAssertEqual(bits.message?.fragments.count, 3)
    }

    func testBitsUseCustomPowerUpAndPowerUpFieldsDecode() throws {
        let custom = """
        {
            "user_id": "1234", "user_login": "cool_user", "user_name": "Cool_User",
            "broadcaster_user_id": "1337", "broadcaster_user_login": "cooler_user", "broadcaster_user_name": "Cooler_User",
            "bits": 500,
            "type": "custom_power_up",
            "power_up": null,
            "custom_power_up": { "title": "Hydrate", "reward_id": "reward-1" },
            "message": null
        }
        """
        guard case .bitsUse(let customUse) = event("channel.bits.use", custom) else {
            return XCTFail("Expected .bitsUse for custom_power_up")
        }
        XCTAssertEqual(customUse.type, .customPowerUp)
        XCTAssertEqual(customUse.customPowerUp, .init(title: "Hydrate", rewardID: "reward-1"))

        // Power-up emotes carry only `id` and `name`, without the `emote_set_id` a chat fragment has.
        let powerUp = """
        {
            "user_id": "1234", "user_login": "cool_user", "user_name": "Cool_User",
            "broadcaster_user_id": "1337", "broadcaster_user_login": "cooler_user", "broadcaster_user_name": "Cooler_User",
            "bits": 100,
            "type": "power_up",
            "power_up": {
                "type": "message_effect",
                "emote": { "id": "emote-1", "name": "Kappa" },
                "message_effect_id": "cosmic-abyss"
            },
            "custom_power_up": null
        }
        """
        guard case .bitsUse(let powerUpUse) = event("channel.bits.use", powerUp) else {
            return XCTFail("Expected .bitsUse for power_up")
        }
        XCTAssertEqual(powerUpUse.type, .powerUp)
        XCTAssertEqual(powerUpUse.powerUp?.type, "message_effect")
        XCTAssertEqual(powerUpUse.powerUp?.emote, .init(id: "emote-1", name: "Kappa"))
        XCTAssertEqual(powerUpUse.powerUp?.messageEffectID, "cosmic-abyss")

        // Minimal: no message, power_up or custom_power_up keys, and an unknown type.
        let minimal = """
        {
            "user_id": "1", "user_login": "u", "user_name": "U",
            "broadcaster_user_id": "2", "broadcaster_user_login": "b", "broadcaster_user_name": "B",
            "bits": 1, "type": "combo"
        }
        """
        guard case .bitsUse(let minimalUse) = event("channel.bits.use", minimal) else {
            return XCTFail("Expected .bitsUse for minimal payload")
        }
        XCTAssertEqual(minimalUse.type, .unknown("combo"))
        XCTAssertEqual(minimalUse.type.rawValue, "combo")
        XCTAssertNil(minimalUse.message)
        XCTAssertNil(minimalUse.powerUp)
        XCTAssertNil(minimalUse.customPowerUp)
    }

    // MARK: - channel.follow v2

    func testFollowV2DocsExampleIncludesBroadcaster() throws {
        let json = """
        {
            "user_id": "1234",
            "user_login": "cool_user",
            "user_name": "Cool_User",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cooler_user",
            "broadcaster_user_name": "Cooler_User",
            "followed_at": "2020-07-15T18:16:11.17106713Z"
        }
        """
        guard case .follow(let follow) = event("channel.follow", json) else {
            return XCTFail("Expected .follow")
        }
        XCTAssertEqual(follow.userID, "1234")
        XCTAssertEqual(follow.broadcasterUserID, "1337")
        XCTAssertEqual(follow.broadcasterUserLogin, "cooler_user")
        XCTAssertEqual(follow.broadcasterUserName, "Cooler_User")

        let minimal = #"{"user_id":"1","user_name":"U","followed_at":"2020-07-15T18:16:11Z"}"#
        guard case .follow(let bare) = event("channel.follow", minimal) else {
            return XCTFail("Expected .follow for minimal payload")
        }
        XCTAssertNil(bare.broadcasterUserID)
        XCTAssertNil(bare.broadcasterUserLogin)
        XCTAssertNil(bare.broadcasterUserName)
    }

    // MARK: - Get Users

    func testGetUsersTypeDecodes() throws {
        let json = """
        {
            "id": "141981764",
            "login": "twitchdev",
            "display_name": "TwitchDev",
            "type": "",
            "broadcaster_type": "partner",
            "description": "Supporting third-party developers building Twitch integrations from chatbots to game integrations.",
            "profile_image_url": "https://static-cdn.jtvnw.net/jtv_user_pictures/8a6381c7-d0c0-4576-b179-38bd5ce1d6af-profile_image-300x300.png",
            "offline_image_url": "https://static-cdn.jtvnw.net/jtv_user_pictures/3f13ab61-ec78-4fe6-8481-8682cb3b0ac2-channel_offline_image-1920x1080.png",
            "view_count": 0,
            "email": "not-real@email.com",
            "created_at": "2016-12-14T20:32:28Z"
        }
        """
        let user = try JSONDecoder.twitch().decode(TwitchUser.self, from: Data(json.utf8))
        XCTAssertEqual(user.type, .normal)
        XCTAssertEqual(user.type?.rawValue, "")

        for (raw, expected) in [("admin", TwitchUserType.admin), ("global_mod", .globalMod), ("staff", .staff), ("partner_mod", .unknown("partner_mod"))] {
            let staff = json.replacingOccurrences(of: #""type": "","#, with: #""type": "\#(raw)","#)
            XCTAssertEqual(try JSONDecoder.twitch().decode(TwitchUser.self, from: Data(staff.utf8)).type, expected)
        }

        let minimal = #"{"id":"1","login":"a","display_name":"A","profile_image_url":"","broadcaster_type":""}"#
        XCTAssertNil(try JSONDecoder.twitch().decode(TwitchUser.self, from: Data(minimal.utf8)).type)
    }

    // MARK: - Required-vs-optional fixes from the EventSub reference spot-check

    /// channel.chat.user_message_hold has no `status` field (only the update event does).
    func testChatUserMessageHoldDocsExampleDecodesWithoutStatus() throws {
        let json = """
        {
            "broadcaster_user_id": "123", "broadcaster_user_login": "bob", "broadcaster_user_name": "Bob",
            "user_id": "456", "user_login": "tom", "user_name": "Tommy",
            "message_id": "789",
            "message": {
                "text": "hey world",
                "fragments": [
                    { "type": "emote", "text": "hey world", "cheermote": null, "emote": { "id": "foo", "emote_set_id": "7" } },
                    { "type": "cheermote", "text": "bye world", "cheermote": { "prefix": "prefix", "bits": 100, "tier": 1 }, "emote": null },
                    { "type": "text", "text": "surprise", "cheermote": null, "emote": null }
                ]
            }
        }
        """
        guard case .chatUserMessageHold(let hold) = event("channel.chat.user_message_hold", json) else {
            return XCTFail("Expected .chatUserMessageHold")
        }
        XCTAssertEqual(hold.messageID, "789")
        XCTAssertNil(hold.status)

        let update = json.replacingOccurrences(of: #""message_id": "789","#, with: #""status": "approved", "message_id": "789","#)
        guard case .chatUserMessageUpdate(let updated) = event("channel.chat.user_message_update", update) else {
            return XCTFail("Expected .chatUserMessageUpdate")
        }
        XCTAssertEqual(updated.status, .approved)
    }

    /// channel.subscription.message sends `message.emotes`, not chat fragments.
    func testSubscriptionMessageDocsExampleDecodes() throws {
        let json = """
        {
            "user_id": "1234", "user_login": "cool_user", "user_name": "Cool_User",
            "broadcaster_user_id": "1337", "broadcaster_user_login": "cooler_user", "broadcaster_user_name": "Cooler_User",
            "tier": "1000",
            "message": {
                "text": "Love the stream! FevziGG",
                "emotes": [ { "begin": 23, "end": 30, "id": "302976485" } ]
            },
            "cumulative_months": 15,
            "streak_months": 1,
            "duration_months": 6
        }
        """
        guard case .subscriptionMessage(let message) = event("channel.subscription.message", json) else {
            return XCTFail("Expected .subscriptionMessage")
        }
        XCTAssertEqual(message.message.text, "Love the stream! FevziGG")
        XCTAssertEqual(message.message.emotes, [.init(begin: 23, end: 30, id: "302976485")])

        let minimal = json
            .replacingOccurrences(of: #""emotes": [ { "begin": 23, "end": 30, "id": "302976485" } ]"#, with: #""emotes": null"#)
            .replacingOccurrences(of: #""streak_months": 1,"#, with: "")
        guard case .subscriptionMessage(let bare) = event("channel.subscription.message", minimal) else {
            return XCTFail("Expected .subscriptionMessage for minimal payload")
        }
        XCTAssertNil(bare.message.emotes)
        XCTAssertNil(bare.streakMonths)
    }

    /// Charity campaign start/progress/stop document `broadcaster_id`/`_login`/`_name`.
    func testCharityCampaignDocsExampleDecodesBroadcasterKeys() throws {
        let json = """
        {
            "id": "123-abc-456-def",
            "broadcaster_id": "123456",
            "broadcaster_name": "SunnySideUp",
            "broadcaster_login": "sunnysideup",
            "charity_name": "Example name",
            "charity_description": "Example description",
            "charity_logo": "https://abc.cloudfront.net/ppgf/1000/100.png",
            "charity_website": "https://www.example.com",
            "current_amount": { "value": 0, "decimal_places": 2, "currency": "USD" },
            "target_amount": { "value": 1500000, "decimal_places": 2, "currency": "USD" },
            "started_at": "2022-07-26T17:00:03.17106713Z"
        }
        """
        guard case .charityCampaignStart(let campaign) = event("channel.charity_campaign.start", json) else {
            return XCTFail("Expected .charityCampaignStart")
        }
        XCTAssertEqual(campaign.broadcasterUserID, "123456")
        XCTAssertEqual(campaign.broadcasterUserLogin, "sunnysideup")
        XCTAssertEqual(campaign.broadcasterUserName, "SunnySideUp")
        XCTAssertEqual(campaign.targetAmount.value, 1500000)
        XCTAssertNotNil(campaign.startedAt)
        XCTAssertNil(campaign.stoppedAt)
    }

    /// user.authorization.revoke sends null login and name when the user no longer exists.
    func testUserAuthorizationRevokeAcceptsNullUserFields() throws {
        let json = #"{"client_id":"crq72vsaoijkc83xx42hz6i37","user_id":"1337","user_login":null,"user_name":null}"#
        guard case .userAuthorizationRevoke(let revoke) = event("user.authorization.revoke", json) else {
            return XCTFail("Expected .userAuthorizationRevoke")
        }
        XCTAssertEqual(revoke.userID, "1337")
        XCTAssertNil(revoke.userLogin)
        XCTAssertNil(revoke.userName)

        let grant = #"{"client_id":"crq72vsaoijkc83xx42hz6i37","user_id":"1337","user_login":"cool_user","user_name":"Cool_User"}"#
        guard case .userAuthorizationGrant(let granted) = event("user.authorization.grant", grant) else {
            return XCTFail("Expected .userAuthorizationGrant")
        }
        XCTAssertEqual(granted.userLogin, "cool_user")
    }

    /// channel.guest_star_guest.update sends null guest fields and state when the slot is now empty.
    func testGuestStarGuestUpdateAcceptsEmptySlot() throws {
        let json = """
        {
            "broadcaster_user_id": "1337", "broadcaster_user_name": "Cool_User", "broadcaster_user_login": "cool_user",
            "session_id": "2KFRQbFtpmfyD3IevNRnCzOPRJI",
            "moderator_user_id": null, "moderator_user_name": null, "moderator_user_login": null,
            "guest_user_id": null, "guest_user_name": null, "guest_user_login": null,
            "slot_id": null, "state": null,
            "host_user_id": "1337", "host_user_name": "Cool_User", "host_user_login": "cool_user",
            "host_video_enabled": null, "host_audio_enabled": null, "host_volume": null
        }
        """
        guard case .guestStarGuestUpdate(let update) = event("channel.guest_star_guest.update", json) else {
            return XCTFail("Expected .guestStarGuestUpdate")
        }
        XCTAssertNil(update.guestUserID)
        XCTAssertNil(update.state)

        let slotted = json
            .replacingOccurrences(of: #""guest_user_id": null, "guest_user_name": null, "guest_user_login": null,"#, with: #""guest_user_id": "1234", "guest_user_name": "Cool_Guest", "guest_user_login": "cool_guest","#)
            .replacingOccurrences(of: #""slot_id": null, "state": null,"#, with: #""slot_id": "1", "state": "live","#)
        guard case .guestStarGuestUpdate(let live) = event("channel.guest_star_guest.update", slotted) else {
            return XCTFail("Expected .guestStarGuestUpdate for a slotted guest")
        }
        XCTAssertEqual(live.guestUserLogin, "cool_guest")
        XCTAssertEqual(live.state, .live)
    }

    /// The v2 automatic reward example: fragment emotes carry only `id`, and the reward
    /// reports `channel_points` and `emote` rather than v1's `cost` and `unlocked_emote`.
    func testAutomaticRewardRedemptionV2DocsExampleDecodes() throws {
        let json = """
        {
            "broadcaster_user_id": "12826", "broadcaster_user_name": "Twitch", "broadcaster_user_login": "twitch",
            "user_id": "141981764", "user_name": "TwitchDev", "user_login": "twitchdev",
            "id": "f024099a-e0fe-4339-9a0a-a706fb59f353",
            "reward": { "type": "send_highlighted_message", "channel_points": 100, "emote": null },
            "message": {
                "text": "Hello world! VoHiYo",
                "fragments": [
                    { "type": "text", "text": "Hello world! ", "emote": null },
                    { "type": "emote", "text": "VoHiYo", "emote": { "id": "81274" } }
                ]
            },
            "redeemed_at": "2024-08-12T21:14:34.260398045Z"
        }
        """
        guard case .channelPointsAutomaticRewardRedemptionAdd(let redemption) = event("channel.channel_points_automatic_reward_redemption.add", json) else {
            return XCTFail("Expected .channelPointsAutomaticRewardRedemptionAdd")
        }
        XCTAssertEqual(redemption.reward.type, "send_highlighted_message")
        XCTAssertEqual(redemption.reward.channelPoints, 100)
        XCTAssertNil(redemption.reward.emote)
        XCTAssertEqual(redemption.message?.text, "Hello world! VoHiYo")
        XCTAssertEqual(redemption.message?.fragments?.last?.type, .emote)
        XCTAssertEqual(redemption.message?.fragments?.last?.emote?.id, "81274")

        let gigantify = json
            .replacingOccurrences(of: #""type": "send_highlighted_message", "channel_points": 100, "emote": null"#, with: #""type": "gigantify_an_emote", "channel_points": 50, "emote": { "id": "81274", "name": "VoHiYo" }"#)
        guard case .channelPointsAutomaticRewardRedemptionAdd(let giant) = event("channel.channel_points_automatic_reward_redemption.add", gigantify) else {
            return XCTFail("Expected .channelPointsAutomaticRewardRedemptionAdd for gigantify")
        }
        XCTAssertEqual(giant.reward.emote, .init(id: "81274", name: "VoHiYo"))
    }
}
