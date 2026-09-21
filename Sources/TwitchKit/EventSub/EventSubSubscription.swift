import Foundation

/// A typed EventSub subscription request that can be re-created after reconnecting.
public struct EventSubSubscription: Sendable, Hashable {
    public let type: String
    public let version: String
    public let condition: [String: String]
    public let isBatchingEnabled: Bool?

    public init(type: String, version: String, condition: [String: String], isBatchingEnabled: Bool? = nil) {
        self.type = type
        self.version = version
        self.condition = condition
        self.isBatchingEnabled = isBatchingEnabled
    }

    public static func makeChannelChatMessage(broadcasterID: String, userID: String) -> Self {
        Chat.message(broadcasterID: broadcasterID, userID: userID)
    }

    public static func makeChannelFollow(broadcasterID: String, moderatorID: String) -> Self {
        Channel.follow(broadcasterID: broadcasterID, moderatorID: moderatorID)
    }

    public static func makeChannelSubscribe(broadcasterID: String) -> Self {
        Channel.subscribe(broadcasterID: broadcasterID)
    }

    public enum Chat {
        public static func message(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.message",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func clear(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.clear",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func clearUserMessages(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.clear_user_messages",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func messageDelete(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.message_delete",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func notification(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.notification",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func settingsUpdate(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat_settings.update",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func userMessageHold(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.user_message_hold",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }

        public static func userMessageUpdate(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.user_message_update",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }
    }

    public enum Channel {
        public static func update(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.update",
                version: "2",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func follow(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.follow",
                version: "2",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func subscribe(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.subscribe",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func subscriptionEnd(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.subscription.end",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func subscriptionGift(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.subscription.gift",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func subscriptionMessage(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.subscription.message",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func raid(toBroadcasterID broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.raid",
                version: "1",
                condition: ["to_broadcaster_user_id": broadcasterID]
            )
        }

        public static func raid(fromBroadcasterID broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.raid",
                version: "1",
                condition: ["from_broadcaster_user_id": broadcasterID]
            )
        }

        public static func cheer(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.cheer",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func bitsUse(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.bits.use",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func adBreakBegin(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.ad_break.begin",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func sharedChatBegin(broadcasterID: String) -> EventSubSubscription {
            sharedChat(type: "channel.shared_chat.begin", broadcasterID: broadcasterID)
        }

        public static func sharedChatUpdate(broadcasterID: String) -> EventSubSubscription {
            sharedChat(type: "channel.shared_chat.update", broadcasterID: broadcasterID)
        }

        public static func sharedChatEnd(broadcasterID: String) -> EventSubSubscription {
            sharedChat(type: "channel.shared_chat.end", broadcasterID: broadcasterID)
        }

        public static func pollBegin(broadcasterID: String) -> EventSubSubscription {
            poll(type: "channel.poll.begin", broadcasterID: broadcasterID)
        }

        public static func pollProgress(broadcasterID: String) -> EventSubSubscription {
            poll(type: "channel.poll.progress", broadcasterID: broadcasterID)
        }

        public static func pollEnd(broadcasterID: String) -> EventSubSubscription {
            poll(type: "channel.poll.end", broadcasterID: broadcasterID)
        }

        public static func predictionBegin(broadcasterID: String) -> EventSubSubscription {
            prediction(type: "channel.prediction.begin", broadcasterID: broadcasterID)
        }

        public static func predictionProgress(broadcasterID: String) -> EventSubSubscription {
            prediction(type: "channel.prediction.progress", broadcasterID: broadcasterID)
        }

        public static func predictionLock(broadcasterID: String) -> EventSubSubscription {
            prediction(type: "channel.prediction.lock", broadcasterID: broadcasterID)
        }

        public static func predictionEnd(broadcasterID: String) -> EventSubSubscription {
            prediction(type: "channel.prediction.end", broadcasterID: broadcasterID)
        }

        public static func goalBegin(broadcasterID: String) -> EventSubSubscription {
            goal(type: "channel.goal.begin", broadcasterID: broadcasterID)
        }

        public static func goalProgress(broadcasterID: String) -> EventSubSubscription {
            goal(type: "channel.goal.progress", broadcasterID: broadcasterID)
        }

        public static func goalEnd(broadcasterID: String) -> EventSubSubscription {
            goal(type: "channel.goal.end", broadcasterID: broadcasterID)
        }

        public static func hypeTrainBegin(broadcasterID: String) -> EventSubSubscription {
            hypeTrain(type: "channel.hype_train.begin", broadcasterID: broadcasterID)
        }

        public static func hypeTrainProgress(broadcasterID: String) -> EventSubSubscription {
            hypeTrain(type: "channel.hype_train.progress", broadcasterID: broadcasterID)
        }

        public static func hypeTrainEnd(broadcasterID: String) -> EventSubSubscription {
            hypeTrain(type: "channel.hype_train.end", broadcasterID: broadcasterID)
        }

        public static func shieldModeBegin(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            shieldMode(type: "channel.shield_mode.begin", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func shieldModeEnd(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            shieldMode(type: "channel.shield_mode.end", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func shoutoutCreate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.shoutout.create",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func shoutoutReceive(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.shoutout.receive",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func charityDonation(broadcasterID: String) -> EventSubSubscription {
            charity(type: "channel.charity_campaign.donate", broadcasterID: broadcasterID)
        }

        public static func charityCampaignStart(broadcasterID: String) -> EventSubSubscription {
            charity(type: "channel.charity_campaign.start", broadcasterID: broadcasterID)
        }

        public static func charityCampaignProgress(broadcasterID: String) -> EventSubSubscription {
            charity(type: "channel.charity_campaign.progress", broadcasterID: broadcasterID)
        }

        public static func charityCampaignStop(broadcasterID: String) -> EventSubSubscription {
            charity(type: "channel.charity_campaign.stop", broadcasterID: broadcasterID)
        }

        private static func sharedChat(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "1", condition: ["broadcaster_user_id": broadcasterID])
        }

        private static func poll(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "1", condition: ["broadcaster_user_id": broadcasterID])
        }

        private static func prediction(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "1", condition: ["broadcaster_user_id": broadcasterID])
        }

        private static func goal(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "1", condition: ["broadcaster_user_id": broadcasterID])
        }

        private static func hypeTrain(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "2", condition: ["broadcaster_user_id": broadcasterID])
        }

        private static func shieldMode(type: String, broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: type,
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        private static func charity(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "1", condition: ["broadcaster_user_id": broadcasterID])
        }
    }

    public enum Stream {
        public static func online(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "stream.online",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func offline(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "stream.offline",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }
    }

    public enum Moderation {
        public static func automodMessageHold(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            automod(type: "automod.message.hold", version: "2", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func automodMessageHoldV1(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            automod(type: "automod.message.hold", version: "1", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func automodMessageUpdate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            automod(type: "automod.message.update", version: "2", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func automodMessageUpdateV1(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            automod(type: "automod.message.update", version: "1", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func automodSettingsUpdate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            automod(type: "automod.settings.update", version: "1", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func automodTermsUpdate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            automod(type: "automod.terms.update", version: "1", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func ban(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.ban",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func unban(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.unban",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func moderatorAdd(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.moderator.add",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func moderatorRemove(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.moderator.remove",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func moderate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.moderate",
                version: "2",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func moderateV1(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.moderate",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func unbanRequestCreate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.unban_request.create",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func unbanRequestResolve(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.unban_request.resolve",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func suspiciousUserMessage(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            suspiciousUser(type: "channel.suspicious_user.message", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func suspiciousUserUpdate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            suspiciousUser(type: "channel.suspicious_user.update", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func vipAdd(broadcasterID: String) -> EventSubSubscription {
            vip(type: "channel.vip.add", broadcasterID: broadcasterID)
        }

        public static func vipRemove(broadcasterID: String) -> EventSubSubscription {
            vip(type: "channel.vip.remove", broadcasterID: broadcasterID)
        }

        public static func warningAcknowledge(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            warning(type: "channel.warning.acknowledge", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func warningSend(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            warning(type: "channel.warning.send", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        private static func automod(
            type: String,
            version: String,
            broadcasterID: String,
            moderatorID: String
        ) -> EventSubSubscription {
            EventSubSubscription(
                type: type,
                version: version,
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        private static func suspiciousUser(
            type: String,
            broadcasterID: String,
            moderatorID: String
        ) -> EventSubSubscription {
            EventSubSubscription(
                type: type,
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        private static func vip(type: String, broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(type: type, version: "1", condition: ["broadcaster_user_id": broadcasterID])
        }

        private static func warning(type: String, broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: type,
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }
    }

    public enum ChannelPoints {
        public static func automaticRewardRedemptionAdd(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.channel_points_automatic_reward_redemption.add",
                version: "2",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func automaticRewardRedemptionAddV1(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.channel_points_automatic_reward_redemption.add",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func customPowerUpRedemptionAdd(broadcasterID: String, rewardID: String? = nil) -> EventSubSubscription {
            var condition = ["broadcaster_user_id": broadcasterID]
            condition["reward_id"] = rewardID
            return EventSubSubscription(type: "channel.custom_power_up_redemption.add", version: "1", condition: condition)
        }

        public static func customRewardAdd(broadcasterID: String) -> EventSubSubscription {
            customReward(type: "channel.channel_points_custom_reward.add", broadcasterID: broadcasterID)
        }

        public static func customRewardUpdate(broadcasterID: String, rewardID: String? = nil) -> EventSubSubscription {
            customReward(type: "channel.channel_points_custom_reward.update", broadcasterID: broadcasterID, rewardID: rewardID)
        }

        public static func customRewardRemove(broadcasterID: String, rewardID: String? = nil) -> EventSubSubscription {
            customReward(type: "channel.channel_points_custom_reward.remove", broadcasterID: broadcasterID, rewardID: rewardID)
        }

        public static func customRewardRedemptionAdd(
            broadcasterID: String,
            rewardID: String? = nil
        ) -> EventSubSubscription {
            customRewardRedemption(
                type: "channel.channel_points_custom_reward_redemption.add",
                broadcasterID: broadcasterID,
                rewardID: rewardID
            )
        }

        public static func customRewardRedemptionUpdate(
            broadcasterID: String,
            rewardID: String? = nil
        ) -> EventSubSubscription {
            customRewardRedemption(
                type: "channel.channel_points_custom_reward_redemption.update",
                broadcasterID: broadcasterID,
                rewardID: rewardID
            )
        }

        private static func customRewardRedemption(
            type: String,
            broadcasterID: String,
            rewardID: String?
        ) -> EventSubSubscription {
            var condition = ["broadcaster_user_id": broadcasterID]
            condition["reward_id"] = rewardID
            return EventSubSubscription(type: type, version: "1", condition: condition)
        }

        private static func customReward(
            type: String,
            broadcasterID: String,
            rewardID: String? = nil
        ) -> EventSubSubscription {
            var condition = ["broadcaster_user_id": broadcasterID]
            condition["reward_id"] = rewardID
            return EventSubSubscription(type: type, version: "1", condition: condition)
        }
    }

    public enum GuestStar {
        public static func sessionBegin(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            guestStar(type: "channel.guest_star_session.begin", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func sessionEnd(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            guestStar(type: "channel.guest_star_session.end", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func guestUpdate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            guestStar(type: "channel.guest_star_guest.update", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        public static func settingsUpdate(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            guestStar(type: "channel.guest_star_settings.update", broadcasterID: broadcasterID, moderatorID: moderatorID)
        }

        private static func guestStar(type: String, broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: type,
                version: "beta",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }
    }

    public enum Conduit {
        public static func shardDisabled(clientID: String, conduitID: String? = nil) -> EventSubSubscription {
            var condition = ["client_id": clientID]
            condition["conduit_id"] = conduitID
            return EventSubSubscription(type: "conduit.shard.disabled", version: "1", condition: condition)
        }
    }

    public enum Drop {
        public static func entitlementGrant(organizationID: String, categoryID: String? = nil, campaignID: String? = nil) -> EventSubSubscription {
            var condition = ["organization_id": organizationID]
            condition["category_id"] = categoryID
            condition["campaign_id"] = campaignID
            return EventSubSubscription(
                type: "drop.entitlement.grant",
                version: "1",
                condition: condition,
                isBatchingEnabled: true
            )
        }
    }

    public enum Extension {
        public static func bitsTransactionCreate(extensionClientID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "extension.bits_transaction.create",
                version: "1",
                condition: ["extension_client_id": extensionClientID]
            )
        }
    }

    public enum User {
        public static func authorizationGrant(clientID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "user.authorization.grant",
                version: "1",
                condition: ["client_id": clientID]
            )
        }

        public static func authorizationRevoke(clientID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "user.authorization.revoke",
                version: "1",
                condition: ["client_id": clientID]
            )
        }

        public static func update(userID: String) -> EventSubSubscription {
            EventSubSubscription(type: "user.update", version: "1", condition: ["user_id": userID])
        }

        public static func whisperMessage(userID: String) -> EventSubSubscription {
            EventSubSubscription(type: "user.whisper.message", version: "1", condition: ["user_id": userID])
        }
    }
}
