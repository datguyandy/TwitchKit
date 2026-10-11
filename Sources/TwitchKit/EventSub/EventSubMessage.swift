import Foundation
import os

private let eventSubMessageLogger = Logger(subsystem: "com.twitchkit", category: "eventsub")

func eventSubDecodingErrorDescription(_ error: Error) -> String {
    switch error {
    case DecodingError.keyNotFound(let key, let context):
        return "keyNotFound(\(eventSubCodingPath(context.codingPath + [key]))): \(context.debugDescription)"
    case DecodingError.typeMismatch(let type, let context):
        return "typeMismatch(\(type) at \(eventSubCodingPath(context.codingPath))): \(context.debugDescription)"
    case DecodingError.valueNotFound(let type, let context):
        return "valueNotFound(\(type) at \(eventSubCodingPath(context.codingPath))): \(context.debugDescription)"
    case DecodingError.dataCorrupted(let context):
        return "dataCorrupted(\(eventSubCodingPath(context.codingPath))): \(context.debugDescription)"
    default:
        return String(describing: error)
    }
}

private func eventSubCodingPath(_ path: [CodingKey]) -> String {
    guard !path.isEmpty else { return "<root>" }
    return path.map(\.stringValue).joined(separator: ".")
}

/// Events emitted from the EventSub WebSocket to consumers.
public enum EventSubEvent: Sendable {
    case chatMessage(ChatMessage)
    case channelUpdate(EventSubChannelUpdate)
    case follow(TwitchFollow)
    case subscription(TwitchSubscription)
    case streamOnline(EventSubStreamOnline)
    case streamOffline(EventSubStreamOffline)
    case automodMessageHold(EventSubAutoModMessage)
    case automodMessageUpdate(EventSubAutoModMessage)
    case automodSettingsUpdate(EventSubAutoModSettingsUpdate)
    case automodTermsUpdate(EventSubAutoModTermsUpdate)
    case bitsUse(EventSubBitsUse)
    case adBreakBegin(EventSubAdBreakBegin)
    case raid(EventSubRaid)
    case cheer(EventSubCheer)
    case ban(EventSubBan)
    case unban(EventSubUnban)
    case moderatorAdd(EventSubModeratorChange)
    case moderatorRemove(EventSubModeratorChange)
    case channelPointsCustomRewardRedemptionAdd(EventSubChannelPointsCustomRewardRedemption)
    case channelPointsCustomRewardRedemptionUpdate(EventSubChannelPointsCustomRewardRedemption)
    case channelPointsCustomRewardAdd(EventSubChannelPointsCustomReward)
    case channelPointsCustomRewardUpdate(EventSubChannelPointsCustomReward)
    case channelPointsCustomRewardRemove(EventSubChannelPointsCustomReward)
    case channelPointsAutomaticRewardRedemptionAdd(EventSubChannelPointsAutomaticRewardRedemption)
    case chatClear(EventSubChatClear)
    case chatClearUserMessages(EventSubChatClearUserMessages)
    case chatMessageDelete(EventSubChatMessageDelete)
    case chatNotification(EventSubChatNotification)
    case chatUserMessageHold(EventSubChatUserMessageModeration)
    case chatUserMessageUpdate(EventSubChatUserMessageModeration)
    case chatSettingsUpdate(EventSubChatSettingsUpdate)
    case sharedChatBegin(EventSubSharedChatSession)
    case sharedChatUpdate(EventSubSharedChatSession)
    case sharedChatEnd(EventSubSharedChatSession)
    case moderate(EventSubModerate)
    case guestStarSessionBegin(EventSubGuestStarSession)
    case guestStarSessionEnd(EventSubGuestStarSession)
    case guestStarGuestUpdate(EventSubGuestStarGuestUpdate)
    case guestStarSettingsUpdate(EventSubGuestStarSettingsUpdate)
    case subscriptionEnd(EventSubSubscriptionEnd)
    case subscriptionGift(EventSubSubscriptionGift)
    case subscriptionMessage(EventSubSubscriptionMessage)
    case pollBegin(EventSubPoll)
    case pollProgress(EventSubPoll)
    case pollEnd(EventSubPoll)
    case predictionBegin(EventSubPrediction)
    case predictionProgress(EventSubPrediction)
    case predictionLock(EventSubPrediction)
    case predictionEnd(EventSubPrediction)
    case goalBegin(EventSubGoal)
    case goalProgress(EventSubGoal)
    case goalEnd(EventSubGoal)
    case hypeTrainBegin(EventSubHypeTrain)
    case hypeTrainProgress(EventSubHypeTrain)
    case hypeTrainEnd(EventSubHypeTrain)
    case charityCampaignDonate(EventSubCharityDonation)
    case charityCampaignStart(EventSubCharityCampaign)
    case charityCampaignProgress(EventSubCharityCampaign)
    case charityCampaignStop(EventSubCharityCampaign)
    case customPowerUpRedemptionAdd(EventSubCustomPowerUpRedemption)
    case suspiciousUserMessage(EventSubSuspiciousUserMessage)
    case suspiciousUserUpdate(EventSubSuspiciousUserUpdate)
    case unbanRequestCreate(EventSubUnbanRequest)
    case unbanRequestResolve(EventSubUnbanRequest)
    case vipAdd(EventSubVIPChange)
    case vipRemove(EventSubVIPChange)
    case shieldModeBegin(EventSubShieldMode)
    case shieldModeEnd(EventSubShieldMode)
    case shoutoutCreate(EventSubShoutout)
    case shoutoutReceive(EventSubShoutout)
    case warningAcknowledge(EventSubWarning)
    case warningSend(EventSubWarning)
    case conduitShardDisabled(EventSubConduitShardDisabled)
    case dropEntitlementGrant(EventSubDropEntitlementGrant)
    case extensionBitsTransactionCreate(EventSubExtensionBitsTransaction)
    case userAuthorizationGrant(EventSubUserAuthorization)
    case userAuthorizationRevoke(EventSubUserAuthorization)
    case userUpdate(EventSubUserUpdate)
    case userWhisperMessage(EventSubWhisperMessage)
    case revocation(EventSubRevocation)
    /// Twitch rejected re-creating a subscription after a reconnect, for a
    /// reason retrying can't fix (for example a missing scope, or a type or
    /// version Twitch no longer supports). The client has stopped tracking
    /// the subscription; subscribe again once the cause is fixed.
    case subscriptionFailed(EventSubSubscription, HelixError)
    case known(EventSubKnownEvent)
    case unknown(type: String, payload: Data)

    static func decode(type: String, payload data: Data, decoder: JSONDecoder = .twitch()) -> Self {
        switch type {
        case "channel.chat.message":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: ChatMessage.self, map: Self.chatMessage)
        case "channel.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelUpdate.self, map: Self.channelUpdate)
        case "channel.follow":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: TwitchFollow.self, map: Self.follow)
        case "channel.subscribe":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: TwitchSubscription.self, map: Self.subscription)
        case "stream.online":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubStreamOnline.self, map: Self.streamOnline)
        case "stream.offline":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubStreamOffline.self, map: Self.streamOffline)
        case "automod.message.hold":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubAutoModMessage.self, map: Self.automodMessageHold)
        case "automod.message.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubAutoModMessage.self, map: Self.automodMessageUpdate)
        case "automod.settings.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubAutoModSettingsUpdate.self, map: Self.automodSettingsUpdate)
        case "automod.terms.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubAutoModTermsUpdate.self, map: Self.automodTermsUpdate)
        case "channel.bits.use":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubBitsUse.self, map: Self.bitsUse)
        case "channel.ad_break.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubAdBreakBegin.self, map: Self.adBreakBegin)
        case "channel.raid":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubRaid.self, map: Self.raid)
        case "channel.cheer":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubCheer.self, map: Self.cheer)
        case "channel.ban":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubBan.self, map: Self.ban)
        case "channel.unban":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubUnban.self, map: Self.unban)
        case "channel.moderator.add":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubModeratorChange.self, map: Self.moderatorAdd)
        case "channel.moderator.remove":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubModeratorChange.self, map: Self.moderatorRemove)
        case "channel.channel_points_custom_reward_redemption.add":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelPointsCustomRewardRedemption.self, map: Self.channelPointsCustomRewardRedemptionAdd)
        case "channel.channel_points_custom_reward_redemption.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelPointsCustomRewardRedemption.self, map: Self.channelPointsCustomRewardRedemptionUpdate)
        case "channel.channel_points_custom_reward.add":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelPointsCustomReward.self, map: Self.channelPointsCustomRewardAdd)
        case "channel.channel_points_custom_reward.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelPointsCustomReward.self, map: Self.channelPointsCustomRewardUpdate)
        case "channel.channel_points_custom_reward.remove":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelPointsCustomReward.self, map: Self.channelPointsCustomRewardRemove)
        case "channel.channel_points_automatic_reward_redemption.add":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChannelPointsAutomaticRewardRedemption.self, map: Self.channelPointsAutomaticRewardRedemptionAdd)
        case "channel.chat.clear":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatClear.self, map: Self.chatClear)
        case "channel.chat.clear_user_messages":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatClearUserMessages.self, map: Self.chatClearUserMessages)
        case "channel.chat.message_delete":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatMessageDelete.self, map: Self.chatMessageDelete)
        case "channel.chat.notification":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatNotification.self, map: Self.chatNotification)
        case "channel.chat.user_message_hold":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatUserMessageModeration.self, map: Self.chatUserMessageHold)
        case "channel.chat.user_message_update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatUserMessageModeration.self, map: Self.chatUserMessageUpdate)
        case "channel.chat_settings.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubChatSettingsUpdate.self, map: Self.chatSettingsUpdate)
        case "channel.shared_chat.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSharedChatSession.self, map: Self.sharedChatBegin)
        case "channel.shared_chat.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSharedChatSession.self, map: Self.sharedChatUpdate)
        case "channel.shared_chat.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSharedChatSession.self, map: Self.sharedChatEnd)
        case "channel.moderate":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubModerate.self, map: Self.moderate)
        case "channel.guest_star_session.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGuestStarSession.self, map: Self.guestStarSessionBegin)
        case "channel.guest_star_session.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGuestStarSession.self, map: Self.guestStarSessionEnd)
        case "channel.guest_star_guest.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGuestStarGuestUpdate.self, map: Self.guestStarGuestUpdate)
        case "channel.guest_star_settings.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGuestStarSettingsUpdate.self, map: Self.guestStarSettingsUpdate)
        case "channel.subscription.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSubscriptionEnd.self, map: Self.subscriptionEnd)
        case "channel.subscription.gift":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSubscriptionGift.self, map: Self.subscriptionGift)
        case "channel.subscription.message":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSubscriptionMessage.self, map: Self.subscriptionMessage)
        case "channel.poll.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPoll.self, map: Self.pollBegin)
        case "channel.poll.progress":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPoll.self, map: Self.pollProgress)
        case "channel.poll.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPoll.self, map: Self.pollEnd)
        case "channel.prediction.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionBegin)
        case "channel.prediction.progress":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionProgress)
        case "channel.prediction.lock":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionLock)
        case "channel.prediction.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionEnd)
        case "channel.goal.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGoal.self, map: Self.goalBegin)
        case "channel.goal.progress":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGoal.self, map: Self.goalProgress)
        case "channel.goal.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubGoal.self, map: Self.goalEnd)
        case "channel.hype_train.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubHypeTrain.self, map: Self.hypeTrainBegin)
        case "channel.hype_train.progress":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubHypeTrain.self, map: Self.hypeTrainProgress)
        case "channel.hype_train.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubHypeTrain.self, map: Self.hypeTrainEnd)
        case "channel.charity_campaign.donate":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubCharityDonation.self, map: Self.charityCampaignDonate)
        case "channel.charity_campaign.start":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubCharityCampaign.self, map: Self.charityCampaignStart)
        case "channel.charity_campaign.progress":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubCharityCampaign.self, map: Self.charityCampaignProgress)
        case "channel.charity_campaign.stop":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubCharityCampaign.self, map: Self.charityCampaignStop)
        case "channel.custom_power_up_redemption.add":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubCustomPowerUpRedemption.self, map: Self.customPowerUpRedemptionAdd)
        case "channel.suspicious_user.message":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSuspiciousUserMessage.self, map: Self.suspiciousUserMessage)
        case "channel.suspicious_user.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubSuspiciousUserUpdate.self, map: Self.suspiciousUserUpdate)
        case "channel.unban_request.create":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubUnbanRequest.self, map: Self.unbanRequestCreate)
        case "channel.unban_request.resolve":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubUnbanRequest.self, map: Self.unbanRequestResolve)
        case "channel.vip.add":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubVIPChange.self, map: Self.vipAdd)
        case "channel.vip.remove":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubVIPChange.self, map: Self.vipRemove)
        case "channel.shield_mode.begin":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubShieldMode.self, map: Self.shieldModeBegin)
        case "channel.shield_mode.end":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubShieldMode.self, map: Self.shieldModeEnd)
        case "channel.shoutout.create":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubShoutout.self, map: Self.shoutoutCreate)
        case "channel.shoutout.receive":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubShoutout.self, map: Self.shoutoutReceive)
        case "channel.warning.acknowledge":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubWarning.self, map: Self.warningAcknowledge)
        case "channel.warning.send":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubWarning.self, map: Self.warningSend)
        case "conduit.shard.disabled":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubConduitShardDisabled.self, map: Self.conduitShardDisabled)
        case "drop.entitlement.grant":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubDropEntitlementGrant.self, map: Self.dropEntitlementGrant)
        case "extension.bits_transaction.create":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubExtensionBitsTransaction.self, map: Self.extensionBitsTransactionCreate)
        case "user.authorization.grant":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubUserAuthorization.self, map: Self.userAuthorizationGrant)
        case "user.authorization.revoke":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubUserAuthorization.self, map: Self.userAuthorizationRevoke)
        case "user.update":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubUserUpdate.self, map: Self.userUpdate)
        case "user.whisper.message":
            return decodeKnownEvent(type: type, payload: data, decoder: decoder, as: EventSubWhisperMessage.self, map: Self.userWhisperMessage)
        default:
            break
        }
        return fallbackEvent(type: type, payload: data)
    }

    static func decodeNotification(type: String, envelope data: Data, decoder: JSONDecoder = .twitch()) -> Self {
        switch type {
        case "channel.chat.message":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: ChatMessage.self, map: Self.chatMessage)
        case "channel.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelUpdate.self, map: Self.channelUpdate)
        case "channel.follow":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: TwitchFollow.self, map: Self.follow)
        case "channel.subscribe":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: TwitchSubscription.self, map: Self.subscription)
        case "stream.online":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubStreamOnline.self, map: Self.streamOnline)
        case "stream.offline":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubStreamOffline.self, map: Self.streamOffline)
        case "automod.message.hold":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubAutoModMessage.self, map: Self.automodMessageHold)
        case "automod.message.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubAutoModMessage.self, map: Self.automodMessageUpdate)
        case "automod.settings.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubAutoModSettingsUpdate.self, map: Self.automodSettingsUpdate)
        case "automod.terms.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubAutoModTermsUpdate.self, map: Self.automodTermsUpdate)
        case "channel.bits.use":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubBitsUse.self, map: Self.bitsUse)
        case "channel.ad_break.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubAdBreakBegin.self, map: Self.adBreakBegin)
        case "channel.raid":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubRaid.self, map: Self.raid)
        case "channel.cheer":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubCheer.self, map: Self.cheer)
        case "channel.ban":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubBan.self, map: Self.ban)
        case "channel.unban":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubUnban.self, map: Self.unban)
        case "channel.moderator.add":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubModeratorChange.self, map: Self.moderatorAdd)
        case "channel.moderator.remove":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubModeratorChange.self, map: Self.moderatorRemove)
        case "channel.channel_points_custom_reward_redemption.add":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelPointsCustomRewardRedemption.self, map: Self.channelPointsCustomRewardRedemptionAdd)
        case "channel.channel_points_custom_reward_redemption.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelPointsCustomRewardRedemption.self, map: Self.channelPointsCustomRewardRedemptionUpdate)
        case "channel.channel_points_custom_reward.add":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelPointsCustomReward.self, map: Self.channelPointsCustomRewardAdd)
        case "channel.channel_points_custom_reward.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelPointsCustomReward.self, map: Self.channelPointsCustomRewardUpdate)
        case "channel.channel_points_custom_reward.remove":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelPointsCustomReward.self, map: Self.channelPointsCustomRewardRemove)
        case "channel.channel_points_automatic_reward_redemption.add":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChannelPointsAutomaticRewardRedemption.self, map: Self.channelPointsAutomaticRewardRedemptionAdd)
        case "channel.chat.clear":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatClear.self, map: Self.chatClear)
        case "channel.chat.clear_user_messages":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatClearUserMessages.self, map: Self.chatClearUserMessages)
        case "channel.chat.message_delete":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatMessageDelete.self, map: Self.chatMessageDelete)
        case "channel.chat.notification":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatNotification.self, map: Self.chatNotification)
        case "channel.chat.user_message_hold":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatUserMessageModeration.self, map: Self.chatUserMessageHold)
        case "channel.chat.user_message_update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatUserMessageModeration.self, map: Self.chatUserMessageUpdate)
        case "channel.chat_settings.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubChatSettingsUpdate.self, map: Self.chatSettingsUpdate)
        case "channel.shared_chat.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSharedChatSession.self, map: Self.sharedChatBegin)
        case "channel.shared_chat.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSharedChatSession.self, map: Self.sharedChatUpdate)
        case "channel.shared_chat.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSharedChatSession.self, map: Self.sharedChatEnd)
        case "channel.moderate":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubModerate.self, map: Self.moderate)
        case "channel.guest_star_session.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGuestStarSession.self, map: Self.guestStarSessionBegin)
        case "channel.guest_star_session.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGuestStarSession.self, map: Self.guestStarSessionEnd)
        case "channel.guest_star_guest.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGuestStarGuestUpdate.self, map: Self.guestStarGuestUpdate)
        case "channel.guest_star_settings.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGuestStarSettingsUpdate.self, map: Self.guestStarSettingsUpdate)
        case "channel.subscription.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSubscriptionEnd.self, map: Self.subscriptionEnd)
        case "channel.subscription.gift":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSubscriptionGift.self, map: Self.subscriptionGift)
        case "channel.subscription.message":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSubscriptionMessage.self, map: Self.subscriptionMessage)
        case "channel.poll.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPoll.self, map: Self.pollBegin)
        case "channel.poll.progress":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPoll.self, map: Self.pollProgress)
        case "channel.poll.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPoll.self, map: Self.pollEnd)
        case "channel.prediction.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionBegin)
        case "channel.prediction.progress":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionProgress)
        case "channel.prediction.lock":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionLock)
        case "channel.prediction.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubPrediction.self, map: Self.predictionEnd)
        case "channel.goal.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGoal.self, map: Self.goalBegin)
        case "channel.goal.progress":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGoal.self, map: Self.goalProgress)
        case "channel.goal.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubGoal.self, map: Self.goalEnd)
        case "channel.hype_train.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubHypeTrain.self, map: Self.hypeTrainBegin)
        case "channel.hype_train.progress":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubHypeTrain.self, map: Self.hypeTrainProgress)
        case "channel.hype_train.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubHypeTrain.self, map: Self.hypeTrainEnd)
        case "channel.charity_campaign.donate":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubCharityDonation.self, map: Self.charityCampaignDonate)
        case "channel.charity_campaign.start":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubCharityCampaign.self, map: Self.charityCampaignStart)
        case "channel.charity_campaign.progress":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubCharityCampaign.self, map: Self.charityCampaignProgress)
        case "channel.charity_campaign.stop":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubCharityCampaign.self, map: Self.charityCampaignStop)
        case "channel.custom_power_up_redemption.add":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubCustomPowerUpRedemption.self, map: Self.customPowerUpRedemptionAdd)
        case "channel.suspicious_user.message":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSuspiciousUserMessage.self, map: Self.suspiciousUserMessage)
        case "channel.suspicious_user.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubSuspiciousUserUpdate.self, map: Self.suspiciousUserUpdate)
        case "channel.unban_request.create":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubUnbanRequest.self, map: Self.unbanRequestCreate)
        case "channel.unban_request.resolve":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubUnbanRequest.self, map: Self.unbanRequestResolve)
        case "channel.vip.add":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubVIPChange.self, map: Self.vipAdd)
        case "channel.vip.remove":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubVIPChange.self, map: Self.vipRemove)
        case "channel.shield_mode.begin":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubShieldMode.self, map: Self.shieldModeBegin)
        case "channel.shield_mode.end":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubShieldMode.self, map: Self.shieldModeEnd)
        case "channel.shoutout.create":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubShoutout.self, map: Self.shoutoutCreate)
        case "channel.shoutout.receive":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubShoutout.self, map: Self.shoutoutReceive)
        case "channel.warning.acknowledge":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubWarning.self, map: Self.warningAcknowledge)
        case "channel.warning.send":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubWarning.self, map: Self.warningSend)
        case "conduit.shard.disabled":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubConduitShardDisabled.self, map: Self.conduitShardDisabled)
        case "drop.entitlement.grant":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubDropEntitlementGrant.self, map: Self.dropEntitlementGrant)
        case "extension.bits_transaction.create":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubExtensionBitsTransaction.self, map: Self.extensionBitsTransactionCreate)
        case "user.authorization.grant":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubUserAuthorization.self, map: Self.userAuthorizationGrant)
        case "user.authorization.revoke":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubUserAuthorization.self, map: Self.userAuthorizationRevoke)
        case "user.update":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubUserUpdate.self, map: Self.userUpdate)
        case "user.whisper.message":
            return decodeNotificationEvent(type: type, envelope: data, decoder: decoder, as: EventSubWhisperMessage.self, map: Self.userWhisperMessage)
        default:
            break
        }
        return fallbackEvent(type: type, payload: rawEventPayload(from: data) ?? data)
    }


    private static func decodeKnownEvent<T: Decodable>(
        type: String,
        payload data: Data,
        decoder: JSONDecoder,
        as _: T.Type,
        map: (T) -> Self
    ) -> Self {
        do {
            return map(try decoder.decode(T.self, from: data))
        } catch {
            eventSubMessageLogger.error(
                "EventSub: failed to decode \(type, privacy: .public) as \(String(describing: T.self), privacy: .public): \(eventSubDecodingErrorDescription(error), privacy: .public)"
            )
            return fallbackEvent(type: type, payload: data)
        }
    }

    private static func decodeNotificationEvent<T: Decodable>(
        type: String,
        envelope data: Data,
        decoder: JSONDecoder,
        as _: T.Type,
        map: (T) -> Self
    ) -> Self {
        do {
            let envelope = try decoder.decode(EventSubNotificationEnvelope<T>.self, from: data)
            return map(envelope.payload.event)
        } catch {
            eventSubMessageLogger.error(
                "EventSub: failed to decode notification \(type, privacy: .public) as \(String(describing: T.self), privacy: .public): \(eventSubDecodingErrorDescription(error), privacy: .public)"
            )
            return fallbackEvent(type: type, payload: rawEventPayload(from: data) ?? data)
        }
    }

    private static func rawEventPayload(from envelopeData: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: envelopeData) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              let event = payload["event"] else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: event)
    }

    private static func fallbackEvent(type: String, payload data: Data) -> Self {
        if let knownType = EventSubKnownEventType(rawValue: type) {
            return .known(EventSubKnownEvent(type: knownType, payload: data))
        }
        return .unknown(type: type, payload: data)
    }
}

/// An EventSub subscription revocation notification.
public struct EventSubRevocation: Codable, Sendable, Equatable {
    public let id: String
    public let status: EventSubSubscriptionStatus
    public let type: String
    public let version: String
    public let condition: [String: String]
}


private struct EventSubNotificationEnvelope<Event: Decodable>: Decodable {
    let payload: Payload

    struct Payload: Decodable {
        let event: Event
    }
}

/// Raw WebSocket message envelope from Twitch EventSub.
struct EventSubEnvelope: Decodable {
    let metadata: Metadata
    let payload: Payload

    struct Metadata: Decodable {
        let messageId: String
        let messageType: String
        let messageTimestamp: Date
        let subscriptionType: String?
    }

    struct Payload: Decodable {
        // session_welcome
        let session: SessionInfo?

        let subscription: EventSubRevocation?

        struct SessionInfo: Decodable {
            let id: String
            let status: String
            let keepaliveTimeoutSeconds: Int?
            let reconnectUrl: String?
            let connectedAt: Date?
        }
    }
}
