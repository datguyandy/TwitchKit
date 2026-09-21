import Darwin
import Foundation
import TwitchKit

@main
private enum SmokeTestMain {
    static func main() async {
        await TwitchKitSmokeTestCLI.main()
    }
}

struct TwitchKitSmokeTestCLI {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "help"

        if command == "help" || command == "--help" || command == "-h" {
            printHelp()
            return
        }

        let context = try SmokeContext()

        switch command {
        case "all":
            try await fetchAuthenticatedUser(context)
            try await fetchChannelIfConfigured(context)
            try await listEventSubSubscriptions(context)

        case "user":
            try await fetchAuthenticatedUser(context)

        case "channel":
            try await fetchChannel(context)

        case "eventsub-list":
            try await listEventSubSubscriptions(context)

        case "eventsub-connect":
            try await connectEventSub(context)

        case "eventsub-cleanup":
            try await cleanupEventSubSubscriptions(context)

        case "send-chat":
            try await sendChatMessage(context)

        default:
            throw SmokeTestError.invalidCommand(command)
        }
    }

    private static func fetchAuthenticatedUser(_ context: SmokeContext) async throws {
        let user = try await context.client.api.fetchUser()
        print("Authenticated user: \(user.displayName) (@\(user.login), id: \(user.id))")
    }

    private static func fetchChannelIfConfigured(_ context: SmokeContext) async throws {
        guard context.broadcasterID != nil else {
            print("Channel: skipped (set TWITCH_BROADCASTER_ID)")
            return
        }
        try await fetchChannel(context)
    }

    private static func fetchChannel(_ context: SmokeContext) async throws {
        let broadcasterID = try context.required("TWITCH_BROADCASTER_ID")
        let channel = try await context.client.api.fetchChannelInfo(forBroadcasterID: broadcasterID)
        print("Channel: \(channel.broadcasterName) playing \(channel.gameName) - \(channel.title)")
    }

    private static func listEventSubSubscriptions(_ context: SmokeContext) async throws {
        let page = try await context.client.api.fetchEventSubSubscriptionsPage()
        print("EventSub subscriptions: \(page.data.count) returned, total: \(page.total ?? page.data.count)")
        print("EventSub cost: \(page.totalCost ?? 0)/\(page.maxTotalCost ?? 0)")
        for subscription in page.data.prefix(10) {
            print("- \(subscription.id) \(subscription.type) v\(subscription.version) [\(subscription.status.rawValue)]")
        }
        if page.data.count > 10 {
            print("- ... \(page.data.count - 10) more on this page")
        }
    }

    private static func connectEventSub(_ context: SmokeContext) async throws {
        let broadcasterID = try context.required("TWITCH_BROADCASTER_ID")
        let userID: String
        if let eventSubUserID = context.eventSubUserID {
            userID = eventSubUserID
        } else {
            userID = try await context.client.api.fetchUser().id
        }
        let waitSeconds = context.eventSubWaitSeconds

        let eventTask = Task {
            for await event in context.client.eventSub.events {
                print("EventSub event: \(describe(event))")
            }
        }

        print("Connecting EventSub WebSocket...")
        try await context.client.eventSub.connect()
        print("Connected. Creating smoke-test subscriptions...")

        try await context.client.eventSub.subscribe(EventSubSubscription.Stream.online(broadcasterID: broadcasterID))
        print("Subscribed: stream.online for broadcaster \(broadcasterID)")

        try await context.client.eventSub.subscribe(EventSubSubscription.Stream.offline(broadcasterID: broadcasterID))
        print("Subscribed: stream.offline for broadcaster \(broadcasterID)")

        try await context.client.eventSub.subscribe(EventSubSubscription.Chat.message(
            broadcasterID: broadcasterID,
            userID: userID
        ))
        print("Subscribed: channel.chat.message for broadcaster \(broadcasterID) as user \(userID)")

        print("Waiting for EventSub events for \(waitSeconds)s...")
        print("Tip: send a chat message in the channel or run send-chat from another terminal.")
        try await Task.sleep(for: .seconds(waitSeconds))

        print("Disconnecting EventSub WebSocket...")
        await context.client.eventSub.disconnect()
        eventTask.cancel()
        print("EventSub smoke test complete.")
    }

    private static func cleanupEventSubSubscriptions(_ context: SmokeContext) async throws {
        guard context.allowCleanup else {
            throw SmokeTestError.cleanupNotEnabled
        }

        var subscriptions: [EventSubSubscriptionRecord] = []
        for try await subscription in context.client.api.eventSubSubscriptions() {
            subscriptions.append(subscription)
        }

        guard !subscriptions.isEmpty else {
            print("No EventSub subscriptions to delete.")
            return
        }

        print("Deleting \(subscriptions.count) EventSub subscription(s)...")
        for subscription in subscriptions {
            try await context.client.api.deleteEventSubSubscription(id: subscription.id)
            print("Deleted: \(subscription.id) \(subscription.type) [\(subscription.status.rawValue)]")
        }
        print("EventSub cleanup complete. Deleted \(subscriptions.count) subscription(s).")
    }

    private static func sendChatMessage(_ context: SmokeContext) async throws {
        guard context.allowChatSend else {
            throw SmokeTestError.chatSendNotEnabled
        }

        let broadcasterID = try context.required("TWITCH_BROADCASTER_ID")
        let senderID: String
        if let configuredSenderID = context.senderID {
            senderID = configuredSenderID
        } else {
            senderID = try await context.client.api.fetchUser().id
        }
        let message = context.chatMessage ?? "TwitchKit smoke test"

        let response = try await context.client.api.sendChatMessage(
            broadcasterId: broadcasterID,
            senderId: senderID,
            message: message
        )
        print("Chat message sent: \(response.isSent), id: \(response.messageId)")
        if let dropReason = response.dropReason {
            print("Drop reason: \(dropReason.code) - \(dropReason.message)")
        }
    }

    private static func describe(_ event: EventSubEvent) -> String {
        switch event {
        case .chatMessage(let message):
            "chat message from \(message.chatterUserName): \(message.message.text)"
        case .channelUpdate(let update):
            "channel update: \(update.title)"
        case .follow(let follow):
            "follow from \(follow.userName)"
        case .subscription(let subscription):
            "subscription from \(subscription.userName)"
        case .streamOnline(let stream):
            "stream online: \(stream.broadcasterUserName) (\(stream.type.rawValue))"
        case .streamOffline(let stream):
            "stream offline: \(stream.broadcasterUserName)"
        case .automodMessageHold(let message):
            "automod message held: \(message.messageId)"
        case .automodMessageUpdate(let message):
            "automod message updated: \(message.messageId)"
        case .automodSettingsUpdate:
            "automod settings updated"
        case .automodTermsUpdate(let event):
            "automod terms \(event.action): \(event.terms.count) term(s)"
        case .bitsUse(let event):
            "bits used: \(event.bits)"
        case .adBreakBegin(let event):
            "ad break began: \(event.durationSeconds)s"
        case .raid(let raid):
            "raid from \(raid.fromBroadcasterUserName) to \(raid.toBroadcasterUserName), viewers: \(raid.viewers)"
        case .cheer(let cheer):
            "cheer: \(cheer.bits) bits"
        case .ban(let ban):
            "ban: \(ban.userName), permanent: \(ban.isPermanent)"
        case .unban(let unban):
            "unban: \(unban.userName)"
        case .moderatorAdd(let moderator):
            "moderator added: \(moderator.userName)"
        case .moderatorRemove(let moderator):
            "moderator removed: \(moderator.userName)"
        case .channelPointsCustomRewardRedemptionAdd(let redemption):
            "reward redemption add: \(redemption.reward.title) by \(redemption.userName)"
        case .channelPointsCustomRewardRedemptionUpdate(let redemption):
            "reward redemption update: \(redemption.reward.title) is \(redemption.status.rawValue)"
        case .channelPointsCustomRewardAdd(let reward):
            "channel points reward added: \(reward.title)"
        case .channelPointsCustomRewardUpdate(let reward):
            "channel points reward updated: \(reward.title)"
        case .channelPointsCustomRewardRemove(let reward):
            "channel points reward removed: \(reward.title)"
        case .channelPointsAutomaticRewardRedemptionAdd(let redemption):
            "automatic reward redemption by \(redemption.userName)"
        case .chatClear:
            "chat cleared"
        case .chatClearUserMessages(let event):
            "chat messages cleared for \(event.targetUserName)"
        case .chatMessageDelete(let event):
            "chat message deleted: \(event.messageId)"
        case .chatNotification(let notification):
            "chat notification: \(notification.noticeType)"
        case .chatUserMessageHold(let event):
            "chat message held: \(event.messageId)"
        case .chatUserMessageUpdate(let event):
            "chat message moderation update: \(event.messageId)"
        case .chatSettingsUpdate:
            "chat settings updated"
        case .sharedChatBegin(let session):
            "shared chat began: \(session.sessionId)"
        case .sharedChatUpdate(let session):
            "shared chat updated: \(session.sessionId)"
        case .sharedChatEnd(let session):
            "shared chat ended: \(session.sessionId)"
        case .moderate(let event):
            "moderation action: \(event.action)"
        case .guestStarSessionBegin(let session):
            "Guest Star session began: \(session.sessionId ?? "unknown")"
        case .guestStarSessionEnd(let session):
            "Guest Star session ended: \(session.sessionId ?? "unknown")"
        case .guestStarGuestUpdate(let guest):
            "Guest Star guest updated: \(guest.guestUserName)"
        case .guestStarSettingsUpdate:
            "Guest Star settings updated"
        case .subscriptionEnd(let subscription):
            "subscription ended: \(subscription.userName)"
        case .subscriptionGift(let gift):
            "subscription gift: \(gift.total) gift(s)"
        case .subscriptionMessage(let subscription):
            "subscription message from \(subscription.userName)"
        case .pollBegin(let poll):
            "poll began: \(poll.title)"
        case .pollProgress(let poll):
            "poll progress: \(poll.title)"
        case .pollEnd(let poll):
            "poll ended: \(poll.title)"
        case .predictionBegin(let prediction):
            "prediction began: \(prediction.title)"
        case .predictionProgress(let prediction):
            "prediction progress: \(prediction.title)"
        case .predictionLock(let prediction):
            "prediction locked: \(prediction.title)"
        case .predictionEnd(let prediction):
            "prediction ended: \(prediction.title)"
        case .goalBegin(let goal):
            "goal began: \(goal.description)"
        case .goalProgress(let goal):
            "goal progress: \(goal.description)"
        case .goalEnd(let goal):
            "goal ended: \(goal.description)"
        case .hypeTrainBegin(let hypeTrain):
            "hype train began: level \(hypeTrain.level)"
        case .hypeTrainProgress(let hypeTrain):
            "hype train progress: level \(hypeTrain.level)"
        case .hypeTrainEnd(let hypeTrain):
            "hype train ended: level \(hypeTrain.level)"
        case .charityCampaignDonate(let donation):
            "charity donation: \(donation.userName)"
        case .charityCampaignStart(let campaign):
            "charity campaign started: \(campaign.charityName)"
        case .charityCampaignProgress(let campaign):
            "charity campaign progress: \(campaign.charityName)"
        case .charityCampaignStop(let campaign):
            "charity campaign stopped: \(campaign.charityName)"
        case .customPowerUpRedemptionAdd(let redemption):
            "custom power-up redemption: \(redemption.customPowerUp.title)"
        case .suspiciousUserMessage(let event):
            "suspicious user message from \(event.userName)"
        case .suspiciousUserUpdate(let event):
            "suspicious user updated: \(event.userName)"
        case .unbanRequestCreate(let request):
            "unban request created by \(request.userName)"
        case .unbanRequestResolve(let request):
            "unban request resolved for \(request.userName)"
        case .vipAdd(let vip):
            "VIP added: \(vip.userName)"
        case .vipRemove(let vip):
            "VIP removed: \(vip.userName)"
        case .shieldModeBegin:
            "shield mode began"
        case .shieldModeEnd:
            "shield mode ended"
        case .shoutoutCreate(let shoutout):
            "shoutout created to \(shoutout.toBroadcasterUserName ?? "unknown")"
        case .shoutoutReceive(let shoutout):
            "shoutout received from \(shoutout.fromBroadcasterUserName ?? "unknown")"
        case .warningAcknowledge(let warning):
            "warning acknowledged by \(warning.userName)"
        case .warningSend(let warning):
            "warning sent to \(warning.userName)"
        case .conduitShardDisabled(let shard):
            "conduit shard disabled: \(shard.shardId)"
        case .dropEntitlementGrant(let grant):
            "drop entitlement grant: \(grant.data?.count ?? 0) entitlement(s)"
        case .extensionBitsTransactionCreate(let transaction):
            "extension bits transaction: \(transaction.product.bits) bits"
        case .userAuthorizationGrant(let authorization):
            "user authorization granted: \(authorization.userName)"
        case .userAuthorizationRevoke(let authorization):
            "user authorization revoked: \(authorization.userName)"
        case .userUpdate(let user):
            "user updated: \(user.userName)"
        case .userWhisperMessage(let whisper):
            "whisper from \(whisper.fromUserName)"
        case .revocation(let revocation):
            "revocation: \(revocation.type) [\(revocation.status.rawValue)]"
        case .known(let event):
            "known EventSub event: \(event.type.rawValue)"
        case .unknown(let type, _):
            "unknown: \(type)"
        }
    }

    private static func printHelp() {
        print("""
        TwitchKitSmokeTest

        Required environment:
          TWITCH_CLIENT_ID       Twitch application client ID.
          TWITCH_ACCESS_TOKEN    User or app access token for the checks you run.

        Optional environment:
          TWITCH_CLIENT_SECRET              Enables token refresh if your token includes a refresh token.
          TWITCH_REFRESH_TOKEN              Optional refresh token.
          TWITCH_BROADCASTER_ID             Broadcaster/channel user ID for channel, chat, and EventSub checks.
          TWITCH_SENDER_ID                  Chat sender user ID. Defaults to authenticated user.
          TWITCH_CHAT_MESSAGE               Message for send-chat.
          TWITCH_SMOKE_SEND_CHAT=1          Required to allow send-chat.
          TWITCH_SMOKE_CLEANUP=1            Required to allow eventsub-cleanup.
          TWITCH_EVENTSUB_USER_ID           EventSub chat listener user ID. Defaults to authenticated user.
          TWITCH_EVENTSUB_WAIT_SECONDS      EventSub listen duration. Defaults to 30.

        Commands:
          all                Fetch authenticated user, optional channel, and EventSub subscription page.
          user               Fetch authenticated user.
          channel            Fetch TWITCH_BROADCASTER_ID channel info.
          eventsub-list      List first page of EventSub subscriptions.
          eventsub-connect   Connect WebSocket, subscribe to stream/chat events, and wait.
          eventsub-cleanup   Delete all EventSub subscriptions visible to the current token.
          send-chat          Send TWITCH_CHAT_MESSAGE. Requires TWITCH_SMOKE_SEND_CHAT=1.

        Example:
          TWITCH_CLIENT_ID=... TWITCH_ACCESS_TOKEN=... swift run TwitchKitSmokeTest all
        """)
    }
}

private struct SmokeContext {
    let client: TwitchClient
    let broadcasterID: String?
    let senderID: String?
    let chatMessage: String?
    let allowChatSend: Bool
    let allowCleanup: Bool
    let eventSubUserID: String?
    let eventSubWaitSeconds: Int64

    init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        let clientID = try Self.required("TWITCH_CLIENT_ID", in: environment)
        let accessToken = try Self.required("TWITCH_ACCESS_TOKEN", in: environment)
        let refreshToken = Self.value("TWITCH_REFRESH_TOKEN", in: environment)
        let clientSecret = Self.value("TWITCH_CLIENT_SECRET", in: environment)

        let token = OAuthToken(accessToken: accessToken, refreshToken: refreshToken)
        let tokenStore = InMemoryTokenStore(token: token)
        client = TwitchClient(clientId: clientID, clientSecret: clientSecret, tokenStore: tokenStore)

        broadcasterID = Self.value("TWITCH_BROADCASTER_ID", in: environment)
        senderID = Self.value("TWITCH_SENDER_ID", in: environment)
        chatMessage = Self.value("TWITCH_CHAT_MESSAGE", in: environment)
        allowChatSend = Self.value("TWITCH_SMOKE_SEND_CHAT", in: environment) == "1"
        allowCleanup = Self.value("TWITCH_SMOKE_CLEANUP", in: environment) == "1"
        eventSubUserID = Self.value("TWITCH_EVENTSUB_USER_ID", in: environment)
        eventSubWaitSeconds = Int64(Self.value("TWITCH_EVENTSUB_WAIT_SECONDS", in: environment) ?? "") ?? 30
    }

    func required(_ key: String) throws -> String {
        guard let value = Self.value(key, in: ProcessInfo.processInfo.environment) else {
            throw SmokeTestError.missingEnvironment(key)
        }
        return value
    }

    private static func required(_ key: String, in environment: [String: String]) throws -> String {
        guard let value = value(key, in: environment) else {
            throw SmokeTestError.missingEnvironment(key)
        }
        return value
    }

    private static func value(_ key: String, in environment: [String: String]) -> String? {
        guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private enum SmokeTestError: LocalizedError {
    case missingEnvironment(String)
    case invalidCommand(String)
    case chatSendNotEnabled
    case cleanupNotEnabled

    var errorDescription: String? {
        switch self {
        case .missingEnvironment(let key):
            "Missing required environment variable: \(key)"
        case .invalidCommand(let command):
            "Unknown command: \(command). Run `swift run TwitchKitSmokeTest help`."
        case .chatSendNotEnabled:
            "Refusing to send chat. Set TWITCH_SMOKE_SEND_CHAT=1 to confirm this side effect."
        case .cleanupNotEnabled:
            "Refusing to delete EventSub subscriptions. Set TWITCH_SMOKE_CLEANUP=1 to confirm this side effect."
        }
    }
}
