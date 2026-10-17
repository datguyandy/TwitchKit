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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        title: String,
        language: String,
        categoryId: String,
        categoryName: String,
        contentClassificationLabels: [String]
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.title = title
        self.language = language
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.contentClassificationLabels = contentClassificationLabels
    }
}

public struct EventSubStreamOnline: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let type: TwitchStreamType
    public let startedAt: Date

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        type: TwitchStreamType,
        startedAt: Date
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.type = type
        self.startedAt = startedAt
    }
}

public struct EventSubStreamOffline: Codable, Sendable, Equatable {
    public let id: String?
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String? = nil,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
    }
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
    public let status: AutoModMessageStatus?
    public let heldAt: Date?
    public let reason: String?
    public let automod: AutoModDetails?
    public let blockedTerm: BlockedTermDetails?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        messageId: String,
        message: ChatMessage.ChatMessageBody,
        category: String? = nil,
        level: Int? = nil,
        status: AutoModMessageStatus? = nil,
        heldAt: Date? = nil,
        reason: String? = nil,
        automod: AutoModDetails? = nil,
        blockedTerm: BlockedTermDetails? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.messageId = messageId
        self.message = message
        self.category = category
        self.level = level
        self.status = status
        self.heldAt = heldAt
        self.reason = reason
        self.automod = automod
        self.blockedTerm = blockedTerm
    }

    public struct Boundary: Codable, Sendable, Equatable {
        public let startPos: Int
        public let endPos: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            startPos: Int,
            endPos: Int
        ) {
            self.startPos = startPos
            self.endPos = endPos
        }
    }

    public struct AutoModDetails: Codable, Sendable, Equatable {
        public let category: String
        public let level: Int
        public let boundaries: [Boundary]

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            category: String,
            level: Int,
            boundaries: [Boundary]
        ) {
            self.category = category
            self.level = level
            self.boundaries = boundaries
        }
    }

    /// Populated for both blocked_term and blocked_link reasons.
    public struct BlockedTermDetails: Codable, Sendable, Equatable {
        public let termsFound: [Term]

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            termsFound: [Term]
        ) {
            self.termsFound = termsFound
        }

        public struct Term: Codable, Sendable, Equatable {
            public let termId: String
            public let boundary: Boundary
            public let ownerBroadcasterUserId: String
            public let ownerBroadcasterUserLogin: String
            public let ownerBroadcasterUserName: String

            /// Creates a value directly, for example in tests or SwiftUI previews.
            public init(
                termId: String,
                boundary: Boundary,
                ownerBroadcasterUserId: String,
                ownerBroadcasterUserLogin: String,
                ownerBroadcasterUserName: String
            ) {
                self.termId = termId
                self.boundary = boundary
                self.ownerBroadcasterUserId = ownerBroadcasterUserId
                self.ownerBroadcasterUserLogin = ownerBroadcasterUserLogin
                self.ownerBroadcasterUserName = ownerBroadcasterUserName
            }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String? = nil,
        moderatorUserLogin: String? = nil,
        moderatorUserName: String? = nil,
        overallLevel: Int? = nil,
        disability: Int? = nil,
        aggression: Int? = nil,
        sexualitySexOrGender: Int? = nil,
        misogyny: Int? = nil,
        bullying: Int? = nil,
        swearing: Int? = nil,
        raceEthnicityOrReligion: Int? = nil,
        sexBasedTerms: Int? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.overallLevel = overallLevel
        self.disability = disability
        self.aggression = aggression
        self.sexualitySexOrGender = sexualitySexOrGender
        self.misogyny = misogyny
        self.bullying = bullying
        self.swearing = swearing
        self.raceEthnicityOrReligion = raceEthnicityOrReligion
        self.sexBasedTerms = sexBasedTerms
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String? = nil,
        moderatorUserLogin: String? = nil,
        moderatorUserName: String? = nil,
        action: String,
        fromAutomod: Bool? = nil,
        terms: [String]
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.action = action
        self.fromAutomod = fromAutomod
        self.terms = terms
    }
}

public struct EventSubBitsUse: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let bits: Int
    /// How the Bits were used. The raw string is available as `type.rawValue`.
    public let type: EventSubBitsUseType
    public let message: ChatMessage.ChatMessageBody?
    /// Data about a built-in Power-up. `nil` unless ``type`` is ``EventSubBitsUseType/powerUp``.
    public let powerUp: PowerUp?
    /// Data about a custom Power-up. `nil` unless ``type`` is ``EventSubBitsUseType/customPowerUp``.
    public let customPowerUp: CustomPowerUp?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        bits: Int,
        type: EventSubBitsUseType,
        message: ChatMessage.ChatMessageBody? = nil,
        powerUp: PowerUp? = nil,
        customPowerUp: CustomPowerUp? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.bits = bits
        self.type = type
        self.message = message
        self.powerUp = powerUp
        self.customPowerUp = customPowerUp
    }

    /// A built-in Power-up.
    public struct PowerUp: Codable, Sendable, Equatable {
        /// The Power-up kind: `message_effect`, `celebration`, or `gigantify_an_emote`.
        public let type: String
        /// The emote associated with the Power-up, for example the gigantified emote.
        public let emote: Emote?
        /// The ID of the message effect, for `message_effect` Power-ups.
        public let messageEffectId: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            type: String,
            emote: Emote? = nil,
            messageEffectId: String? = nil
        ) {
            self.type = type
            self.emote = emote
            self.messageEffectId = messageEffectId
        }

        /// The emote a Power-up applies to. Twitch sends only its ID and token here,
        /// not the `emote_set_id` a chat fragment's ``EmoteReference`` requires.
        public struct Emote: Codable, Sendable, Equatable {
            /// The ID that uniquely identifies this emote.
            public let id: String
            /// The human-readable emote token.
            public let name: String?

            /// Creates a value directly, for example in tests or SwiftUI previews.
            public init(
                id: String,
                name: String? = nil
            ) {
                self.id = id
                self.name = name
            }
        }
    }

    /// A custom Power-up the broadcaster created.
    public struct CustomPowerUp: Codable, Sendable, Equatable {
        /// The title of the custom Power-up.
        public let title: String
        /// The ID of the custom Power-up.
        public let rewardId: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            title: String,
            rewardId: String
        ) {
            self.title = title
            self.rewardId = rewardId
        }
    }
}

/// How Bits were used in a `channel.bits.use` event.
///
/// A value Twitch adds later is kept verbatim in ``unknown(_:)``, and the enum
/// accepts a string literal, so comparisons written against the former `String`
/// field (`event.type == "cheer"`) still compile.
public enum EventSubBitsUseType: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    /// The Bits were cheered in chat.
    case cheer
    /// The Bits were spent on a built-in Power-up.
    case powerUp
    /// The Bits were spent on a custom Power-up.
    case customPowerUp
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .cheer: "cheer"
        case .powerUp: "power_up"
        case .customPowerUp: "custom_power_up"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "cheer": .cheer
        case "power_up": .powerUp
        case "custom_power_up": .customPowerUp
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        requesterUserId: String? = nil,
        requesterUserLogin: String? = nil,
        requesterUserName: String? = nil,
        durationSeconds: Int,
        startedAt: Date,
        isAutomatic: Bool? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.requesterUserId = requesterUserId
        self.requesterUserLogin = requesterUserLogin
        self.requesterUserName = requesterUserName
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.isAutomatic = isAutomatic
    }
}

public struct EventSubRaid: Codable, Sendable, Equatable {
    public let fromBroadcasterUserId: String
    public let fromBroadcasterUserLogin: String
    public let fromBroadcasterUserName: String
    public let toBroadcasterUserId: String
    public let toBroadcasterUserLogin: String
    public let toBroadcasterUserName: String
    public let viewers: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        fromBroadcasterUserId: String,
        fromBroadcasterUserLogin: String,
        fromBroadcasterUserName: String,
        toBroadcasterUserId: String,
        toBroadcasterUserLogin: String,
        toBroadcasterUserName: String,
        viewers: Int
    ) {
        self.fromBroadcasterUserId = fromBroadcasterUserId
        self.fromBroadcasterUserLogin = fromBroadcasterUserLogin
        self.fromBroadcasterUserName = fromBroadcasterUserName
        self.toBroadcasterUserId = toBroadcasterUserId
        self.toBroadcasterUserLogin = toBroadcasterUserLogin
        self.toBroadcasterUserName = toBroadcasterUserName
        self.viewers = viewers
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        isAnonymous: Bool,
        userId: String? = nil,
        userLogin: String? = nil,
        userName: String? = nil,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        message: String,
        bits: Int
    ) {
        self.isAnonymous = isAnonymous
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.message = message
        self.bits = bits
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String,
        moderatorUserLogin: String,
        moderatorUserName: String,
        reason: String,
        bannedAt: Date,
        endsAt: Date? = nil,
        isPermanent: Bool
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.reason = reason
        self.bannedAt = bannedAt
        self.endsAt = endsAt
        self.isPermanent = isPermanent
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String,
        moderatorUserLogin: String,
        moderatorUserName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
    }
}

public struct EventSubModeratorChange: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        userInput: String,
        status: ChannelPointsRedemptionStatus,
        reward: Reward,
        redeemedAt: Date
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.userInput = userInput
        self.status = status
        self.reward = reward
        self.redeemedAt = redeemedAt
    }

    public struct Reward: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let prompt: String
        public let cost: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            id: String,
            title: String,
            prompt: String,
            cost: Int
        ) {
            self.id = id
            self.title = title
            self.prompt = prompt
            self.cost = cost
        }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        isEnabled: Bool? = nil,
        isPaused: Bool? = nil,
        isInStock: Bool? = nil,
        title: String,
        cost: Int,
        prompt: String? = nil,
        isUserInputRequired: Bool? = nil,
        shouldRedemptionsSkipRequestQueue: Bool? = nil,
        cooldownExpiresAt: Date? = nil,
        redemptionsRedeemedCurrentStream: Int? = nil,
        maxPerStream: Limit? = nil,
        maxPerUserPerStream: Limit? = nil,
        globalCooldown: Cooldown? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.isEnabled = isEnabled
        self.isPaused = isPaused
        self.isInStock = isInStock
        self.title = title
        self.cost = cost
        self.prompt = prompt
        self.isUserInputRequired = isUserInputRequired
        self.shouldRedemptionsSkipRequestQueue = shouldRedemptionsSkipRequestQueue
        self.cooldownExpiresAt = cooldownExpiresAt
        self.redemptionsRedeemedCurrentStream = redemptionsRedeemedCurrentStream
        self.maxPerStream = maxPerStream
        self.maxPerUserPerStream = maxPerUserPerStream
        self.globalCooldown = globalCooldown
    }

    public struct Limit: Codable, Sendable, Equatable {
        public let isEnabled: Bool
        public let value: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            isEnabled: Bool,
            value: Int? = nil
        ) {
            self.isEnabled = isEnabled
            self.value = value
        }
    }

    public struct Cooldown: Codable, Sendable, Equatable {
        public let isEnabled: Bool
        public let seconds: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            isEnabled: Bool,
            seconds: Int? = nil
        ) {
            self.isEnabled = isEnabled
            self.seconds = seconds
        }
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
    /// The user's message. Version 2 fragments carry only the emote ID, so this
    /// uses ``Message`` rather than ``ChatMessage/ChatMessageBody``.
    public let message: Message?
    public let userInput: String?
    public let redeemedAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        id: String? = nil,
        reward: Reward,
        message: Message? = nil,
        userInput: String? = nil,
        redeemedAt: Date? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.id = id
        self.reward = reward
        self.message = message
        self.userInput = userInput
        self.redeemedAt = redeemedAt
    }

    public struct Reward: Codable, Sendable, Equatable {
        public let type: String
        /// The reward cost, as sent by version 1.
        public let cost: Int?
        public let unlockedEmote: TwitchEmote?
        /// The Channel Points spent, as sent by version 2.
        public let channelPoints: Int?
        /// The emote associated with the reward, as sent by version 2.
        public let emote: Emote?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            type: String,
            cost: Int? = nil,
            unlockedEmote: TwitchEmote? = nil,
            channelPoints: Int? = nil,
            emote: Emote? = nil
        ) {
            self.type = type
            self.cost = cost
            self.unlockedEmote = unlockedEmote
            self.channelPoints = channelPoints
            self.emote = emote
        }

        /// An emote tied to an automatic reward.
        public struct Emote: Codable, Sendable, Equatable {
            /// The emote ID.
            public let id: String
            /// The human-readable emote token.
            public let name: String?

            /// Creates a value directly, for example in tests or SwiftUI previews.
            public init(
                id: String,
                name: String? = nil
            ) {
                self.id = id
                self.name = name
            }
        }
    }

    /// The message attached to an automatic reward redemption.
    public struct Message: Codable, Sendable, Equatable {
        /// The chat message in plain text.
        public let text: String
        /// The ordered message fragments.
        public let fragments: [Fragment]?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            text: String,
            fragments: [Fragment]? = nil
        ) {
            self.text = text
            self.fragments = fragments
        }

        /// One fragment of an automatic reward message.
        public struct Fragment: Codable, Sendable, Equatable {
            /// The fragment type: `text` or `emote`.
            public let type: ChatFragmentType
            /// The fragment's text.
            public let text: String
            /// The emote, for `emote` fragments.
            public let emote: Emote?

            /// Creates a value directly, for example in tests or SwiftUI previews.
            public init(
                type: ChatFragmentType,
                text: String,
                emote: Emote? = nil
            ) {
                self.type = type
                self.text = text
                self.emote = emote
            }

            /// An emote in a fragment. Twitch sends only its ID here.
            public struct Emote: Codable, Sendable, Equatable {
                /// The ID that uniquely identifies this emote.
                public let id: String

                /// Creates a value directly, for example in tests or SwiftUI previews.
                public init(
                    id: String
                ) {
                    self.id = id
                }
            }
        }
    }
}

public struct EventSubChatClear: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
    }
}

public struct EventSubChatClearUserMessages: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let targetUserId: String
    public let targetUserLogin: String
    public let targetUserName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        targetUserId: String,
        targetUserLogin: String,
        targetUserName: String
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.targetUserId = targetUserId
        self.targetUserLogin = targetUserLogin
        self.targetUserName = targetUserName
    }
}

public struct EventSubChatMessageDelete: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let targetUserId: String
    public let targetUserLogin: String
    public let targetUserName: String
    public let messageId: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        targetUserId: String,
        targetUserLogin: String,
        targetUserName: String,
        messageId: String
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.targetUserId = targetUserId
        self.targetUserLogin = targetUserLogin
        self.targetUserName = targetUserName
        self.messageId = messageId
    }
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
    /// The kind of notice. The raw string is available as `noticeType.rawValue`.
    public let noticeType: EventSubChatNoticeType
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
    /// Details of a gifted Drops summary. `nil` unless ``noticeType`` is ``EventSubChatNoticeType/giftedDropsSummary``.
    public let giftedDropsSummary: GiftedDropsSummary?

    /// The broadcaster ID of the shared-chat channel the notice came from; `nil` outside shared chat
    /// or when the notice happened in the subscribed broadcaster's own channel.
    public let sourceBroadcasterUserId: String?
    /// The broadcaster login of the shared-chat channel the notice came from.
    public let sourceBroadcasterUserLogin: String?
    /// The broadcaster display name of the shared-chat channel the notice came from.
    public let sourceBroadcasterUserName: String?
    /// The ID of the source message in the shared-chat channel the notice came from.
    public let sourceMessageId: String?
    /// The chatter's badges in the shared-chat channel the notice came from.
    public let sourceBadges: [ChatBadge]?
    /// Whether the notice is only sent to the source channel. `nil` outside shared chat.
    public let isSourceOnly: Bool?

    // Shared-chat variants: the same payloads as their non-shared counterparts, for a
    // notice that happened in another channel of the shared chat session.
    public let sharedChatSub: Subscription?
    public let sharedChatResub: Resubscription?
    public let sharedChatSubGift: SubscriptionGift?
    public let sharedChatCommunitySubGift: CommunitySubscriptionGift?
    public let sharedChatGiftPaidUpgrade: GiftPaidUpgrade?
    public let sharedChatPrimePaidUpgrade: PrimePaidUpgrade?
    public let sharedChatPayItForward: PayItForward?
    public let sharedChatRaid: Raid?
    public let sharedChatAnnouncement: Announcement?
    public let sharedChatModiversary: Modiversary?
    public let sharedChatGiftedDropsSummary: GiftedDropsSummary?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        chatterUserId: String,
        chatterUserLogin: String,
        chatterUserName: String,
        chatterIsAnonymous: Bool? = nil,
        color: String? = nil,
        badges: [ChatBadge],
        systemMessage: String,
        messageId: String,
        message: ChatMessage.ChatMessageBody,
        noticeType: EventSubChatNoticeType,
        sub: Subscription? = nil,
        resub: Resubscription? = nil,
        subGift: SubscriptionGift? = nil,
        communitySubGift: CommunitySubscriptionGift? = nil,
        giftPaidUpgrade: GiftPaidUpgrade? = nil,
        primePaidUpgrade: PrimePaidUpgrade? = nil,
        raid: Raid? = nil,
        unraid: Empty? = nil,
        payItForward: PayItForward? = nil,
        announcement: Announcement? = nil,
        charityDonation: CharityDonation? = nil,
        bitsBadgeTier: BitsBadgeTier? = nil,
        watchStreak: WatchStreak? = nil,
        modiversary: Modiversary? = nil,
        sharedChatModiversary: Modiversary? = nil,
        isSourceOnly: Bool? = nil,
        giftedDropsSummary: GiftedDropsSummary? = nil,
        sourceBroadcasterUserId: String? = nil,
        sourceBroadcasterUserLogin: String? = nil,
        sourceBroadcasterUserName: String? = nil,
        sourceMessageId: String? = nil,
        sourceBadges: [ChatBadge]? = nil,
        sharedChatSub: Subscription? = nil,
        sharedChatResub: Resubscription? = nil,
        sharedChatSubGift: SubscriptionGift? = nil,
        sharedChatCommunitySubGift: CommunitySubscriptionGift? = nil,
        sharedChatGiftPaidUpgrade: GiftPaidUpgrade? = nil,
        sharedChatPrimePaidUpgrade: PrimePaidUpgrade? = nil,
        sharedChatPayItForward: PayItForward? = nil,
        sharedChatRaid: Raid? = nil,
        sharedChatAnnouncement: Announcement? = nil,
        sharedChatGiftedDropsSummary: GiftedDropsSummary? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.chatterUserId = chatterUserId
        self.chatterUserLogin = chatterUserLogin
        self.chatterUserName = chatterUserName
        self.chatterIsAnonymous = chatterIsAnonymous
        self.color = color
        self.badges = badges
        self.systemMessage = systemMessage
        self.messageId = messageId
        self.message = message
        self.noticeType = noticeType
        self.sub = sub
        self.resub = resub
        self.subGift = subGift
        self.communitySubGift = communitySubGift
        self.giftPaidUpgrade = giftPaidUpgrade
        self.primePaidUpgrade = primePaidUpgrade
        self.raid = raid
        self.unraid = unraid
        self.payItForward = payItForward
        self.announcement = announcement
        self.charityDonation = charityDonation
        self.bitsBadgeTier = bitsBadgeTier
        self.watchStreak = watchStreak
        self.modiversary = modiversary
        self.sharedChatModiversary = sharedChatModiversary
        self.isSourceOnly = isSourceOnly
        self.giftedDropsSummary = giftedDropsSummary
        self.sourceBroadcasterUserId = sourceBroadcasterUserId
        self.sourceBroadcasterUserLogin = sourceBroadcasterUserLogin
        self.sourceBroadcasterUserName = sourceBroadcasterUserName
        self.sourceMessageId = sourceMessageId
        self.sourceBadges = sourceBadges
        self.sharedChatSub = sharedChatSub
        self.sharedChatResub = sharedChatResub
        self.sharedChatSubGift = sharedChatSubGift
        self.sharedChatCommunitySubGift = sharedChatCommunitySubGift
        self.sharedChatGiftPaidUpgrade = sharedChatGiftPaidUpgrade
        self.sharedChatPrimePaidUpgrade = sharedChatPrimePaidUpgrade
        self.sharedChatPayItForward = sharedChatPayItForward
        self.sharedChatRaid = sharedChatRaid
        self.sharedChatAnnouncement = sharedChatAnnouncement
        self.sharedChatGiftedDropsSummary = sharedChatGiftedDropsSummary
    }

    /// A summary of gifted Drops, sent for `gifted_drops_summary` notices.
    public struct GiftedDropsSummary: Codable, Sendable, Equatable {
        /// The number of users who received a gifted Drop.
        public let recipientCount: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            recipientCount: Int
        ) {
            self.recipientCount = recipientCount
        }
    }

    public struct WatchStreak: Codable, Sendable, Equatable {
        public let streakCount: Int
        public let channelPointsAwarded: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            streakCount: Int,
            channelPointsAwarded: Int
        ) {
            self.streakCount = streakCount
            self.channelPointsAwarded = channelPointsAwarded
        }
    }

    public struct Modiversary: Codable, Sendable, Equatable {
        public let months: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            months: Int
        ) {
            self.months = months
        }
    }

    public struct Subscription: Codable, Sendable, Equatable {
        public let subTier: SubscriptionTier
        public let isPrime: Bool
        public let durationMonths: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            subTier: SubscriptionTier,
            isPrime: Bool,
            durationMonths: Int
        ) {
            self.subTier = subTier
            self.isPrime = isPrime
            self.durationMonths = durationMonths
        }
    }

    public struct Resubscription: Codable, Sendable, Equatable {
        public let cumulativeMonths: Int
        public let durationMonths: Int
        public let streakMonths: Int?
        public let subTier: SubscriptionTier
        /// Whether this is a Prime subscription. Twitch documents the field as optional.
        public let isPrime: Bool?
        public let isGift: Bool
        public let gifterIsAnonymous: Bool?
        public let gifterUserId: String?
        public let gifterUserLogin: String?
        public let gifterUserName: String?

        private enum CodingKeys: String, CodingKey {
            case cumulativeMonths, durationMonths, streakMonths, subTier, isPrime, isGift
            case gifterIsAnonymous, gifterUserId, gifterUserLogin, gifterUserName
        }

        /// The tier key used by Twitch's published `channel.chat.notification` examples.
        private enum ExampleKeys: String, CodingKey {
            case subPlan
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            cumulativeMonths = try container.decode(Int.self, forKey: .cumulativeMonths)
            durationMonths = try container.decode(Int.self, forKey: .durationMonths)
            streakMonths = try container.decodeIfPresent(Int.self, forKey: .streakMonths)
            if let tier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .subTier) {
                subTier = tier
            } else {
                subTier = try decoder.container(keyedBy: ExampleKeys.self).decode(SubscriptionTier.self, forKey: .subPlan)
            }
            isPrime = try container.decodeIfPresent(Bool.self, forKey: .isPrime)
            isGift = try container.decode(Bool.self, forKey: .isGift)
            gifterIsAnonymous = try container.decodeIfPresent(Bool.self, forKey: .gifterIsAnonymous)
            gifterUserId = try container.decodeIfPresent(String.self, forKey: .gifterUserId)
            gifterUserLogin = try container.decodeIfPresent(String.self, forKey: .gifterUserLogin)
            gifterUserName = try container.decodeIfPresent(String.self, forKey: .gifterUserName)
        }

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            cumulativeMonths: Int,
            durationMonths: Int,
            streakMonths: Int? = nil,
            subTier: SubscriptionTier,
            isPrime: Bool? = nil,
            isGift: Bool,
            gifterIsAnonymous: Bool? = nil,
            gifterUserId: String? = nil,
            gifterUserLogin: String? = nil,
            gifterUserName: String? = nil
        ) {
            self.cumulativeMonths = cumulativeMonths
            self.durationMonths = durationMonths
            self.streakMonths = streakMonths
            self.subTier = subTier
            self.isPrime = isPrime
            self.isGift = isGift
            self.gifterIsAnonymous = gifterIsAnonymous
            self.gifterUserId = gifterUserId
            self.gifterUserLogin = gifterUserLogin
            self.gifterUserName = gifterUserName
        }
    }

    public struct SubscriptionGift: Codable, Sendable, Equatable {
        public let durationMonths: Int
        public let cumulativeTotal: Int?
        public let recipientUserId: String
        public let recipientUserLogin: String
        public let recipientUserName: String
        public let subTier: SubscriptionTier
        public let communityGiftId: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            durationMonths: Int,
            cumulativeTotal: Int? = nil,
            recipientUserId: String,
            recipientUserLogin: String,
            recipientUserName: String,
            subTier: SubscriptionTier,
            communityGiftId: String? = nil
        ) {
            self.durationMonths = durationMonths
            self.cumulativeTotal = cumulativeTotal
            self.recipientUserId = recipientUserId
            self.recipientUserLogin = recipientUserLogin
            self.recipientUserName = recipientUserName
            self.subTier = subTier
            self.communityGiftId = communityGiftId
        }
    }

    public struct CommunitySubscriptionGift: Codable, Sendable, Equatable {
        public let id: String
        public let total: Int
        public let subTier: SubscriptionTier
        public let cumulativeTotal: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            id: String,
            total: Int,
            subTier: SubscriptionTier,
            cumulativeTotal: Int? = nil
        ) {
            self.id = id
            self.total = total
            self.subTier = subTier
            self.cumulativeTotal = cumulativeTotal
        }
    }

    public struct GiftPaidUpgrade: Codable, Sendable, Equatable {
        public let gifterIsAnonymous: Bool
        public let gifterUserId: String?
        public let gifterUserLogin: String?
        public let gifterUserName: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            gifterIsAnonymous: Bool,
            gifterUserId: String? = nil,
            gifterUserLogin: String? = nil,
            gifterUserName: String? = nil
        ) {
            self.gifterIsAnonymous = gifterIsAnonymous
            self.gifterUserId = gifterUserId
            self.gifterUserLogin = gifterUserLogin
            self.gifterUserName = gifterUserName
        }
    }

    public struct PrimePaidUpgrade: Codable, Sendable, Equatable {
        public let subTier: SubscriptionTier

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            subTier: SubscriptionTier
        ) {
            self.subTier = subTier
        }
    }

    public struct Raid: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let viewerCount: Int
        public let profileImageUrl: URL?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            viewerCount: Int,
            profileImageUrl: URL? = nil
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.viewerCount = viewerCount
            self.profileImageUrl = profileImageUrl
        }
    }

    public struct PayItForward: Codable, Sendable, Equatable {
        public let gifterIsAnonymous: Bool
        public let gifterUserId: String?
        public let gifterUserLogin: String?
        public let gifterUserName: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            gifterIsAnonymous: Bool,
            gifterUserId: String? = nil,
            gifterUserLogin: String? = nil,
            gifterUserName: String? = nil
        ) {
            self.gifterIsAnonymous = gifterIsAnonymous
            self.gifterUserId = gifterUserId
            self.gifterUserLogin = gifterUserLogin
            self.gifterUserName = gifterUserName
        }
    }

    public struct Announcement: Codable, Sendable, Equatable {
        public let color: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            color: String
        ) {
            self.color = color
        }
    }

    public struct CharityDonation: Decodable, Sendable, Equatable {
        public let charityName: String
        public let amount: CharityAmount

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            charityName: String,
            amount: CharityAmount
        ) {
            self.charityName = charityName
            self.amount = amount
        }
    }

    public struct BitsBadgeTier: Codable, Sendable, Equatable {
        public let tier: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            tier: Int
        ) {
            self.tier = tier
        }
    }

    public struct Empty: Codable, Sendable, Equatable {}
}

/// The kind of a `channel.chat.notification` notice.
///
/// A value Twitch adds later is kept verbatim in ``unknown(_:)``; Twitch's own documented
/// `unknown` notice type also decodes there, as `.unknown("unknown")`. The enum accepts a
/// string literal, so comparisons written against the former `String` field
/// (`notification.noticeType == "sub"`) still compile.
public enum EventSubChatNoticeType: Codable, RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    case sub
    case resub
    case subGift
    case communitySubGift
    case giftPaidUpgrade
    case primePaidUpgrade
    case raid
    case unraid
    case payItForward
    case announcement
    case bitsBadgeTier
    case charityDonation
    case watchStreak
    case modiversary
    case giftedDropsSummary
    case sharedChatSub
    case sharedChatResub
    case sharedChatSubGift
    case sharedChatCommunitySubGift
    case sharedChatGiftPaidUpgrade
    case sharedChatPrimePaidUpgrade
    case sharedChatRaid
    case sharedChatPayItForward
    case sharedChatAnnouncement
    case sharedChatModiversary
    case sharedChatGiftedDropsSummary
    /// A value this version of TwitchKit doesn't know, kept verbatim.
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .sub: "sub"
        case .resub: "resub"
        case .subGift: "sub_gift"
        case .communitySubGift: "community_sub_gift"
        case .giftPaidUpgrade: "gift_paid_upgrade"
        case .primePaidUpgrade: "prime_paid_upgrade"
        case .raid: "raid"
        case .unraid: "unraid"
        case .payItForward: "pay_it_forward"
        case .announcement: "announcement"
        case .bitsBadgeTier: "bits_badge_tier"
        case .charityDonation: "charity_donation"
        case .watchStreak: "watch_streak"
        case .modiversary: "modiversary"
        case .giftedDropsSummary: "gifted_drops_summary"
        case .sharedChatSub: "shared_chat_sub"
        case .sharedChatResub: "shared_chat_resub"
        case .sharedChatSubGift: "shared_chat_sub_gift"
        case .sharedChatCommunitySubGift: "shared_chat_community_sub_gift"
        case .sharedChatGiftPaidUpgrade: "shared_chat_gift_paid_upgrade"
        case .sharedChatPrimePaidUpgrade: "shared_chat_prime_paid_upgrade"
        case .sharedChatRaid: "shared_chat_raid"
        case .sharedChatPayItForward: "shared_chat_pay_it_forward"
        case .sharedChatAnnouncement: "shared_chat_announcement"
        case .sharedChatModiversary: "shared_chat_modiversary"
        case .sharedChatGiftedDropsSummary: "shared_chat_gifted_drops_summary"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String) {
        self = switch rawValue {
        case "sub": .sub
        case "resub": .resub
        case "sub_gift": .subGift
        case "community_sub_gift": .communitySubGift
        case "gift_paid_upgrade": .giftPaidUpgrade
        case "prime_paid_upgrade": .primePaidUpgrade
        case "raid": .raid
        case "unraid": .unraid
        case "pay_it_forward": .payItForward
        case "announcement": .announcement
        case "bits_badge_tier": .bitsBadgeTier
        case "charity_donation": .charityDonation
        case "watch_streak": .watchStreak
        case "modiversary": .modiversary
        case "gifted_drops_summary": .giftedDropsSummary
        case "shared_chat_sub": .sharedChatSub
        case "shared_chat_resub": .sharedChatResub
        case "shared_chat_sub_gift": .sharedChatSubGift
        case "shared_chat_community_sub_gift": .sharedChatCommunitySubGift
        case "shared_chat_gift_paid_upgrade": .sharedChatGiftPaidUpgrade
        case "shared_chat_prime_paid_upgrade": .sharedChatPrimePaidUpgrade
        case "shared_chat_raid": .sharedChatRaid
        case "shared_chat_pay_it_forward": .sharedChatPayItForward
        case "shared_chat_announcement": .sharedChatAnnouncement
        case "shared_chat_modiversary": .sharedChatModiversary
        case "shared_chat_gifted_drops_summary": .sharedChatGiftedDropsSummary
        default: .unknown(rawValue)
        }
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    /// The moderation outcome. Only `channel.chat.user_message_update` carries it;
    /// it's `nil` for `channel.chat.user_message_hold`.
    public let status: ChatUserMessageStatus?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        messageId: String,
        message: ChatMessage.ChatMessageBody,
        status: ChatUserMessageStatus? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.messageId = messageId
        self.message = message
        self.status = status
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        emoteMode: Bool,
        followerMode: Bool,
        followerModeDurationMinutes: Int? = nil,
        slowMode: Bool,
        slowModeWaitTimeSeconds: Int? = nil,
        subscriberMode: Bool,
        uniqueChatMode: Bool
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.emoteMode = emoteMode
        self.followerMode = followerMode
        self.followerModeDurationMinutes = followerModeDurationMinutes
        self.slowMode = slowMode
        self.slowModeWaitTimeSeconds = slowModeWaitTimeSeconds
        self.subscriberMode = subscriberMode
        self.uniqueChatMode = uniqueChatMode
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        sessionId: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        hostBroadcasterUserId: String? = nil,
        hostBroadcasterUserLogin: String? = nil,
        hostBroadcasterUserName: String? = nil,
        participants: [Participant]? = nil,
        startedAt: Date? = nil,
        updatedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.sessionId = sessionId
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.hostBroadcasterUserId = hostBroadcasterUserId
        self.hostBroadcasterUserLogin = hostBroadcasterUserLogin
        self.hostBroadcasterUserName = hostBroadcasterUserName
        self.participants = participants
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.endedAt = endedAt
    }

    public struct Participant: Codable, Sendable, Equatable {
        public let broadcasterUserId: String
        public let broadcasterUserLogin: String
        public let broadcasterUserName: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            broadcasterUserId: String,
            broadcasterUserLogin: String,
            broadcasterUserName: String
        ) {
            self.broadcasterUserId = broadcasterUserId
            self.broadcasterUserLogin = broadcasterUserLogin
            self.broadcasterUserName = broadcasterUserName
        }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String,
        moderatorUserLogin: String,
        moderatorUserName: String,
        action: String,
        userId: String? = nil,
        userLogin: String? = nil,
        userName: String? = nil,
        followers: Followers? = nil,
        slow: Slow? = nil,
        vip: TargetUser? = nil,
        unvip: TargetUser? = nil,
        mod: TargetUser? = nil,
        unmod: TargetUser? = nil,
        ban: Ban? = nil,
        unban: TargetUser? = nil,
        timeout: Timeout? = nil,
        untimeout: TargetUser? = nil,
        raid: Raid? = nil,
        unraid: Empty? = nil,
        delete: Delete? = nil,
        automodTerms: AutoModTerms? = nil,
        unbanRequest: UnbanRequest? = nil,
        warn: Warn? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.action = action
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.followers = followers
        self.slow = slow
        self.vip = vip
        self.unvip = unvip
        self.mod = mod
        self.unmod = unmod
        self.ban = ban
        self.unban = unban
        self.timeout = timeout
        self.untimeout = untimeout
        self.raid = raid
        self.unraid = unraid
        self.delete = delete
        self.automodTerms = automodTerms
        self.unbanRequest = unbanRequest
        self.warn = warn
    }

    public struct TargetUser: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
        }
    }

    public struct Followers: Codable, Sendable, Equatable {
        public let followDurationMinutes: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            followDurationMinutes: Int? = nil
        ) {
            self.followDurationMinutes = followDurationMinutes
        }
    }

    public struct Slow: Codable, Sendable, Equatable {
        public let waitTimeSeconds: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            waitTimeSeconds: Int
        ) {
            self.waitTimeSeconds = waitTimeSeconds
        }
    }

    public struct Ban: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let reason: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            reason: String? = nil
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.reason = reason
        }
    }

    public struct Timeout: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let reason: String?
        public let expiresAt: Date

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            reason: String? = nil,
            expiresAt: Date
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.reason = reason
            self.expiresAt = expiresAt
        }
    }

    public struct Raid: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let viewerCount: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            viewerCount: Int? = nil
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.viewerCount = viewerCount
        }
    }

    public struct Delete: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let messageId: String
        public let messageBody: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            messageId: String,
            messageBody: String? = nil
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.messageId = messageId
            self.messageBody = messageBody
        }
    }

    public struct AutoModTerms: Codable, Sendable, Equatable {
        public let action: String
        public let list: String
        public let terms: [String]
        public let fromAutomod: Bool?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            action: String,
            list: String,
            terms: [String],
            fromAutomod: Bool? = nil
        ) {
            self.action = action
            self.list = list
            self.terms = terms
            self.fromAutomod = fromAutomod
        }
    }

    public struct UnbanRequest: Codable, Sendable, Equatable {
        public let isApproved: Bool
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let moderatorMessage: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            isApproved: Bool,
            userId: String,
            userLogin: String,
            userName: String,
            moderatorMessage: String? = nil
        ) {
            self.isApproved = isApproved
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.moderatorMessage = moderatorMessage
        }
    }

    public struct Warn: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let reason: String?
        public let chatRulesCited: [String]?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            reason: String? = nil,
            chatRulesCited: [String]? = nil
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.reason = reason
            self.chatRulesCited = chatRulesCited
        }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        sessionId: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct EventSubGuestStarGuestUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let sessionId: String?
    // Twitch sends the guest fields and state as null when the slot is now empty.
    public let guestUserId: String?
    public let guestUserLogin: String?
    public let guestUserName: String?
    public let slotId: String?
    public let state: GuestStarGuestState?
    public let isAudioEnabled: Bool?
    public let isVideoEnabled: Bool?
    public let isLive: Bool?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String? = nil,
        moderatorUserLogin: String? = nil,
        moderatorUserName: String? = nil,
        sessionId: String? = nil,
        guestUserId: String? = nil,
        guestUserLogin: String? = nil,
        guestUserName: String? = nil,
        slotId: String? = nil,
        state: GuestStarGuestState? = nil,
        isAudioEnabled: Bool? = nil,
        isVideoEnabled: Bool? = nil,
        isLive: Bool? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.sessionId = sessionId
        self.guestUserId = guestUserId
        self.guestUserLogin = guestUserLogin
        self.guestUserName = guestUserName
        self.slotId = slotId
        self.state = state
        self.isAudioEnabled = isAudioEnabled
        self.isVideoEnabled = isVideoEnabled
        self.isLive = isLive
    }
}

public struct EventSubGuestStarSettingsUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let isModeratorSendLiveEnabled: Bool?
    public let slotCount: Int?
    public let isBrowserSourceAudioEnabled: Bool?
    public let groupLayout: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        isModeratorSendLiveEnabled: Bool? = nil,
        slotCount: Int? = nil,
        isBrowserSourceAudioEnabled: Bool? = nil,
        groupLayout: String? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.isModeratorSendLiveEnabled = isModeratorSendLiveEnabled
        self.slotCount = slotCount
        self.isBrowserSourceAudioEnabled = isBrowserSourceAudioEnabled
        self.groupLayout = groupLayout
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String? = nil,
        userLogin: String? = nil,
        userName: String? = nil,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        total: Int,
        tier: SubscriptionTier,
        cumulativeTotal: Int? = nil,
        isAnonymous: Bool
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.total = total
        self.tier = tier
        self.cumulativeTotal = cumulativeTotal
        self.isAnonymous = isAnonymous
    }
}

public struct EventSubSubscriptionMessage: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let tier: SubscriptionTier
    /// The resubscription message. Twitch sends text plus emote positions here,
    /// not the fragment list a ``ChatMessage/ChatMessageBody`` carries.
    public let message: Message
    public let cumulativeMonths: Int
    public let durationMonths: Int
    public let streakMonths: Int?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        tier: SubscriptionTier,
        message: Message,
        cumulativeMonths: Int,
        durationMonths: Int,
        streakMonths: Int? = nil
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.tier = tier
        self.message = message
        self.cumulativeMonths = cumulativeMonths
        self.durationMonths = durationMonths
        self.streakMonths = streakMonths
    }

    /// The text of a resubscription message and where its emotes appear.
    public struct Message: Codable, Sendable, Equatable {
        /// The text of the resubscription chat message.
        public let text: String
        /// The emotes in the text, with their positions. `nil` or empty when there are none.
        public let emotes: [Emote]?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            text: String,
            emotes: [Emote]? = nil
        ) {
            self.text = text
            self.emotes = emotes
        }

        /// An emote's ID and its position in the message text.
        public struct Emote: Codable, Sendable, Equatable {
            /// The index of where the emote starts in the text.
            public let begin: Int
            /// The index of where the emote ends in the text.
            public let end: Int
            /// The emote ID.
            public let id: String

            /// Creates a value directly, for example in tests or SwiftUI previews.
            public init(
                begin: Int,
                end: Int,
                id: String
            ) {
                self.begin = begin
                self.end = end
                self.id = id
            }
        }
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        tier: SubscriptionTier,
        isGift: Bool
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.tier = tier
        self.isGift = isGift
    }
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
    public let status: TwitchPollStatus?
    public let durationSeconds: Int?
    public let startedAt: Date
    public let endedAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        title: String,
        choices: [Choice],
        bitsVoting: Voting? = nil,
        channelPointsVoting: Voting? = nil,
        status: TwitchPollStatus? = nil,
        durationSeconds: Int? = nil,
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.title = title
        self.choices = choices
        self.bitsVoting = bitsVoting
        self.channelPointsVoting = channelPointsVoting
        self.status = status
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public struct Choice: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let bitsVotes: Int?
        public let channelPointsVotes: Int?
        public let votes: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            id: String,
            title: String,
            bitsVotes: Int? = nil,
            channelPointsVotes: Int? = nil,
            votes: Int? = nil
        ) {
            self.id = id
            self.title = title
            self.bitsVotes = bitsVotes
            self.channelPointsVotes = channelPointsVotes
            self.votes = votes
        }
    }

    public struct Voting: Codable, Sendable, Equatable {
        public let isEnabled: Bool
        public let amountPerVote: Int?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            isEnabled: Bool,
            amountPerVote: Int? = nil
        ) {
            self.isEnabled = isEnabled
            self.amountPerVote = amountPerVote
        }
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
    public let status: TwitchPredictionStatus?
    public let startedAt: Date?
    public let locksAt: Date?
    public let lockedAt: Date?
    public let endedAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        title: String,
        outcomes: [Outcome],
        winningOutcomeId: String? = nil,
        status: TwitchPredictionStatus? = nil,
        startedAt: Date? = nil,
        locksAt: Date? = nil,
        lockedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.title = title
        self.outcomes = outcomes
        self.winningOutcomeId = winningOutcomeId
        self.status = status
        self.startedAt = startedAt
        self.locksAt = locksAt
        self.lockedAt = lockedAt
        self.endedAt = endedAt
    }

    public struct Outcome: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let color: String
        public let users: Int?
        public let channelPoints: Int?
        public let topPredictors: [TopPredictor]?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            id: String,
            title: String,
            color: String,
            users: Int? = nil,
            channelPoints: Int? = nil,
            topPredictors: [TopPredictor]? = nil
        ) {
            self.id = id
            self.title = title
            self.color = color
            self.users = users
            self.channelPoints = channelPoints
            self.topPredictors = topPredictors
        }
    }

    public struct TopPredictor: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let channelPointsWon: Int?
        public let channelPointsUsed: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            channelPointsWon: Int? = nil,
            channelPointsUsed: Int
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.channelPointsWon = channelPointsWon
            self.channelPointsUsed = channelPointsUsed
        }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        type: String,
        description: String,
        currentAmount: Int,
        targetAmount: Int,
        startedAt: Date,
        endedAt: Date? = nil,
        isAchieved: Bool? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.type = type
        self.description = description
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isAchieved = isAchieved
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        total: Int? = nil,
        progress: Int? = nil,
        goal: Int? = nil,
        level: Int,
        topContributions: [Contribution],
        lastContribution: Contribution? = nil,
        startedAt: Date,
        expiresAt: Date? = nil,
        endedAt: Date? = nil,
        cooldownEndsAt: Date? = nil,
        type: String? = nil,
        isSharedTrain: Bool? = nil,
        sharedTrainParticipants: [Participant]? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.total = total
        self.progress = progress
        self.goal = goal
        self.level = level
        self.topContributions = topContributions
        self.lastContribution = lastContribution
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.endedAt = endedAt
        self.cooldownEndsAt = cooldownEndsAt
        self.type = type
        self.isSharedTrain = isSharedTrain
        self.sharedTrainParticipants = sharedTrainParticipants
    }

    public struct Contribution: Codable, Sendable, Equatable {
        public let userId: String
        public let userLogin: String
        public let userName: String
        public let type: String
        public let total: Int

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            userId: String,
            userLogin: String,
            userName: String,
            type: String,
            total: Int
        ) {
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.type = type
            self.total = total
        }
    }

    public struct Participant: Codable, Sendable, Equatable {
        public let broadcasterUserId: String
        public let broadcasterUserLogin: String
        public let broadcasterUserName: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            broadcasterUserId: String,
            broadcasterUserLogin: String,
            broadcasterUserName: String
        ) {
            self.broadcasterUserId = broadcasterUserId
            self.broadcasterUserLogin = broadcasterUserLogin
            self.broadcasterUserName = broadcasterUserName
        }
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

    private enum CodingKeys: String, CodingKey {
        case id, broadcasterUserId, broadcasterUserLogin, broadcasterUserName
        case charityName, charityDescription, charityLogo, charityWebsite
        case currentAmount, targetAmount, startedAt, stoppedAt
    }

    /// The broadcaster keys Twitch documents for the campaign start, progress and stop events.
    private enum CampaignBroadcasterKeys: String, CodingKey {
        case broadcasterId, broadcasterLogin, broadcasterName
    }

    // Twitch documents `broadcaster_id`/`broadcaster_login`/`broadcaster_name` for the
    // campaign events, unlike the `broadcaster_user_*` keys every other event uses.
    // Accept either so the event decodes whichever spelling arrives.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let campaign = try decoder.container(keyedBy: CampaignBroadcasterKeys.self)
        id = try container.decode(String.self, forKey: .id)
        broadcasterUserId = try container.decodeIfPresent(String.self, forKey: .broadcasterUserId)
            ?? campaign.decode(String.self, forKey: .broadcasterId)
        broadcasterUserLogin = try container.decodeIfPresent(String.self, forKey: .broadcasterUserLogin)
            ?? campaign.decode(String.self, forKey: .broadcasterLogin)
        broadcasterUserName = try container.decodeIfPresent(String.self, forKey: .broadcasterUserName)
            ?? campaign.decode(String.self, forKey: .broadcasterName)
        charityName = try container.decode(String.self, forKey: .charityName)
        charityDescription = try container.decode(String.self, forKey: .charityDescription)
        charityLogo = try container.decodeIfPresent(URL.self, forKey: .charityLogo)
        charityWebsite = try container.decodeIfPresent(URL.self, forKey: .charityWebsite)
        currentAmount = try container.decode(CharityAmount.self, forKey: .currentAmount)
        targetAmount = try container.decode(CharityAmount.self, forKey: .targetAmount)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        stoppedAt = try container.decodeIfPresent(Date.self, forKey: .stoppedAt)
    }

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        charityName: String,
        charityDescription: String,
        charityLogo: URL? = nil,
        charityWebsite: URL? = nil,
        currentAmount: CharityAmount,
        targetAmount: CharityAmount,
        startedAt: Date? = nil,
        stoppedAt: Date? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.charityName = charityName
        self.charityDescription = charityDescription
        self.charityLogo = charityLogo
        self.charityWebsite = charityWebsite
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        campaignId: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        charityName: String,
        charityDescription: String,
        charityLogo: URL? = nil,
        charityWebsite: URL? = nil,
        amount: CharityAmount
    ) {
        self.id = id
        self.campaignId = campaignId
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.charityName = charityName
        self.charityDescription = charityDescription
        self.charityLogo = charityLogo
        self.charityWebsite = charityWebsite
        self.amount = amount
    }
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

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            id: String,
            title: String,
            bits: Int,
            prompt: String
        ) {
            self.id = id
            self.title = title
            self.bits = bits
            self.prompt = prompt
        }
    }

    @available(*, deprecated, message: "Use customPowerUp.bits")
    public var cost: Int? { customPowerUp.bits }

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        id: String,
        userInput: String,
        status: ChannelPointsRedemptionStatus,
        customPowerUp: PowerUp,
        redeemedAt: Date
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.id = id
        self.userInput = userInput
        self.status = status
        self.customPowerUp = customPowerUp
        self.redeemedAt = redeemedAt
    }
}

public struct EventSubSuspiciousUserMessage: Decodable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let lowTrustStatus: SuspiciousUserStatus?
    public let sharedBanChannelIds: [String]?
    public let types: [String]?
    public let banEvasionEvaluation: String?
    public let message: ChatMessage.ChatMessageBody

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        lowTrustStatus: SuspiciousUserStatus? = nil,
        sharedBanChannelIds: [String]? = nil,
        types: [String]? = nil,
        banEvasionEvaluation: String? = nil,
        message: ChatMessage.ChatMessageBody
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.lowTrustStatus = lowTrustStatus
        self.sharedBanChannelIds = sharedBanChannelIds
        self.types = types
        self.banEvasionEvaluation = banEvasionEvaluation
        self.message = message
    }
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
    public let lowTrustStatus: SuspiciousUserStatus

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String,
        moderatorUserLogin: String,
        moderatorUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        lowTrustStatus: SuspiciousUserStatus
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.lowTrustStatus = lowTrustStatus
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        text: String? = nil
    ) {
        self.id = id
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.text = text
    }
}

public struct EventSubVIPChange: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String,
        moderatorUserLogin: String,
        moderatorUserName: String,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String? = nil,
        moderatorUserLogin: String? = nil,
        moderatorUserName: String? = nil,
        toBroadcasterUserId: String? = nil,
        toBroadcasterUserLogin: String? = nil,
        toBroadcasterUserName: String? = nil,
        fromBroadcasterUserId: String? = nil,
        fromBroadcasterUserLogin: String? = nil,
        fromBroadcasterUserName: String? = nil,
        viewerCount: Int? = nil,
        startedAt: Date? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.toBroadcasterUserId = toBroadcasterUserId
        self.toBroadcasterUserLogin = toBroadcasterUserLogin
        self.toBroadcasterUserName = toBroadcasterUserName
        self.fromBroadcasterUserId = fromBroadcasterUserId
        self.fromBroadcasterUserLogin = fromBroadcasterUserLogin
        self.fromBroadcasterUserName = fromBroadcasterUserName
        self.viewerCount = viewerCount
        self.startedAt = startedAt
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        moderatorUserId: String? = nil,
        moderatorUserLogin: String? = nil,
        moderatorUserName: String? = nil,
        userId: String,
        userLogin: String,
        userName: String,
        reason: String? = nil
    ) {
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.moderatorUserId = moderatorUserId
        self.moderatorUserLogin = moderatorUserLogin
        self.moderatorUserName = moderatorUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.reason = reason
    }
}

public struct EventSubConduitShardDisabled: Codable, Sendable, Equatable {
    public let conduitId: String
    public let shardId: String
    public let status: ConduitShardStatus
    public let transport: Transport?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        conduitId: String,
        shardId: String,
        status: ConduitShardStatus,
        transport: Transport? = nil
    ) {
        self.conduitId = conduitId
        self.shardId = shardId
        self.status = status
        self.transport = transport
    }

    public struct Transport: Codable, Sendable, Equatable {
        public let method: String
        public let callback: URL?
        public let sessionId: String?
        public let conduitId: String?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            method: String,
            callback: URL? = nil,
            sessionId: String? = nil,
            conduitId: String? = nil
        ) {
            self.method = method
            self.callback = callback
            self.sessionId = sessionId
            self.conduitId = conduitId
        }
    }
}

public struct EventSubDropEntitlementGrant: Codable, Sendable, Equatable {
    public let id: String?
    public let data: [Entitlement]?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String? = nil,
        data: [Entitlement]? = nil
    ) {
        self.id = id
        self.data = data
    }

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

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            organizationId: String? = nil,
            categoryId: String? = nil,
            categoryName: String? = nil,
            campaignId: String? = nil,
            userId: String? = nil,
            userLogin: String? = nil,
            userName: String? = nil,
            entitlementId: String? = nil,
            benefitId: String? = nil,
            createdAt: Date? = nil
        ) {
            self.organizationId = organizationId
            self.categoryId = categoryId
            self.categoryName = categoryName
            self.campaignId = campaignId
            self.userId = userId
            self.userLogin = userLogin
            self.userName = userName
            self.entitlementId = entitlementId
            self.benefitId = benefitId
            self.createdAt = createdAt
        }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        id: String,
        extensionClientId: String,
        broadcasterUserId: String,
        broadcasterUserLogin: String,
        broadcasterUserName: String,
        userId: String,
        userLogin: String,
        userName: String,
        product: Product
    ) {
        self.id = id
        self.extensionClientId = extensionClientId
        self.broadcasterUserId = broadcasterUserId
        self.broadcasterUserLogin = broadcasterUserLogin
        self.broadcasterUserName = broadcasterUserName
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.product = product
    }

    public struct Product: Codable, Sendable, Equatable {
        public let name: String
        public let bits: Int
        public let sku: String?
        public let inDevelopment: Bool?

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            name: String,
            bits: Int,
            sku: String? = nil,
            inDevelopment: Bool? = nil
        ) {
            self.name = name
            self.bits = bits
            self.sku = sku
            self.inDevelopment = inDevelopment
        }
    }
}

public struct EventSubUserAuthorization: Codable, Sendable, Equatable {
    public let clientId: String
    public let userId: String
    /// The user's login. `nil` in `user.authorization.revoke` when the user no longer exists.
    public let userLogin: String?
    /// The user's display name. `nil` in `user.authorization.revoke` when the user no longer exists.
    public let userName: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        clientId: String,
        userId: String,
        userLogin: String? = nil,
        userName: String? = nil
    ) {
        self.clientId = clientId
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
    }
}

public struct EventSubUserUpdate: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let email: String?
    public let emailVerified: Bool?
    public let description: String?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        userId: String,
        userLogin: String,
        userName: String,
        email: String? = nil,
        emailVerified: Bool? = nil,
        description: String? = nil
    ) {
        self.userId = userId
        self.userLogin = userLogin
        self.userName = userName
        self.email = email
        self.emailVerified = emailVerified
        self.description = description
    }
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

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        fromUserId: String,
        fromUserLogin: String,
        fromUserName: String,
        toUserId: String,
        toUserLogin: String,
        toUserName: String,
        whisperId: String,
        whisper: Whisper
    ) {
        self.fromUserId = fromUserId
        self.fromUserLogin = fromUserLogin
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserLogin = toUserLogin
        self.toUserName = toUserName
        self.whisperId = whisperId
        self.whisper = whisper
    }

    public struct Whisper: Codable, Sendable, Equatable {
        public let text: String

        /// Creates a value directly, for example in tests or SwiftUI previews.
        public init(
            text: String
        ) {
            self.text = text
        }
    }
}
