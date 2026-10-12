import Foundation

/// A joined channel chat: the EventSub subscriptions a chat view needs, and a
/// stream of that channel's events.
///
/// Create one with ``EventSubClient/joinChat(broadcasterID:userID:additionalSubscriptions:)``
/// and call ``leave()`` when the chat view goes away. Rooms on the same channel
/// share subscriptions, so leaving one room doesn't affect another.
public actor ChatRoom {
    /// The subscriptions every chat room uses: messages, notifications (subs,
    /// raids, announcements), whole-chat clears, per-user clears (timeouts and
    /// bans), single-message deletions, and chat-settings changes.
    public static func chatSubscriptions(broadcasterID: String, userID: String) -> [EventSubSubscription] {
        [
            EventSubSubscription.Chat.message(broadcasterID: broadcasterID, userID: userID),
            EventSubSubscription.Chat.notification(broadcasterID: broadcasterID, userID: userID),
            EventSubSubscription.Chat.clear(broadcasterID: broadcasterID, userID: userID),
            EventSubSubscription.Chat.clearUserMessages(broadcasterID: broadcasterID, userID: userID),
            EventSubSubscription.Chat.messageDelete(broadcasterID: broadcasterID, userID: userID),
            EventSubSubscription.Chat.settingsUpdate(broadcasterID: broadcasterID, userID: userID),
        ]
    }

    /// The channel's broadcaster user ID.
    public nonisolated let broadcasterID: String

    /// The user reading chat (the token's user).
    public nonisolated let userID: String

    /// The subscriptions this room holds.
    public nonisolated let subscriptions: [EventSubSubscription]

    private let client: EventSubClient
    private let broadcaster: AsyncBroadcaster<EventSubNotification>
    private let pump: Task<Void, Never>
    private var hasLeft = false

    init(
        client: EventSubClient,
        broadcasterID: String,
        userID: String,
        subscriptions: [EventSubSubscription],
        source: AsyncStream<EventSubNotification>
    ) {
        self.client = client
        self.broadcasterID = broadcasterID
        self.userID = userID
        self.subscriptions = subscriptions
        let broadcaster = AsyncBroadcaster<EventSubNotification>(
            bufferingPolicy: .bufferingNewest(1_000),
            backlogPolicy: .bufferingNewest(1_000),
            replaysLatest: false
        )
        self.broadcaster = broadcaster
        // `source` was registered before the subscriptions were created, so
        // nothing is missed; events wait in the room until a view iterates.
        pump = Task {
            for await notification in source {
                broadcaster.yield(notification)
            }
            broadcaster.finish()
        }
    }

    deinit {
        pump.cancel()
        broadcaster.finish()
    }

    /// A new stream of this channel's events: chat messages, notifications,
    /// clears, deletions, settings changes, and the channel's revocations and
    /// ``EventSubEvent/subscriptionFailed(_:_:)`` events.
    ///
    /// Each access returns an independent stream, and events that arrive
    /// before anything iterates are kept for the first one. Streams finish
    /// when the room leaves.
    public nonisolated var events: AsyncStream<EventSubEvent> {
        broadcaster.makeStream { $0.event }
    }

    /// A new stream of this channel's events with Twitch's metadata (message
    /// ID and timestamp, and the delivering subscription). Behaves like
    /// ``events``.
    public nonisolated var notifications: AsyncStream<EventSubNotification> {
        broadcaster.makeStream()
    }

    /// Whether ``leave()`` has been called.
    public var hasLeftRoom: Bool {
        hasLeft
    }

    /// Leaves the chat: finishes this room's event streams and removes the
    /// room's subscriptions that no other joined room still uses.
    ///
    /// Calling it again does nothing. If a delete fails, the first error is
    /// rethrown and that subscription stays live; the next room joined on the
    /// channel takes it over and removes it when that room leaves.
    public func leave() async throws {
        guard !hasLeft else { return }
        hasLeft = true
        pump.cancel()
        broadcaster.finish()
        try await client.releaseChatSubscriptions(subscriptions)
    }
}

/// `joinChat` failed because Twitch rejected some of the room's subscriptions.
/// The ones that succeeded were removed again, so nothing is left joined.
public struct JoinChatError: Error, LocalizedError {
    public struct Failure: Sendable {
        public let subscription: EventSubSubscription
        public let error: any Error
    }

    /// The channel that couldn't be joined.
    public let broadcasterID: String

    /// Each subscription that failed, with its error.
    public let failures: [Failure]

    public var errorDescription: String? {
        let types = failures.map(\.subscription.type).joined(separator: ", ")
        return "Couldn't join chat for broadcaster \(broadcasterID): \(types) failed"
    }
}

extension EventSubClient {
    /// Joins a channel's chat: connects if needed, creates the room's
    /// subscriptions in parallel, and returns a ``ChatRoom`` with the
    /// channel's events.
    ///
    /// The room uses ``ChatRoom/chatSubscriptions(broadcasterID:userID:)``
    /// plus `additionalSubscriptions`. Joining is all-or-nothing: if any
    /// subscription fails, the ones created for this join are removed again
    /// and ``JoinChatError`` lists the failures. Rooms on the same channel
    /// share subscriptions instead of creating duplicates, and a subscription
    /// you created with `subscribe` before joining is never removed by a room.
    ///
    /// - Parameters:
    ///   - broadcasterID: The channel's broadcaster user ID.
    ///   - userID: The user reading chat; must match the access token's user.
    ///   - additionalSubscriptions: More subscriptions for the room, for
    ///     example `EventSubSubscription.Chat.userMessageHold`.
    public func joinChat(
        broadcasterID: String,
        userID: String,
        additionalSubscriptions: [EventSubSubscription] = []
    ) async throws -> ChatRoom {
        try await connect()

        var subscriptions: [EventSubSubscription] = []
        for subscription in ChatRoom.chatSubscriptions(broadcasterID: broadcasterID, userID: userID) + additionalSubscriptions
        where !subscriptions.contains(subscription) {
            subscriptions.append(subscription)
        }

        // Register the room's stream before any subscription exists, so the
        // first events can't arrive ahead of it.
        let source = notifications(for: broadcasterID)

        // Claim every subscription before the first await, so a concurrent
        // join of the same channel shares this join's creates instead of
        // racing them into 409 conflicts.
        var pending: [(EventSubSubscription, Task<Void, Error>)] = []
        for subscription in subscriptions {
            let claims = chatRoomClaims[subscription, default: 0]
            chatRoomClaims[subscription] = claims + 1
            if let inFlight = chatRoomInFlightCreates[subscription] {
                pending.append((subscription, inFlight))
            } else if claims == 0, !isDesired(subscription) {
                // Inherits this actor's isolation; the creates run in
                // parallel because each suspends on its network request.
                let create = Task {
                    defer { chatRoomInFlightCreates[subscription] = nil }
                    // A room that just left may still be deleting it.
                    _ = await chatRoomInFlightDeletes[subscription]?.result
                    // That delete failed: the subscription is still live and
                    // still room-owned, so this room takes it over.
                    guard !isDesired(subscription) else { return }
                    _ = try await subscribe(subscription)
                    chatRoomCreatedSubscriptions.insert(subscription)
                }
                chatRoomInFlightCreates[subscription] = create
                pending.append((subscription, create))
            }
        }

        var failures: [JoinChatError.Failure] = []
        for (subscription, create) in pending {
            do {
                try await create.value
            } catch {
                failures.append(JoinChatError.Failure(subscription: subscription, error: error))
            }
        }

        guard failures.isEmpty else {
            // Roll back: release this join's claims, which removes whatever
            // it created that no other room uses. The join error is the one
            // worth reporting, so a failed rollback delete isn't rethrown.
            try? await releaseChatSubscriptions(subscriptions)
            throw JoinChatError(broadcasterID: broadcasterID, failures: failures)
        }

        return ChatRoom(
            client: self,
            broadcasterID: broadcasterID,
            userID: userID,
            subscriptions: subscriptions,
            source: source
        )
    }

    /// Releases one room's claim on each subscription, deleting (in parallel)
    /// the ones a room created that no other room still uses.
    func releaseChatSubscriptions(_ subscriptions: [EventSubSubscription]) async throws {
        var toRemove: [EventSubSubscription] = []
        for subscription in subscriptions {
            let remaining = chatRoomClaims[subscription, default: 1] - 1
            if remaining > 0 {
                chatRoomClaims[subscription] = remaining
                continue
            }
            chatRoomClaims[subscription] = nil
            if chatRoomCreatedSubscriptions.remove(subscription) != nil {
                toRemove.append(subscription)
            }
        }

        let deletes = toRemove.map { subscription in
            let delete = Task {
                defer { chatRoomInFlightDeletes[subscription] = nil }
                do {
                    try await unsubscribe(subscription)
                } catch {
                    // Still live (the client restored it): keep it room-owned
                    // so the next room on the channel removes it.
                    chatRoomCreatedSubscriptions.insert(subscription)
                    throw error
                }
            }
            chatRoomInFlightDeletes[subscription] = delete
            return delete
        }
        var firstError: (any Error)?
        for delete in deletes {
            do {
                try await delete.value
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError {
            throw firstError
        }
    }
}
