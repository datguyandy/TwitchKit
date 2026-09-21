import Foundation

/// A currently-known Twitch EventSub event whose payload is preserved as raw JSON.
///
/// TwitchKit returns this type when Twitch emits a subscription type the SDK recognizes,
/// but does not yet expose as a dedicated field-level model. This keeps future modeling
/// additive while still separating known Twitch events from genuinely unknown future types.
public struct EventSubKnownEvent: Sendable, Equatable {
    /// The known EventSub subscription type.
    public let type: EventSubKnownEventType

    /// The original JSON payload bytes for the event.
    public let payload: Data
}

/// EventSub notification types currently published by Twitch.
public enum EventSubKnownEventType: String, Sendable, Equatable, CaseIterable {
    case automodMessageHold = "automod.message.hold"
    case automodMessageUpdate = "automod.message.update"
    case automodSettingsUpdate = "automod.settings.update"
    case automodTermsUpdate = "automod.terms.update"
    case channelBitsUse = "channel.bits.use"
    case channelUpdate = "channel.update"
    case channelFollow = "channel.follow"
    case channelAdBreakBegin = "channel.ad_break.begin"
    case channelChatClear = "channel.chat.clear"
    case channelChatClearUserMessages = "channel.chat.clear_user_messages"
    case channelChatMessage = "channel.chat.message"
    case channelChatMessageDelete = "channel.chat.message_delete"
    case channelChatNotification = "channel.chat.notification"
    case channelChatSettingsUpdate = "channel.chat_settings.update"
    case channelChatUserMessageHold = "channel.chat.user_message_hold"
    case channelChatUserMessageUpdate = "channel.chat.user_message_update"
    case channelSharedChatBegin = "channel.shared_chat.begin"
    case channelSharedChatUpdate = "channel.shared_chat.update"
    case channelSharedChatEnd = "channel.shared_chat.end"
    case channelSubscribe = "channel.subscribe"
    case channelSubscriptionEnd = "channel.subscription.end"
    case channelSubscriptionGift = "channel.subscription.gift"
    case channelSubscriptionMessage = "channel.subscription.message"
    case channelCheer = "channel.cheer"
    case channelRaid = "channel.raid"
    case channelBan = "channel.ban"
    case channelUnban = "channel.unban"
    case channelUnbanRequestCreate = "channel.unban_request.create"
    case channelUnbanRequestResolve = "channel.unban_request.resolve"
    case channelModerate = "channel.moderate"
    case channelModeratorAdd = "channel.moderator.add"
    case channelModeratorRemove = "channel.moderator.remove"
    case channelGuestStarSessionBegin = "channel.guest_star_session.begin"
    case channelGuestStarSessionEnd = "channel.guest_star_session.end"
    case channelGuestStarGuestUpdate = "channel.guest_star_guest.update"
    case channelGuestStarSettingsUpdate = "channel.guest_star_settings.update"
    case channelPointsAutomaticRewardRedemptionAdd = "channel.channel_points_automatic_reward_redemption.add"
    case channelPointsCustomRewardAdd = "channel.channel_points_custom_reward.add"
    case channelPointsCustomRewardUpdate = "channel.channel_points_custom_reward.update"
    case channelPointsCustomRewardRemove = "channel.channel_points_custom_reward.remove"
    case channelPointsCustomRewardRedemptionAdd = "channel.channel_points_custom_reward_redemption.add"
    case channelPointsCustomRewardRedemptionUpdate = "channel.channel_points_custom_reward_redemption.update"
    case channelCustomPowerUpRedemptionAdd = "channel.custom_power_up_redemption.add"
    case channelPollBegin = "channel.poll.begin"
    case channelPollProgress = "channel.poll.progress"
    case channelPollEnd = "channel.poll.end"
    case channelPredictionBegin = "channel.prediction.begin"
    case channelPredictionProgress = "channel.prediction.progress"
    case channelPredictionLock = "channel.prediction.lock"
    case channelPredictionEnd = "channel.prediction.end"
    case channelSuspiciousUserMessage = "channel.suspicious_user.message"
    case channelSuspiciousUserUpdate = "channel.suspicious_user.update"
    case channelVIPAdd = "channel.vip.add"
    case channelVIPRemove = "channel.vip.remove"
    case channelWarningAcknowledge = "channel.warning.acknowledge"
    case channelWarningSend = "channel.warning.send"
    case channelCharityCampaignDonate = "channel.charity_campaign.donate"
    case channelCharityCampaignStart = "channel.charity_campaign.start"
    case channelCharityCampaignProgress = "channel.charity_campaign.progress"
    case channelCharityCampaignStop = "channel.charity_campaign.stop"
    case conduitShardDisabled = "conduit.shard.disabled"
    case dropEntitlementGrant = "drop.entitlement.grant"
    case extensionBitsTransactionCreate = "extension.bits_transaction.create"
    case channelGoalBegin = "channel.goal.begin"
    case channelGoalProgress = "channel.goal.progress"
    case channelGoalEnd = "channel.goal.end"
    case channelHypeTrainBegin = "channel.hype_train.begin"
    case channelHypeTrainProgress = "channel.hype_train.progress"
    case channelHypeTrainEnd = "channel.hype_train.end"
    case channelShieldModeBegin = "channel.shield_mode.begin"
    case channelShieldModeEnd = "channel.shield_mode.end"
    case channelShoutoutCreate = "channel.shoutout.create"
    case channelShoutoutReceive = "channel.shoutout.receive"
    case streamOnline = "stream.online"
    case streamOffline = "stream.offline"
    case userAuthorizationGrant = "user.authorization.grant"
    case userAuthorizationRevoke = "user.authorization.revoke"
    case userUpdate = "user.update"
    case userWhisperMessage = "user.whisper.message"
}

public struct EventSubChannelUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let title: String
    public let language: String
    public let categoryId: String
    public let categoryName: String
    public let contentClassificationLabels: [String]
}

public struct EventSubStreamOnline: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let type: TwitchStreamType
    public let startedAt: Date
}

public struct EventSubStreamOffline: Codable, Sendable, Equatable {
    public let id: String?
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubAutoModMessage: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let messageId: String
    public let message: ChatMessage.ChatMessageBody
    public let category: String?
    public let level: Int?
    public let status: String?
    public let heldAt: Date?
    public let reason: String?
    public let automod: AutoModDetails?
    public let blockedTerm: BlockedTermDetails?

    public struct Boundary: Codable, Sendable, Equatable {
        public let startPos: Int
        public let endPos: Int
    }

    public struct AutoModDetails: Codable, Sendable, Equatable {
        public let category: String
        public let level: Int
        public let boundaries: [Boundary]
    }

    /// Populated for both blocked_term and blocked_link reasons.
    public struct BlockedTermDetails: Codable, Sendable, Equatable {
        public let termsFound: [Term]

        public struct Term: Codable, Sendable, Equatable {
            public let termId: String
            public let boundary: Boundary
            public let ownerBroadcasterUserId: String
            public let ownerBroadcasterUserLogin: String
            public let ownerBroadcasterUserName: String
        }
    }
}

public struct EventSubAutoModSettingsUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let overallLevel: Int?
    public let disability: Int?
    public let aggression: Int?
    public let sexualitySexOrGender: Int?
    public let misogyny: Int?
    public let bullying: Int?
    public let swearing: Int?
    public let raceEthnicityOrReligion: Int?
    public let sexBasedTerms: Int?
}

public struct EventSubAutoModTermsUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let action: String
    public let fromAutomod: Bool?
    public let terms: [String]
}

public struct EventSubBitsUse: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let bits: Int
    public let type: String
    public let message: ChatMessage.ChatMessageBody?
    public let powerUp: PowerUp?

    public struct PowerUp: Codable, Sendable, Equatable {
        public let type: String
        public let emote: EmoteReference?
    }
}

public struct EventSubAdBreakBegin: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let requesterUserId: String?
    public let requesterUserLogin: String?
    public let requesterUserName: String?
    public let durationSeconds: Int
    public let startedAt: Date
    public let isAutomatic: Bool?
}

public struct EventSubRaid: Codable, Sendable, Equatable {
    public let fromBroadcasterUserId: String
    public let fromBroadcasterUserLogin: String
    public let fromBroadcasterUserName: String
    public let toBroadcasterUserId: String
    public let toBroadcasterUserLogin: String
    public let toBroadcasterUserName: String
    public let viewers: Int
}

public struct EventSubCheer: Codable, Sendable, Equatable {
    public let isAnonymous: Bool
    public let userId: String?
    public let userLogin: String?
    public let userName: String?
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let message: String
    public let bits: Int
}

public struct EventSubBan: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
    public let reason: String
    public let bannedAt: Date
    public let endsAt: Date?
    public let isPermanent: Bool
}

public struct EventSubUnban: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
}

public struct EventSubModeratorChange: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubChannelPointsCustomRewardRedemption: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let userInput: String
    public let status: ChannelPointsRedemptionStatus
    public let reward: Reward
    public let redeemedAt: Date

    public struct Reward: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let prompt: String
        public let cost: Int
    }
}

public struct EventSubChannelPointsCustomReward: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let isEnabled: Bool?
    public let isPaused: Bool?
    public let isInStock: Bool?
    public let title: String
    public let cost: Int
    public let prompt: String?
    public let isUserInputRequired: Bool?
    public let shouldRedemptionsSkipRequestQueue: Bool?
    public let cooldownExpiresAt: Date?
    public let redemptionsRedeemedCurrentStream: Int?
    public let maxPerStream: Limit?
    public let maxPerUserPerStream: Limit?
    public let globalCooldown: Cooldown?

    public struct Limit: Codable, Sendable, Equatable {
        public let isEnabled: Bool
        public let value: Int?
    }

    public struct Cooldown: Codable, Sendable, Equatable {
        public let isEnabled: Bool
        public let seconds: Int?
    }
}

public struct EventSubChannelPointsAutomaticRewardRedemption: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let id: String?
    public let reward: Reward
    public let message: ChatMessage.ChatMessageBody?
    public let userInput: String?
    public let redeemedAt: Date?

    public struct Reward: Codable, Sendable, Equatable {
        public let type: String
        public let cost: Int?
        public let unlockedEmote: TwitchEmote?
    }
}

public struct EventSubChatClear: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubChatClearUserMessages: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let targetUserId: String
    public let targetUserLogin: String
    public let targetUserName: String
}

public struct EventSubChatMessageDelete: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let targetUserId: String
    public let targetUserLogin: String
    public let targetUserName: String
    public let messageId: String
}

public struct EventSubChatNotification: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let chatterUserId: String
    public let chatterUserLogin: String
    public let chatterUserName: String
    public let chatterIsAnonymous: Bool?
    public let color: String?
    public let badges: [ChatBadge]
    public let systemMessage: String
    public let messageId: String
    public let message: ChatMessage.ChatMessageBody
    public let noticeType: String
    public let sub: Subscription?
    public let resub: Resubscription?
    public let subGift: SubscriptionGift?
    public let communitySubGift: CommunitySubscriptionGift?
    public let giftPaidUpgrade: GiftPaidUpgrade?
    public let primePaidUpgrade: PrimePaidUpgrade?
    public let raid: Raid?
    public let unraid: Empty?
    public let payItForward: PayItForward?
    public let announcement: Announcement?
    public let charityDonation: CharityDonation?
    public let bitsBadgeTier: BitsBadgeTier?
    public let watchStreak: WatchStreak?
    public let modiversary: Modiversary?
    public let sharedChatModiversary: Modiversary?
    public let isSourceOnly: Bool?

    public struct WatchStreak: Codable, Sendable, Equatable {
        public let streakCount: Int
        public let channelPointsAwarded: Int
    }

    public struct Modiversary: Codable, Sendable, Equatable {
        public let months: Int
    }

    public struct Subscription: Codable, Sendable, Equatable {
        public let subTier: SubscriptionTier
        public let isPrime: Bool
        public let durationMonths: Int
    }

    public struct Resubscription: Codable, Sendable, Equatable {
        public let cumulativeMonths: Int
        public let durationMonths: Int
        public let streakMonths: Int?
        public let subTier: SubscriptionTier
        public let isPrime: Bool
        public let isGift: Bool
        public let gifterIsAnonymous: Bool?
        public let gifterUserId: String?
        public let gifterUserLogin: String?
        public let gifterUserName: String?
    }

    public struct SubscriptionGift: Codable, Sendable, Equatable {
        public let durationMonths: Int
        public let cumulativeTotal: Int?
        public let recipientUserId: String
        public let recipientUserLogin: String
        public let recipientUserName: String
        public let subTier: SubscriptionTier
        public let communityGiftId: String?
    }

    public struct CommunitySubscriptionGift: Codable, Sendable, Equatable {
        public let id: String
        public let total: Int
        public let subTier: SubscriptionTier
        public let cumulativeTotal: Int?
    }

    public struct GiftPaidUpgrade: Codable, Sendable, Equatable {
        public let gifterIsAnonymous: Bool
        public let gifterUserId: String?
        public let gifterUserLogin: String?
        public let gifterUserName: String?
    }

    public struct PrimePaidUpgrade: Codable, Sendable, Equatable {
        public let subTier: SubscriptionTier
    }

    public struct Raid: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let viewerCount: Int
        public let profileImageUrl: URL?
    }

    public struct PayItForward: Codable, Sendable, Equatable {
        public let gifterIsAnonymous: Bool
        public let gifterUserId: String?
        public let gifterUserLogin: String?
        public let gifterUserName: String?
    }

    public struct Announcement: Codable, Sendable, Equatable {
        public let color: String
    }

    public struct CharityDonation: Decodable, Sendable, Equatable {
        public let charityName: String
        public let amount: CharityAmount
    }

    public struct BitsBadgeTier: Codable, Sendable, Equatable {
        public let tier: Int
    }

    public struct Empty: Codable, Sendable, Equatable {}
}

public struct EventSubChatUserMessageModeration: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let messageId: String
    public let message: ChatMessage.ChatMessageBody
    public let status: String
}

public struct EventSubChatSettingsUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let emoteMode: Bool
    public let followerMode: Bool
    public let followerModeDurationMinutes: Int?
    public let slowMode: Bool
    public let slowModeWaitTimeSeconds: Int?
    public let subscriberMode: Bool
    public let uniqueChatMode: Bool
}

public struct EventSubSharedChatSession: Codable, Sendable, Equatable {
    public let sessionId: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let hostBroadcasterUserId: String?
    public let hostBroadcasterUserLogin: String?
    public let hostBroadcasterUserName: String?
    public let participants: [Participant]?
    public let startedAt: Date?
    public let updatedAt: Date?
    public let endedAt: Date?

    public struct Participant: Codable, Sendable, Equatable {
        public let broadcasterUserId: String
        public let broadcasterUserLogin: String
        public let broadcasterUserName: String
    }
}

public struct EventSubModerate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
    public let action: String
    public let userId: String?
    public let userLogin: String?
    public let userName: String?
    public let followers: Followers?
    public let slow: Slow?
    public let vip: TargetUser?
    public let unvip: TargetUser?
    public let mod: TargetUser?
    public let unmod: TargetUser?
    public let ban: Ban?
    public let unban: TargetUser?
    public let timeout: Timeout?
    public let untimeout: TargetUser?
    public let raid: Raid?
    public let unraid: Empty?
    public let delete: Delete?
    public let automodTerms: AutoModTerms?
    public let unbanRequest: UnbanRequest?
    public let warn: Warn?

    public struct TargetUser: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
    }

    public struct Followers: Codable, Sendable, Equatable {
        public let followDurationMinutes: Int?
    }

    public struct Slow: Codable, Sendable, Equatable {
        public let waitTimeSeconds: Int
    }

    public struct Ban: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let reason: String?
    }

    public struct Timeout: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let reason: String?
        public let expiresAt: Date
    }

    public struct Raid: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let viewerCount: Int?
    }

    public struct Delete: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let messageId: String
        public let messageBody: String?
    }

    public struct AutoModTerms: Codable, Sendable, Equatable {
        public let action: String
        public let list: String
        public let terms: [String]
        public let fromAutomod: Bool?
    }

    public struct UnbanRequest: Codable, Sendable, Equatable {
        public let isApproved: Bool
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let moderatorMessage: String?
    }

    public struct Warn: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let reason: String?
        public let chatRulesCited: [String]?
    }

    public struct Empty: Codable, Sendable, Equatable {}
}

public struct EventSubGuestStarSession: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let sessionId: String?
    public let startedAt: Date?
    public let endedAt: Date?
}

public struct EventSubGuestStarGuestUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let sessionId: String?
    public let guestUserId: String
    public let guestUserLogin: String
    public let guestUserName: String
    public let slotId: String?
    public let state: String
    public let isAudioEnabled: Bool?
    public let isVideoEnabled: Bool?
    public let isLive: Bool?
}

public struct EventSubGuestStarSettingsUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let isModeratorSendLiveEnabled: Bool?
    public let slotCount: Int?
    public let isBrowserSourceAudioEnabled: Bool?
    public let groupLayout: String?
}

public struct EventSubSubscriptionGift: Codable, Sendable, Equatable {
    public let userId: String?
    public let userLogin: String?
    public let userName: String?
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let total: Int
    public let tier: SubscriptionTier
    public let cumulativeTotal: Int?
    public let isAnonymous: Bool
}

public struct EventSubSubscriptionMessage: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let tier: SubscriptionTier
    public let message: ChatMessage.ChatMessageBody
    public let cumulativeMonths: Int
    public let durationMonths: Int
    public let streakMonths: Int?
}

public struct EventSubSubscriptionEnd: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let tier: SubscriptionTier
    public let isGift: Bool
}

public struct EventSubPoll: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let title: String
    public let choices: [Choice]
    public let bitsVoting: Voting?
    public let channelPointsVoting: Voting?
    public let status: String?
    public let durationSeconds: Int?
    public let startedAt: Date
    public let endedAt: Date?

    public struct Choice: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let bitsVotes: Int?
        public let channelPointsVotes: Int?
        public let votes: Int?
    }

    public struct Voting: Codable, Sendable, Equatable {
        public let isEnabled: Bool
        public let amountPerVote: Int?
    }
}

public struct EventSubPrediction: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let title: String
    public let outcomes: [Outcome]
    public let winningOutcomeId: String?
    public let status: String?
    public let startedAt: Date?
    public let locksAt: Date?
    public let lockedAt: Date?
    public let endedAt: Date?

    public struct Outcome: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let color: String
        public let users: Int?
        public let channelPoints: Int?
        public let topPredictors: [TopPredictor]?
    }

    public struct TopPredictor: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let channelPointsWon: Int?
        public let channelPointsUsed: Int
    }
}

public struct EventSubGoal: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let type: String
    public let description: String
    public let currentAmount: Int
    public let targetAmount: Int
    public let startedAt: Date
    public let endedAt: Date?
    public let isAchieved: Bool?
}

public struct EventSubHypeTrain: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let total: Int?
    public let progress: Int?
    public let goal: Int?
    public let level: Int
    public let topContributions: [Contribution]
    public let lastContribution: Contribution?
    public let startedAt: Date
    public let expiresAt: Date?
    public let endedAt: Date?
    public let cooldownEndsAt: Date?
    public let type: String?
    public let isSharedTrain: Bool?
    public let sharedTrainParticipants: [Participant]?

    public struct Contribution: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let type: String
        public let total: Int
    }

    public struct Participant: Codable, Sendable, Equatable {
        public let broadcasterUserId: String
        public let broadcasterUserLogin: String
        public let broadcasterUserName: String
    }
}

public struct EventSubCharityCampaign: Decodable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let charityName: String
    public let charityDescription: String
    public let charityLogo: URL?
    public let charityWebsite: URL?
    public let currentAmount: CharityAmount
    public let targetAmount: CharityAmount
    public let startedAt: Date?
    public let stoppedAt: Date?
}

public struct EventSubCharityDonation: Decodable, Sendable, Equatable {
    public let id: String
    public let campaignId: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let charityName: String
    public let charityDescription: String
    public let charityLogo: URL?
    public let charityWebsite: URL?
    public let amount: CharityAmount
}

public struct EventSubCustomPowerUpRedemption: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let id: String
    public let userInput: String
    public let status: ChannelPointsRedemptionStatus
    public let customPowerUp: PowerUp
    public let redeemedAt: Date

    public struct PowerUp: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let bits: Int
        public let prompt: String
    }

    @available(*, deprecated, message: "Use customPowerUp.bits")
    public var cost: Int? { customPowerUp.bits }
}

public struct EventSubSuspiciousUserMessage: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let lowTrustStatus: String?
    public let sharedBanChannelIds: [String]?
    public let types: [String]?
    public let banEvasionEvaluation: String?
    public let message: ChatMessage.ChatMessageBody
}

public struct EventSubSuspiciousUserUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let lowTrustStatus: String
}

public struct EventSubUnbanRequest: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let text: String?
}

public struct EventSubVIPChange: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubShieldMode: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
    public let startedAt: Date?
    public let endedAt: Date?
}

public struct EventSubShoutout: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let toBroadcasterUserId: String?
    public let toBroadcasterUserLogin: String?
    public let toBroadcasterUserName: String?
    public let fromBroadcasterUserId: String?
    public let fromBroadcasterUserLogin: String?
    public let fromBroadcasterUserName: String?
    public let viewerCount: Int?
    public let startedAt: Date?
}

public struct EventSubWarning: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let reason: String?
}

public struct EventSubConduitShardDisabled: Codable, Sendable, Equatable {
    public let conduitId: String
    public let shardId: String
    public let status: String
    public let transport: Transport?

    public struct Transport: Codable, Sendable, Equatable {
        public let method: String
        public let callback: URL?
        public let sessionId: String?
        public let conduitId: String?
    }
}

public struct EventSubDropEntitlementGrant: Codable, Sendable, Equatable {
    public let id: String?
    public let data: [Entitlement]?

    public struct Entitlement: Codable, Sendable, Equatable {
        public let organizationId: String?
        public let categoryId: String?
        public let categoryName: String?
        public let campaignId: String?
        public let userId: String?
        public let userLogin: String?
        public let userName: String?
        public let entitlementId: String?
        public let benefitId: String?
        public let createdAt: Date?
    }
}

public struct EventSubExtensionBitsTransaction: Codable, Sendable, Equatable {
    public let id: String
    public let extensionClientId: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let product: Product

    public struct Product: Codable, Sendable, Equatable {
        public let name: String
        public let bits: Int
        public let sku: String?
        public let inDevelopment: Bool?
    }
}

public struct EventSubUserAuthorization: Codable, Sendable, Equatable {
    public let clientId: String
    public let userId: String
    public let userLogin: String
    public let userName: String
}

public struct EventSubUserUpdate: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let email: String?
    public let emailVerified: Bool?
    public let description: String?
}

public struct EventSubWhisperMessage: Decodable, Sendable, Equatable {
    public let fromUserId: String
    public let fromUserLogin: String
    public let fromUserName: String
    public let toUserId: String
    public let toUserLogin: String
    public let toUserName: String
    public let whisperId: String
    public let whisper: Whisper

    public struct Whisper: Codable, Sendable, Equatable {
        public let text: String
    }
}
