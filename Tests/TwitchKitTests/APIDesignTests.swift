import XCTest
@testable import TwitchKit

final class APIDesignTests: XCTestCase {
    func test_authScopesSeparateDefaultsFromCompleteCatalog() {
        XCTAssertTrue(TwitchAuth.allScopes.contains("analytics:read:extensions"))
        XCTAssertTrue(TwitchAuth.defaultScopes.contains("user:read:email"))
        XCTAssertFalse(TwitchAuth.defaultScopes.contains("analytics:read:extensions"))
        XCTAssertLessThan(TwitchAuth.defaultScopes.count, TwitchAuth.allScopes.count)
    }

    func test_authURLsAcceptTypedScopes() {
        let auth = TwitchAuth(clientId: "client-id")

        let url = auth.implicitGrantURL(scopes: [.userReadEmail, .userReadChat])
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scope = components?.queryItems?.first { $0.name == "scope" }?.value

        XCTAssertEqual(scope, "user:read:email user:read:chat")
    }

    func test_rawScopeEscapeHatchAllowsFutureTwitchScopes() {
        let auth = TwitchAuth(clientId: "client-id")

        let url = auth.implicitGrantURL(rawScopes: ["future:scope"])
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scope = components?.queryItems?.first { $0.name == "scope" }?.value

        XCTAssertEqual(scope, "future:scope")
    }

    func test_channelInfoUpdateEncodesOnlyProvidedFields() throws {
        let update = ChannelInfoUpdate(title: "New title", tags: [])

        let data = try JSONEncoder.twitch().encode(update)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["title"] as? String, "New title")
        XCTAssertEqual(object["tags"] as? [String], [])
        XCTAssertNil(object["game_id"])
    }

    func test_eventSubFactoriesUseMakePrefix() {
        let subscription = EventSubSubscription.makeChannelChatMessage(
            broadcasterID: "broadcaster",
            userID: "user"
        )

        XCTAssertEqual(subscription.type, "channel.chat.message")
        XCTAssertEqual(subscription.version, "1")
        XCTAssertEqual(subscription.condition["broadcaster_user_id"], "broadcaster")
        XCTAssertEqual(subscription.condition["user_id"], "user")
    }

    func test_eventSubFactoriesAreGroupedByDomain() {
        let channelUpdate = EventSubSubscription.Channel.update(broadcasterID: "broadcaster")
        XCTAssertEqual(channelUpdate.type, "channel.update")
        XCTAssertEqual(channelUpdate.version, "2")
        XCTAssertEqual(channelUpdate.condition["broadcaster_user_id"], "broadcaster")

        let raid = EventSubSubscription.Channel.raid(toBroadcasterID: "target")
        XCTAssertEqual(raid.type, "channel.raid")
        XCTAssertEqual(raid.condition["to_broadcaster_user_id"], "target")

        let redemption = EventSubSubscription.ChannelPoints.customRewardRedemptionAdd(
            broadcasterID: "broadcaster",
            rewardID: "reward"
        )
        XCTAssertEqual(redemption.type, "channel.channel_points_custom_reward_redemption.add")
        XCTAssertEqual(redemption.condition["broadcaster_user_id"], "broadcaster")
        XCTAssertEqual(redemption.condition["reward_id"], "reward")

        let streamOnline = EventSubSubscription.Stream.online(broadcasterID: "broadcaster")
        XCTAssertEqual(streamOnline.type, "stream.online")
        XCTAssertEqual(streamOnline.condition["broadcaster_user_id"], "broadcaster")
    }

    func test_eventSubFactoriesCoverImportantChatAndModerationEvents() {
        let clear = EventSubSubscription.Chat.clear(broadcasterID: "broadcaster", userID: "bot")
        XCTAssertEqual(clear.type, "channel.chat.clear")
        XCTAssertEqual(clear.condition["user_id"], "bot")

        let automod = EventSubSubscription.Moderation.automodMessageHold(
            broadcasterID: "broadcaster",
            moderatorID: "moderator"
        )
        XCTAssertEqual(automod.type, "automod.message.hold")
        XCTAssertEqual(automod.version, "2")
        XCTAssertEqual(automod.condition["moderator_user_id"], "moderator")

        let warning = EventSubSubscription.Moderation.warningSend(
            broadcasterID: "broadcaster",
            moderatorID: "moderator"
        )
        XCTAssertEqual(warning.type, "channel.warning.send")
        XCTAssertEqual(warning.condition["broadcaster_user_id"], "broadcaster")
    }

    func test_eventSubFactoriesCoverImportantChannelLifecycleEvents() {
        XCTAssertEqual(EventSubSubscription.Channel.subscriptionGift(broadcasterID: "broadcaster").type, "channel.subscription.gift")
        XCTAssertEqual(EventSubSubscription.Channel.sharedChatBegin(broadcasterID: "broadcaster").type, "channel.shared_chat.begin")
        XCTAssertEqual(EventSubSubscription.Channel.pollBegin(broadcasterID: "broadcaster").type, "channel.poll.begin")
        XCTAssertEqual(EventSubSubscription.Channel.predictionEnd(broadcasterID: "broadcaster").type, "channel.prediction.end")
        XCTAssertEqual(EventSubSubscription.Channel.hypeTrainBegin(broadcasterID: "broadcaster").version, "2")
        XCTAssertEqual(EventSubSubscription.Channel.charityDonation(broadcasterID: "broadcaster").type, "channel.charity_campaign.donate")
    }

    func test_eventSubFactoriesCoverSpecializedSubscriptionTypes() {
        let guestStar = EventSubSubscription.GuestStar.sessionBegin(
            broadcasterID: "broadcaster",
            moderatorID: "moderator"
        )
        XCTAssertEqual(guestStar.type, "channel.guest_star_session.begin")
        XCTAssertEqual(guestStar.version, "beta")

        let drop = EventSubSubscription.Drop.entitlementGrant(organizationID: "organization", categoryID: "category")
        XCTAssertEqual(drop.type, "drop.entitlement.grant")
        XCTAssertEqual(drop.condition["category_id"], "category")
        XCTAssertEqual(drop.isBatchingEnabled, true)

        let conduit = EventSubSubscription.Conduit.shardDisabled(clientID: "client", conduitID: "conduit")
        XCTAssertEqual(conduit.type, "conduit.shard.disabled")
        XCTAssertEqual(conduit.condition["client_id"], "client")
        XCTAssertEqual(conduit.condition["conduit_id"], "conduit")
        XCTAssertEqual(EventSubSubscription.Extension.bitsTransactionCreate(extensionClientID: "extension").condition["extension_client_id"], "extension")
        XCTAssertEqual(EventSubSubscription.ChannelPoints.customPowerUpRedemptionAdd(broadcasterID: "broadcaster").version, "1")
    }

    func test_eventSubFactoriesCoverCurrentTwitchSubscriptionTypes() {
        let broadcaster = "broadcaster"
        let moderator = "moderator"
        let user = "user"
        let subscriptions = [
            EventSubSubscription.Moderation.automodMessageHoldV1(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.automodMessageHold(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.automodMessageUpdateV1(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.automodMessageUpdate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.automodSettingsUpdate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.automodTermsUpdate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Channel.bitsUse(broadcasterID: broadcaster),
            EventSubSubscription.Channel.update(broadcasterID: broadcaster),
            EventSubSubscription.Channel.follow(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Channel.adBreakBegin(broadcasterID: broadcaster),
            EventSubSubscription.Chat.clear(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.clearUserMessages(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.message(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.messageDelete(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.notification(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.settingsUpdate(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.userMessageHold(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Chat.userMessageUpdate(broadcasterID: broadcaster, userID: user),
            EventSubSubscription.Channel.sharedChatBegin(broadcasterID: broadcaster),
            EventSubSubscription.Channel.sharedChatUpdate(broadcasterID: broadcaster),
            EventSubSubscription.Channel.sharedChatEnd(broadcasterID: broadcaster),
            EventSubSubscription.Channel.subscribe(broadcasterID: broadcaster),
            EventSubSubscription.Channel.subscriptionEnd(broadcasterID: broadcaster),
            EventSubSubscription.Channel.subscriptionGift(broadcasterID: broadcaster),
            EventSubSubscription.Channel.subscriptionMessage(broadcasterID: broadcaster),
            EventSubSubscription.Channel.cheer(broadcasterID: broadcaster),
            EventSubSubscription.Channel.raid(toBroadcasterID: broadcaster),
            EventSubSubscription.Moderation.ban(broadcasterID: broadcaster),
            EventSubSubscription.Moderation.unban(broadcasterID: broadcaster),
            EventSubSubscription.Moderation.unbanRequestCreate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.unbanRequestResolve(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.moderateV1(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.moderate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.moderatorAdd(broadcasterID: broadcaster),
            EventSubSubscription.Moderation.moderatorRemove(broadcasterID: broadcaster),
            EventSubSubscription.GuestStar.sessionBegin(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.GuestStar.sessionEnd(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.GuestStar.guestUpdate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.GuestStar.settingsUpdate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.ChannelPoints.automaticRewardRedemptionAddV1(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.automaticRewardRedemptionAdd(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.customRewardAdd(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.customRewardUpdate(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.customRewardRemove(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.customRewardRedemptionAdd(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.customRewardRedemptionUpdate(broadcasterID: broadcaster),
            EventSubSubscription.ChannelPoints.customPowerUpRedemptionAdd(broadcasterID: broadcaster),
            EventSubSubscription.Channel.pollBegin(broadcasterID: broadcaster),
            EventSubSubscription.Channel.pollProgress(broadcasterID: broadcaster),
            EventSubSubscription.Channel.pollEnd(broadcasterID: broadcaster),
            EventSubSubscription.Channel.predictionBegin(broadcasterID: broadcaster),
            EventSubSubscription.Channel.predictionProgress(broadcasterID: broadcaster),
            EventSubSubscription.Channel.predictionLock(broadcasterID: broadcaster),
            EventSubSubscription.Channel.predictionEnd(broadcasterID: broadcaster),
            EventSubSubscription.Moderation.suspiciousUserMessage(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.suspiciousUserUpdate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.vipAdd(broadcasterID: broadcaster),
            EventSubSubscription.Moderation.vipRemove(broadcasterID: broadcaster),
            EventSubSubscription.Moderation.warningAcknowledge(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Moderation.warningSend(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Channel.charityDonation(broadcasterID: broadcaster),
            EventSubSubscription.Channel.charityCampaignStart(broadcasterID: broadcaster),
            EventSubSubscription.Channel.charityCampaignProgress(broadcasterID: broadcaster),
            EventSubSubscription.Channel.charityCampaignStop(broadcasterID: broadcaster),
            EventSubSubscription.Conduit.shardDisabled(clientID: "client"),
            EventSubSubscription.Drop.entitlementGrant(organizationID: "organization"),
            EventSubSubscription.Extension.bitsTransactionCreate(extensionClientID: "extension"),
            EventSubSubscription.Channel.goalBegin(broadcasterID: broadcaster),
            EventSubSubscription.Channel.goalProgress(broadcasterID: broadcaster),
            EventSubSubscription.Channel.goalEnd(broadcasterID: broadcaster),
            EventSubSubscription.Channel.hypeTrainBegin(broadcasterID: broadcaster),
            EventSubSubscription.Channel.hypeTrainProgress(broadcasterID: broadcaster),
            EventSubSubscription.Channel.hypeTrainEnd(broadcasterID: broadcaster),
            EventSubSubscription.Channel.shieldModeBegin(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Channel.shieldModeEnd(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Channel.shoutoutCreate(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Channel.shoutoutReceive(broadcasterID: broadcaster, moderatorID: moderator),
            EventSubSubscription.Stream.online(broadcasterID: broadcaster),
            EventSubSubscription.Stream.offline(broadcasterID: broadcaster),
            EventSubSubscription.User.authorizationGrant(clientID: "client"),
            EventSubSubscription.User.authorizationRevoke(clientID: "client"),
            EventSubSubscription.User.update(userID: user),
            EventSubSubscription.User.whisperMessage(userID: user)
        ]

        let actual = Set(subscriptions.map { "\($0.type)#\($0.version)" })
        let expected: Set<String> = [
            "automod.message.hold#1",
            "automod.message.hold#2",
            "automod.message.update#1",
            "automod.message.update#2",
            "automod.settings.update#1",
            "automod.terms.update#1",
            "channel.bits.use#1",
            "channel.update#2",
            "channel.follow#2",
            "channel.ad_break.begin#1",
            "channel.chat.clear#1",
            "channel.chat.clear_user_messages#1",
            "channel.chat.message#1",
            "channel.chat.message_delete#1",
            "channel.chat.notification#1",
            "channel.chat_settings.update#1",
            "channel.chat.user_message_hold#1",
            "channel.chat.user_message_update#1",
            "channel.shared_chat.begin#1",
            "channel.shared_chat.update#1",
            "channel.shared_chat.end#1",
            "channel.subscribe#1",
            "channel.subscription.end#1",
            "channel.subscription.gift#1",
            "channel.subscription.message#1",
            "channel.cheer#1",
            "channel.raid#1",
            "channel.ban#1",
            "channel.unban#1",
            "channel.unban_request.create#1",
            "channel.unban_request.resolve#1",
            "channel.moderate#1",
            "channel.moderate#2",
            "channel.moderator.add#1",
            "channel.moderator.remove#1",
            "channel.guest_star_session.begin#beta",
            "channel.guest_star_session.end#beta",
            "channel.guest_star_guest.update#beta",
            "channel.guest_star_settings.update#beta",
            "channel.channel_points_automatic_reward_redemption.add#1",
            "channel.channel_points_automatic_reward_redemption.add#2",
            "channel.channel_points_custom_reward.add#1",
            "channel.channel_points_custom_reward.update#1",
            "channel.channel_points_custom_reward.remove#1",
            "channel.channel_points_custom_reward_redemption.add#1",
            "channel.channel_points_custom_reward_redemption.update#1",
            "channel.custom_power_up_redemption.add#1",
            "channel.poll.begin#1",
            "channel.poll.progress#1",
            "channel.poll.end#1",
            "channel.prediction.begin#1",
            "channel.prediction.progress#1",
            "channel.prediction.lock#1",
            "channel.prediction.end#1",
            "channel.suspicious_user.message#1",
            "channel.suspicious_user.update#1",
            "channel.vip.add#1",
            "channel.vip.remove#1",
            "channel.warning.acknowledge#1",
            "channel.warning.send#1",
            "channel.charity_campaign.donate#1",
            "channel.charity_campaign.start#1",
            "channel.charity_campaign.progress#1",
            "channel.charity_campaign.stop#1",
            "conduit.shard.disabled#1",
            "drop.entitlement.grant#1",
            "extension.bits_transaction.create#1",
            "channel.goal.begin#1",
            "channel.goal.progress#1",
            "channel.goal.end#1",
            "channel.hype_train.begin#2",
            "channel.hype_train.progress#2",
            "channel.hype_train.end#2",
            "channel.shield_mode.begin#1",
            "channel.shield_mode.end#1",
            "channel.shoutout.create#1",
            "channel.shoutout.receive#1",
            "stream.online#1",
            "stream.offline#1",
            "user.authorization.grant#1",
            "user.authorization.revoke#1",
            "user.update#1",
            "user.whisper.message#1"
        ]

        XCTAssertEqual(actual, expected)
    }

    func test_chatMessageClosedDomainStringsDecodeKnownAndUnknownValues() throws {
        let known = try JSONDecoder.twitch().decode(ChatMessageType.self, from: Data(#""text""#.utf8))
        let unknown = try JSONDecoder.twitch().decode(ChatMessageType.self, from: Data(#""future_type""#.utf8))

        XCTAssertEqual(known, .text)
        XCTAssertEqual(unknown, .unknown("future_type"))
        XCTAssertEqual(known.rawValue, "text")
        XCTAssertEqual(unknown.rawValue, "future_type")
    }

    func test_twitchClientAcceptsEventSubBufferingPolicy() {
        let client = TwitchClient(
            clientId: "client-id",
            tokenStore: InMemoryTokenStore(),
            eventBufferingPolicy: .bufferingNewest(10)
        )

        _ = client.eventSub
    }

    func test_twitchStringEnumsDecodeUnknownValues() throws {
        let streamType = try JSONDecoder.twitch().decode(TwitchStreamType.self, from: Data(#""rerun""#.utf8))
        let transport = try JSONDecoder.twitch().decode(EventSubTransportMethod.self, from: Data(#""future_transport""#.utf8))
        let redemption = try JSONDecoder.twitch().decode(ChannelPointsRedemptionStatus.self, from: Data(#""future_status""#.utf8))
        let subscriptionStatus = try JSONDecoder.twitch().decode(
            EventSubSubscriptionStatus.self,
            from: Data(#""future_subscription_status""#.utf8)
        )

        XCTAssertEqual(streamType.rawValue, "rerun")
        XCTAssertEqual(transport.rawValue, "future_transport")
        XCTAssertEqual(redemption.rawValue, "future_status")
        XCTAssertEqual(subscriptionStatus.rawValue, "future_subscription_status")
    }

    /// Helix requires and returns UPPERCASE redemption statuses; decoding is
    /// also tolerant of lowercase inputs (e.g. EventSub redemption payloads).
    func test_channelPointsRedemptionStatusEmitsUppercaseAndDecodesCaseInsensitively() throws {
        let uppercase = try JSONDecoder.twitch().decode(ChannelPointsRedemptionStatus.self, from: Data(#""FULFILLED""#.utf8))
        let lowercase = try JSONDecoder.twitch().decode(ChannelPointsRedemptionStatus.self, from: Data(#""fulfilled""#.utf8))
        let unknown = try JSONDecoder.twitch().decode(ChannelPointsRedemptionStatus.self, from: Data(#""future_status""#.utf8))

        XCTAssertEqual(uppercase, .fulfilled)
        XCTAssertEqual(lowercase, .fulfilled)
        XCTAssertEqual(unknown, .unknown("future_status"))
        XCTAssertEqual(unknown.rawValue, "future_status")

        XCTAssertEqual(ChannelPointsRedemptionStatus.unfulfilled.rawValue, "UNFULFILLED")
        XCTAssertEqual(ChannelPointsRedemptionStatus.fulfilled.rawValue, "FULFILLED")
        XCTAssertEqual(ChannelPointsRedemptionStatus.canceled.rawValue, "CANCELED")

        let encoded = try JSONEncoder.twitch().encode(ChannelPointsRedemptionStatus.fulfilled)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), #""FULFILLED""#)
    }
}
