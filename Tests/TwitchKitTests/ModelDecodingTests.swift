import XCTest
import Foundation
@testable import TwitchKit

/// Tests that TwitchKit models correctly decode real Twitch API JSON responses.
/// These tests use JSON payloads matching the actual Twitch Helix and EventSub formats
/// to catch any Codable mismatches before they hit production.
final class ModelDecodingTests: XCTestCase {

    // MARK: - TwitchUser

    func test_decodeTwitchUser() throws {
        let json = """
        {
            "id": "141981764",
            "login": "twitchdev",
            "display_name": "TwitchDev",
            "profile_image_url": "https://static-cdn.jtvnw.net/jtv_user_pictures/profile.png",
            "email": "not-real@example.com",
            "broadcaster_type": "partner",
            "description": "Twitch developer account",
            "offline_image_url": "https://static-cdn.jtvnw.net/jtv_user_pictures/offline.png",
            "created_at": "2021-07-30T20:32:28Z"
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder.twitch().decode(TwitchUser.self, from: json)

        XCTAssertEqual(user.id, "141981764")
        XCTAssertEqual(user.login, "twitchdev")
        XCTAssertEqual(user.displayName, "TwitchDev")
        XCTAssertEqual(user.email, "not-real@example.com")
        XCTAssertEqual(user.broadcasterType, "partner")
        XCTAssertEqual(user.description, "Twitch developer account")
    }

    func test_decodeTwitchUserMinimal() throws {
        let json = """
        {
            "id": "12345",
            "login": "testuser",
            "display_name": "TestUser",
            "profile_image_url": "https://example.com/img.png",
            "broadcaster_type": ""
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder.twitch().decode(TwitchUser.self, from: json)

        XCTAssertEqual(user.id, "12345")
        XCTAssertEqual(user.email, nil)
        XCTAssertEqual(user.description, nil)
        XCTAssertEqual(user.broadcasterType, "")
    }

    // MARK: - TwitchChannel

    func test_decodeTwitchChannel() throws {
        let json = """
        {
            "broadcaster_id": "141981764",
            "broadcaster_login": "twitchdev",
            "broadcaster_name": "TwitchDev",
            "title": "Building cool stuff",
            "game_name": "Science & Technology",
            "game_id": "509670",
            "tags": ["English", "Programming"],
            "broadcaster_language": "en",
            "delay": 0,
            "is_branded_content": false
        }
        """.data(using: .utf8)!

        let channel = try JSONDecoder.twitch().decode(TwitchChannel.self, from: json)

        XCTAssertEqual(channel.broadcasterID, "141981764")
        XCTAssertEqual(channel.title, "Building cool stuff")
        XCTAssertEqual(channel.gameName, "Science & Technology")
        XCTAssertEqual(channel.tags, ["English", "Programming"])
        XCTAssertEqual(channel.delay, 0)
    }

    // MARK: - ChatMessage

    func test_decodeChatMessage() throws {
        let json = """
        {
            "broadcaster_user_id": "1971641",
            "broadcaster_user_login": "streamer",
            "broadcaster_user_name": "streamer",
            "chatter_user_id": "4145994",
            "chatter_user_login": "viewer32",
            "chatter_user_name": "viewer32",
            "message_id": "cc106a89-1814-919d-454c-f4f2f970aae7",
            "message": {
                "text": "Hi chat",
                "fragments": [
                    {
                        "type": "text",
                        "text": "Hi chat",
                        "cheermote": null,
                        "emote": null,
                        "mention": null
                    }
                ]
            },
            "color": "#00FF7F",
            "badges": [
                {
                    "set_id": "moderator",
                    "id": "1",
                    "info": ""
                },
                {
                    "set_id": "subscriber",
                    "id": "12",
                    "info": "16"
                }
            ],
            "message_type": "text",
            "cheer": null,
            "reply": null,
            "channel_points_custom_reward_id": null,
            "source_broadcaster_user_id": null,
            "source_broadcaster_user_login": null,
            "source_broadcaster_user_name": null,
            "source_message_id": null,
            "source_badges": null
        }
        """.data(using: .utf8)!

        let msg = try JSONDecoder.twitch().decode(ChatMessage.self, from: json)

        XCTAssertEqual(msg.messageID, "cc106a89-1814-919d-454c-f4f2f970aae7")
        XCTAssertEqual(msg.id, msg.messageID)
        XCTAssertEqual(msg.broadcasterUserID, "1971641")
        XCTAssertEqual(msg.chatterUserLogin, "viewer32")
        XCTAssertEqual(msg.message.text, "Hi chat")
        XCTAssertEqual(msg.message.fragments.count, 1)
        XCTAssertEqual(msg.message.fragments[0].type, .text)
        XCTAssertEqual(msg.color, "#00FF7F")
        XCTAssertEqual(msg.badges.count, 2)
        XCTAssertEqual(msg.badges[0].setID, "moderator")
        XCTAssertEqual(msg.badges[1].info, "16")
        XCTAssertEqual(msg.messageType, .text)
        XCTAssertEqual(msg.cheer, nil)
        XCTAssertEqual(msg.reply, nil)
        XCTAssertEqual(msg.sourceBroadcasterUserID, nil)
    }

    func test_decodeChatMessageWithCheer() throws {
        let json = """
        {
            "broadcaster_user_id": "1971641",
            "broadcaster_user_login": "streamer",
            "broadcaster_user_name": "streamer",
            "chatter_user_id": "4145994",
            "chatter_user_login": "viewer32",
            "chatter_user_name": "viewer32",
            "message_id": "abc-123",
            "message": {
                "text": "Cheer100 nice!",
                "fragments": [
                    {
                        "type": "cheermote",
                        "text": "Cheer100",
                        "cheermote": { "prefix": "Cheer", "bits": 100, "tier": 1 },
                        "emote": null,
                        "mention": null
                    },
                    {
                        "type": "text",
                        "text": " nice!",
                        "cheermote": null,
                        "emote": null,
                        "mention": null
                    }
                ]
            },
            "color": "#FF0000",
            "badges": [],
            "message_type": "text",
            "cheer": { "bits": 100 },
            "reply": null,
            "channel_points_custom_reward_id": null,
            "source_broadcaster_user_id": null,
            "source_broadcaster_user_login": null,
            "source_broadcaster_user_name": null,
            "source_message_id": null,
            "source_badges": null
        }
        """.data(using: .utf8)!

        let msg = try JSONDecoder.twitch().decode(ChatMessage.self, from: json)

        XCTAssertEqual(msg.cheer?.bits, 100)
        XCTAssertEqual(msg.message.fragments[0].cheermote?.prefix, "Cheer")
        XCTAssertEqual(msg.message.fragments[0].cheermote?.bits, 100)
    }

    func test_decodeChatMessageSharedChat() throws {
        let json = """
        {
            "broadcaster_user_id": "1971641",
            "broadcaster_user_login": "streamer",
            "broadcaster_user_name": "streamer",
            "chatter_user_id": "4145994",
            "chatter_user_login": "viewer32",
            "chatter_user_name": "viewer32",
            "message_id": "shared-123",
            "message": { "text": "From another channel!", "fragments": [] },
            "color": "#FFFFFF",
            "badges": [],
            "message_type": "text",
            "cheer": null,
            "reply": null,
            "channel_points_custom_reward_id": null,
            "source_broadcaster_user_id": "9999999",
            "source_broadcaster_user_login": "otherchannel",
            "source_broadcaster_user_name": "OtherChannel",
            "source_message_id": "original-456",
            "source_badges": [{ "set_id": "subscriber", "id": "1", "info": "3" }]
        }
        """.data(using: .utf8)!

        let msg = try JSONDecoder.twitch().decode(ChatMessage.self, from: json)

        XCTAssertEqual(msg.sourceBroadcasterUserID, "9999999")
        XCTAssertEqual(msg.sourceBroadcasterUserLogin, "otherchannel")
        XCTAssertEqual(msg.sourceMessageID, "original-456")
        XCTAssertEqual(msg.sourceBadges?.count, 1)
        XCTAssertEqual(msg.sourceBadges?[0].setID, "subscriber")
    }

    // MARK: - TwitchEmote

    func test_decodeGlobalEmote() throws {
        let json = """
        {
            "id": "25",
            "name": "Kappa",
            "images": {
                "url_1x": "https://static-cdn.jtvnw.net/emoticons/v2/25/static/light/1.0",
                "url_2x": "https://static-cdn.jtvnw.net/emoticons/v2/25/static/light/2.0",
                "url_4x": "https://static-cdn.jtvnw.net/emoticons/v2/25/static/light/3.0"
            },
            "format": ["static"],
            "scale": ["1.0", "2.0", "3.0"],
            "theme_mode": ["light", "dark"],
            "template": "https://static-cdn.jtvnw.net/emoticons/v2/{{id}}/{{format}}/{{theme_mode}}/{{scale}}"
        }
        """.data(using: .utf8)!

        let emote = try JSONDecoder.twitch().decode(TwitchEmote.self, from: json)

        XCTAssertEqual(emote.id, "25")
        XCTAssertEqual(emote.name, "Kappa")
        XCTAssertEqual(emote.format, ["static"])
        XCTAssertEqual(emote.tier, nil)
        XCTAssertEqual(emote.emoteType, nil)
    }

    func test_decodeChannelEmote() throws {
        let json = """
        {
            "id": "304456832",
            "name": "twitchdevPitchfork",
            "images": {
                "url_1x": "https://static-cdn.jtvnw.net/emoticons/v2/304456832/static/light/1.0",
                "url_2x": "https://static-cdn.jtvnw.net/emoticons/v2/304456832/static/light/2.0",
                "url_4x": "https://static-cdn.jtvnw.net/emoticons/v2/304456832/static/light/3.0"
            },
            "tier": "1000",
            "emote_type": "subscriptions",
            "emote_set_id": "301590448",
            "format": ["static", "animated"],
            "scale": ["1.0", "2.0", "3.0"],
            "theme_mode": ["light", "dark"]
        }
        """.data(using: .utf8)!

        let emote = try JSONDecoder.twitch().decode(TwitchEmote.self, from: json)

        XCTAssertEqual(emote.tier, "1000")
        XCTAssertEqual(emote.emoteType, "subscriptions")
        XCTAssertEqual(emote.emoteSetID, "301590448")
        XCTAssertTrue(emote.format.contains("animated"))
        XCTAssertNil(emote.template)
    }

    func test_emoteImageURL() throws {
        let emote = TwitchEmote(
            id: "25", name: "Kappa", images: nil,
            format: ["static"], scale: ["3.0"], themeMode: ["dark"],
            template: "https://static-cdn.jtvnw.net/emoticons/v2/{{id}}/{{format}}/{{theme_mode}}/{{scale}}",
            tier: nil, emoteType: nil, emoteSetID: nil
        )

        let url = try XCTUnwrap(emote.imageURL(format: "static", theme: "dark", scale: "3.0"))
        XCTAssertEqual(url.absoluteString, "https://static-cdn.jtvnw.net/emoticons/v2/25/static/dark/3.0")
    }

    func test_emoteImageURLFallback() throws {
        let emote = TwitchEmote(
            id: "304456832", name: "test", images: nil,
            format: ["static"], scale: ["1.0"], themeMode: ["dark"],
            template: nil, tier: nil, emoteType: nil, emoteSetID: nil
        )

        let url = try XCTUnwrap(emote.imageURL(format: "animated", theme: "light", scale: "2.0"))
        XCTAssertEqual(url.absoluteString, "https://static-cdn.jtvnw.net/emoticons/v2/304456832/animated/light/2.0")
    }

    // MARK: - TwitchBadgeSet

    func test_decodeBadgeSet() throws {
        let json = """
        {
            "set_id": "subscriber",
            "versions": [
                {
                    "id": "0",
                    "image_url_1x": "https://static-cdn.jtvnw.net/badges/sub/0/1",
                    "image_url_2x": "https://static-cdn.jtvnw.net/badges/sub/0/2",
                    "image_url_4x": "https://static-cdn.jtvnw.net/badges/sub/0/4",
                    "title": "Subscriber",
                    "description": "Subscriber",
                    "click_action": "subscribe_to_channel",
                    "click_url": null
                },
                {
                    "id": "12",
                    "image_url_1x": "https://static-cdn.jtvnw.net/badges/sub/12/1",
                    "image_url_2x": "https://static-cdn.jtvnw.net/badges/sub/12/2",
                    "image_url_4x": "https://static-cdn.jtvnw.net/badges/sub/12/4",
                    "title": "12-Month Subscriber",
                    "description": "12-Month Subscriber",
                    "click_action": "subscribe_to_channel",
                    "click_url": null
                }
            ]
        }
        """.data(using: .utf8)!

        let badgeSet = try JSONDecoder.twitch().decode(TwitchBadgeSet.self, from: json)

        XCTAssertEqual(badgeSet.setID, "subscriber")
        XCTAssertEqual(badgeSet.versions.count, 2)
        XCTAssertEqual(badgeSet.versions[0].id, "0")
        XCTAssertEqual(badgeSet.versions[0].title, "Subscriber")
        XCTAssertEqual(badgeSet.versions[1].id, "12")
        XCTAssertEqual(badgeSet.versions[1].clickAction, .subscribeToChannel)
        XCTAssertEqual(badgeSet.versions[1].clickURL, nil)
    }

    // MARK: - TwitchFollow

    func test_decodeTwitchFollow() throws {
        let json = """
        {
            "user_id": "1234",
            "user_login": "newviewer",
            "user_name": "NewViewer",
            "followed_at": "2023-11-06T18:11:47Z"
        }
        """.data(using: .utf8)!

        let follow = try JSONDecoder.twitch().decode(TwitchFollow.self, from: json)

        XCTAssertEqual(follow.userID, "1234")
        XCTAssertEqual(follow.userName, "NewViewer")
        XCTAssertEqual(follow.followedAt, try XCTUnwrap(TwitchDateParser.date(from: "2023-11-06T18:11:47Z")))
    }

    // MARK: - TwitchSubscription

    func test_decodeTwitchSubscription() throws {
        let json = """
        {
            "user_id": "5678",
            "user_login": "subscrber",
            "user_name": "Subscrber",
            "tier": "1000",
            "is_gift": false
        }
        """.data(using: .utf8)!

        let sub = try JSONDecoder.twitch().decode(TwitchSubscription.self, from: json)

        XCTAssertEqual(sub.userID, "5678")
        XCTAssertEqual(sub.tier, .tier1)
        XCTAssertEqual(sub.isGift, false)
    }

    func test_decodeGiftedSubscription() throws {
        let json = """
        {
            "user_id": "9999",
            "user_name": "LuckyViewer",
            "tier": "2000",
            "is_gift": true
        }
        """.data(using: .utf8)!

        let sub = try JSONDecoder.twitch().decode(TwitchSubscription.self, from: json)

        XCTAssertEqual(sub.tier, .tier2)
        XCTAssertEqual(sub.isGift, true)
    }

    // MARK: - TwitchStream

    func test_decodeTwitchStream() throws {
        let json = """
        {
            "id": "stream-1",
            "user_id": "123",
            "user_login": "twitchdev",
            "user_name": "TwitchDev",
            "game_id": "493057",
            "game_name": "PUBG: BATTLEGROUNDS",
            "type": "live",
            "title": "Building TwitchKit",
            "tags": ["Swift", "API"],
            "viewer_count": 42,
            "started_at": "2024-01-01T00:00:00Z",
            "language": "en",
            "thumbnail_url": "https://example.com/{width}x{height}.jpg",
            "is_mature": false
        }
        """.data(using: .utf8)!

        let stream = try JSONDecoder.twitch().decode(TwitchStream.self, from: json)

        XCTAssertEqual(stream.userLogin, "twitchdev")
        XCTAssertEqual(stream.tags, ["Swift", "API"])
        XCTAssertEqual(stream.type, .live)
        XCTAssertEqual(stream.viewerCount, 42)
        XCTAssertEqual(stream.language, "en")
    }

    /// Twitch returns `"tags": null` for streams that have no tags set.
    /// The non-optional `[String]` must tolerate this and decode to `[]`.
    func test_decodeTwitchStream_nullTags() throws {
        let json = """
        {
            "id": "stream-1",
            "user_id": "123",
            "user_login": "twitchdev",
            "user_name": "TwitchDev",
            "game_id": "",
            "game_name": "",
            "type": "live",
            "title": "No tags here",
            "tags": null,
            "viewer_count": 42,
            "started_at": "2024-01-01T00:00:00Z",
            "language": "en",
            "thumbnail_url": "https://example.com/{width}x{height}.jpg",
            "is_mature": false
        }
        """.data(using: .utf8)!

        let stream = try JSONDecoder.twitch().decode(TwitchStream.self, from: json)
        XCTAssertEqual(stream.tags, [])
    }

    // MARK: - TwitchGame

    func test_decodeTwitchGame() throws {
        let json = """
        {
            "id": "493057",
            "name": "PUBG: BATTLEGROUNDS",
            "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/493057-{width}x{height}.jpg",
            "igdb_id": "27789"
        }
        """.data(using: .utf8)!

        let game = try JSONDecoder.twitch().decode(TwitchGame.self, from: json)

        XCTAssertEqual(game.id, "493057")
        XCTAssertEqual(game.name, "PUBG: BATTLEGROUNDS")
        XCTAssertEqual(game.igdbID, "27789")
    }

    // MARK: - HelixResponse

    func test_decodeHelixResponse() throws {
        let json = """
        {
            "data": [
                { "id": "1", "login": "user1", "display_name": "User1", "profile_image_url": "", "broadcaster_type": "" },
                { "id": "2", "login": "user2", "display_name": "User2", "profile_image_url": "", "broadcaster_type": "" }
            ],
            "pagination": { "cursor": "abc123" }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.twitch().decode(HelixResponse<TwitchUser>.self, from: json)

        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.data[0].login, "user1")
        XCTAssertEqual(response.pagination?.cursor, "abc123")
    }

    func test_decodeHelixResponseNoPagination() throws {
        let json = """
        {
            "data": [
                { "id": "1", "login": "user1", "display_name": "User1", "profile_image_url": "", "broadcaster_type": "" }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.twitch().decode(HelixResponse<TwitchUser>.self, from: json)

        XCTAssertEqual(response.data.count, 1)
        XCTAssertNil(response.pagination)
    }

    // MARK: - SearchChannel

    /// GET /search/channels returns `"started_at": ""` — an empty string,
    /// NOT null and NOT an absent key — for channels that aren't live.
    /// (Documented: "The string is empty if the broadcaster is not
    /// streaming live.") `Date?` alone doesn't survive that: the key is
    /// present, so the decoder runs the date strategy on "" and throws,
    /// failing the entire results page for any search that includes one
    /// offline channel — i.e. almost every search.
    func test_decodeSearchChannelOffline_emptyStartedAt() throws {
        let json = """
        {
            "broadcaster_language": "en",
            "broadcaster_login": "loserfruit",
            "display_name": "Loserfruit",
            "game_id": "498000",
            "game_name": "House Flipper",
            "id": "41245072",
            "is_live": false,
            "tag_ids": [],
            "tags": ["English"],
            "thumbnail_url": "https://static-cdn.jtvnw.net/jtv_user_pictures/profile.png",
            "title": "loserfruit",
            "started_at": ""
        }
        """.data(using: .utf8)!

        let channel = try JSONDecoder.twitch().decode(SearchChannel.self, from: json)

        XCTAssertEqual(channel.broadcasterLogin, "loserfruit")
        XCTAssertFalse(channel.isLive)
        XCTAssertNil(channel.startedAt)
    }

    func test_decodeSearchChannelLive_parsesStartedAt() throws {
        let json = """
        {
            "broadcaster_language": "en",
            "broadcaster_login": "a_seagull",
            "display_name": "A_Seagull",
            "game_id": "506442",
            "game_name": "DOOM Eternal",
            "id": "19070311",
            "is_live": true,
            "tag_ids": [],
            "tags": ["English"],
            "thumbnail_url": "https://static-cdn.jtvnw.net/jtv_user_pictures/profile.png",
            "title": "I hate headaches",
            "started_at": "2020-03-18T17:56:00Z"
        }
        """.data(using: .utf8)!

        let channel = try JSONDecoder.twitch().decode(SearchChannel.self, from: json)

        XCTAssertTrue(channel.isLive)
        XCTAssertNotNil(channel.startedAt)
    }

    // MARK: - ShieldModeStatus

    /// GET /moderation/shield_mode returns `"last_activated_at": ""` — an
    /// empty string, NOT null — for broadcasters who have never activated
    /// Shield Mode, which would make the date strategy throw.
    func test_decodeShieldModeStatusNeverActivated_emptyLastActivatedAt() throws {
        let json = """
        {
            "is_active": false,
            "moderator_id": "",
            "moderator_name": "",
            "moderator_login": "",
            "last_activated_at": ""
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder.twitch().decode(ShieldModeStatus.self, from: json)

        XCTAssertFalse(status.isActive)
        XCTAssertNil(status.lastActivatedAt)
    }

    func test_decodeShieldModeStatusActivated_parsesLastActivatedAt() throws {
        let json = """
        {
            "is_active": true,
            "moderator_id": "98765",
            "moderator_name": "SimplySimple",
            "moderator_login": "simplysimple",
            "last_activated_at": "2023-08-01T18:11:47Z"
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder.twitch().decode(ShieldModeStatus.self, from: json)

        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.moderatorLogin, "simplysimple")
        XCTAssertEqual(status.lastActivatedAt, try XCTUnwrap(TwitchDateParser.date(from: "2023-08-01T18:11:47Z")))
    }

    // MARK: - AdSchedule

    /// GET /channels/ads returns `""` — an empty string, NOT null — for
    /// `snooze_refresh_at`, `next_ad_at`, and `last_ad_at` when the channel
    /// is offline or has never run an ad.
    func test_decodeAdScheduleOffline_emptyDateStrings() throws {
        let json = """
        {
            "snooze_count": 3,
            "snooze_refresh_at": "",
            "next_ad_at": "",
            "duration": 0,
            "last_ad_at": "",
            "preroll_free_time": 0
        }
        """.data(using: .utf8)!

        let schedule = try JSONDecoder.twitch().decode(AdSchedule.self, from: json)

        XCTAssertEqual(schedule.snoozeCount, 3)
        XCTAssertNil(schedule.snoozeRefreshAt)
        XCTAssertNil(schedule.nextAdAt)
        XCTAssertNil(schedule.lastAdAt)
        XCTAssertEqual(schedule.duration, 0)
        XCTAssertEqual(schedule.prerollFreeTime, 0)
    }

    func test_decodeAdScheduleLive_parsesDates() throws {
        let json = """
        {
            "snooze_count": 1,
            "snooze_refresh_at": "2024-01-01T01:00:00Z",
            "next_ad_at": "2024-01-01T00:30:00Z",
            "duration": 60,
            "last_ad_at": "2024-01-01T00:00:00Z",
            "preroll_free_time": 90
        }
        """.data(using: .utf8)!

        let schedule = try JSONDecoder.twitch().decode(AdSchedule.self, from: json)

        XCTAssertEqual(schedule.snoozeRefreshAt, try XCTUnwrap(TwitchDateParser.date(from: "2024-01-01T01:00:00Z")))
        XCTAssertEqual(schedule.nextAdAt, try XCTUnwrap(TwitchDateParser.date(from: "2024-01-01T00:30:00Z")))
        XCTAssertEqual(schedule.lastAdAt, try XCTUnwrap(TwitchDateParser.date(from: "2024-01-01T00:00:00Z")))
        XCTAssertEqual(schedule.duration, 60)
    }

    func test_decodeAdSnoozeToleratesEmptyDateStrings() throws {
        // Same Twitch quirk AdSchedule already tolerates: date fields can be
        // empty strings instead of absent, and one bad field must not fail
        // the whole decode.
        let json = """
        {
            "snooze_count": 3,
            "snooze_refresh_at": "",
            "next_ad_at": ""
        }
        """.data(using: .utf8)!

        let snooze = try JSONDecoder.twitch().decode(AdSnooze.self, from: json)

        XCTAssertEqual(snooze.snoozeCount, 3)
        XCTAssertNil(snooze.snoozeRefreshAt)
        XCTAssertNil(snooze.nextAdAt)
    }

    // MARK: - CustomReward

    /// Real payload shape from the Get Custom Reward docs: `default_image` uses
    /// `url_1x`/`url_2x`/`url_4x` and each limit setting carries its value under
    /// an endpoint-specific key (`max_per_stream`, `max_per_user_per_stream`).
    private static let customRewardJSON = """
    {
        "broadcaster_name": "torpedo09",
        "broadcaster_login": "torpedo09",
        "broadcaster_id": "274637212",
        "id": "92af127c-7326-4483-a52b-b0da0be61c01",
        "image": null,
        "background_color": "#00E5CB",
        "is_enabled": true,
        "cost": 50000,
        "title": "game analysis",
        "prompt": "",
        "is_user_input_required": false,
        "max_per_stream_setting": {
            "is_enabled": true,
            "max_per_stream": 3
        },
        "max_per_user_per_stream_setting": {
            "is_enabled": true,
            "max_per_user_per_stream": 1
        },
        "global_cooldown_setting": {
            "is_enabled": true,
            "global_cooldown_seconds": 300
        },
        "is_paused": false,
        "is_in_stock": true,
        "default_image": {
            "url_1x": "https://static-cdn.jtvnw.net/custom-reward-images/default-1.png",
            "url_2x": "https://static-cdn.jtvnw.net/custom-reward-images/default-2.png",
            "url_4x": "https://static-cdn.jtvnw.net/custom-reward-images/default-4.png"
        },
        "should_redemptions_skip_request_queue": false,
        "redemptions_redeemed_current_stream": null,
        "cooldown_expires_at": null
    }
    """.data(using: .utf8)!

    func test_decodeCustomReward_defaultImageURLs() throws {
        let reward = try JSONDecoder.twitch().decode(CustomReward.self, from: Self.customRewardJSON)

        XCTAssertEqual(reward.defaultImage.url1X, "https://static-cdn.jtvnw.net/custom-reward-images/default-1.png")
        XCTAssertEqual(reward.defaultImage.url2X, "https://static-cdn.jtvnw.net/custom-reward-images/default-2.png")
        XCTAssertEqual(reward.defaultImage.url4X, "https://static-cdn.jtvnw.net/custom-reward-images/default-4.png")
        XCTAssertNil(reward.image)
    }

    func test_decodeCustomReward_limitSettingValues() throws {
        let reward = try JSONDecoder.twitch().decode(CustomReward.self, from: Self.customRewardJSON)

        XCTAssertTrue(reward.maxPerStreamSetting.isEnabled)
        XCTAssertEqual(reward.maxPerStreamSetting.value, 3)
        XCTAssertTrue(reward.maxPerUserPerStreamSetting.isEnabled)
        XCTAssertEqual(reward.maxPerUserPerStreamSetting.value, 1)
        XCTAssertEqual(reward.globalCooldownSetting.globalCooldownSeconds, 300)
    }
}
