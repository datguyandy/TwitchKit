# EventSub

Use ``TwitchKit/EventSubClient`` to receive Twitch EventSub notifications over WebSockets, or use ``TwitchKit/HelixClient`` to create and manage webhook/conduit subscriptions directly.

## WebSocket Flow

Connect first, then create subscriptions after Twitch sends the `session_welcome` message. ``TwitchKit/EventSubClient/connect(timeout:)`` waits for that welcome before returning.

```swift
let eventSub = client.eventSub
try await eventSub.connect()

let record = try await eventSub.subscribe(
    .makeChannelChatMessage(
        broadcasterID: "<#Broadcaster ID#>",
        userID: "<#User ID#>"
    )
)

print("Created subscription:", record.id)
```

Keep the returned subscription ID when your app needs to remove the subscription later. The ID keeps working after reconnects, even though Twitch assigns the re-created subscription a new ID:

```swift
try await eventSub.unsubscribe(id: record.id)
```

TwitchKit reconnects automatically after disconnects and re-creates the subscriptions you requested through ``TwitchKit/EventSubClient/subscribe(_:)``. A subscription Twitch revokes (`.revocation`) is no longer re-created. If Twitch rejects re-creating a subscription for a reason retrying can't fix, such as a missing scope, the client drops it, reports `.subscriptionFailed`, and continues with the rest. Duplicate EventSub messages are ignored by message ID. Duplicate tracking is bounded, and EventSub notifications use `.bufferingNewest(1_000)` by default so a slow consumer cannot grow memory without limit.

The `shouldKeepReconnecting` closure passed to ``TwitchKit/EventSubClient/init(api:shouldKeepReconnecting:pathMonitor:socketFactory:eventBufferingPolicy:)`` (or `TwitchClient`) decides how hard reconnects try. It's called before each attempt. While it returns `true` (the default), the client retries forever with a backoff capped at 5 seconds. While it returns `false`, the client gives up after 5 attempts, about 31 seconds, reports `.disconnected`, and waits for the network path to change or for `connect()`. Return `false` once the app no longer needs live events, for example when no chat view is open or the app is in the background.

Configure the buffering policy on ``TwitchKit/TwitchClient`` when your app needs a different tradeoff:

```swift
let client = TwitchClient(
    clientID: "<#Client ID#>",
    eventBufferingPolicy: .bufferingNewest(5_000)
)
```

## Consume Events

```swift
for await event in eventSub.events {
    switch event {
    case .chatMessage(let message):
        print(message.chatterUserName, message.message.text)
    case .ban(let ban):
        print("Banned:", ban.userName)
    case .revocation(let revocation):
        print("Subscription revoked:", revocation.status.rawValue)
    case .subscriptionFailed(let subscription, let error):
        print("Could not re-create \(subscription.type):", error.localizedDescription)
    case .known(let event):
        print("Known EventSub payload:", event.type.rawValue)
    case .unknown(let type, _):
        print("Unhandled future EventSub payload:", type)
    default:
        break
    }
}
```

For Twitch's metadata with each event (message ID and timestamp, and the delivering subscription's ID, type, version and condition), iterate ``TwitchKit/EventSubClient/notifications`` or ``TwitchKit/EventSubClient/notifications(for:)``.

To follow a single channel, iterate ``TwitchKit/EventSubClient/events(for:)`` instead. It yields only events delivered by subscriptions that name that broadcaster, so a chat screen per channel doesn't need its own routing:

```swift
for await event in eventSub.events(for: "<#Broadcaster ID#>") {
    // this channel's chat messages, deletions, notifications, …
}
```

### Join a chat room

Showing a channel's chat takes six subscriptions. ``TwitchKit/EventSubClient/joinChat(broadcasterID:userID:additionalSubscriptions:)`` creates them in parallel and returns a ``TwitchKit/ChatRoom`` whose ``TwitchKit/ChatRoom/events`` carries that channel's events:

```swift
let room = try await eventSub.joinChat(
    broadcasterID: "<#Broadcaster ID#>",
    userID: "<#Your User ID#>"
)

for await event in room.events {
    // messages, notifications, clears, deletions, settings changes
}

try await room.leave()
```

Joining is all-or-nothing: if Twitch rejects any subscription, the ones just created are removed and ``TwitchKit/JoinChatError`` lists each failure. Rooms on the same channel share subscriptions, so a chat view and a mini-player can each hold a room and leave independently. A subscription you created with `subscribe` before joining is never removed by a room. Pass `additionalSubscriptions` for anything else the room needs, such as `EventSubSubscription.Chat.userMessageHold`.

## Manage Subscriptions

Use Helix when you need to inspect or clean up subscriptions created by your app:

```swift
let page = try await client.api.fetchEventSubSubscriptionsPage(
    filter: .status(.enabled)
)

for subscription in page.data {
    print(subscription.id, subscription.type, subscription.status.rawValue)
}
```

Delete one subscription by ID:

```swift
try await client.api.deleteEventSubSubscription(id: "<#Subscription ID#>")
```

For development tools and cleanup jobs, delete every subscription matching a filter:

```swift
let deletedCount = try await client.api.deleteAllEventSubSubscriptions(
    filter: .status(.webhookCallbackVerificationPending)
)

print("Deleted", deletedCount, "stale subscriptions")
```

Pass `nil` only when you intentionally want to delete all EventSub subscriptions visible to the authenticated app/token.

## Webhook And Conduit Transports

``TwitchKit/EventSubClient`` is for WebSocket delivery. For webhook and conduit delivery, call Helix directly with an explicit transport:

```swift
let record = try await client.api.createEventSubSubscription(
    type: "channel.update",
    version: "2",
    condition: ["broadcaster_user_id": "<#Broadcaster ID#>"],
    transport: .webhook(
        callback: URL(string: "https://example.com/twitch/eventsub")!,
        secret: "<#Shared Secret#>"
    )
)

print(record.id)
```

Conduit subscriptions use the conduit ID returned by Twitch's conduit APIs:

```swift
try await client.api.createEventSubSubscription(
    type: "channel.update",
    version: "2",
    condition: ["broadcaster_user_id": "<#Broadcaster ID#>"],
    transport: .conduit(conduitID: "<#Conduit ID#>")
)
```

## Webhook Verification

For webhook transports, ``TwitchKit/EventSubWebhookVerifier/message(headers:body:maxAge:now:)`` checks Twitch's request signature and timestamp, then decodes the request into an ``TwitchKit/EventSubWebhookMessage``. Use the raw HTTP request body bytes exactly as received.

```swift
let verifier = EventSubWebhookVerifier(secret: eventSubSecret)

switch try verifier.message(headers: request.headers, body: requestBody) {
case .verification(let challenge, _):
    return .ok(text: challenge)     // 200, Content-Type: text/plain
case .notification(let notification):
    await handle(notification)      // a typed event (or `.revocation`) with Twitch's metadata
    return .noContent               // respond 2xx quickly
}
```

A request whose signature doesn't match, or whose timestamp is older than `maxAge`, throws ``TwitchKit/EventSubWebhookError/invalidSignature``; respond 403 and don't process it.

Notifications are ``TwitchKit/EventSubNotification`` values, the same type ``TwitchKit/EventSubClient/notifications`` yields for the WebSocket transport, so one handler can serve both.

Twitch can deliver a message more than once. Before applying side effects, atomically check and record the notification's ``TwitchKit/EventSubMetadata/messageID`` in your handler’s deduplication store. Ignore an ID already processed, and retain IDs for the full accepted timestamp window (the 600-second maximum age plus the verifier’s 300-second future-clock tolerance). Signature and timestamp checks alone do not prevent duplicate delivery within that window.

To decode an event you received some other way, call ``TwitchKit/EventSubEvent/decode(type:event:)`` with its subscription type and the JSON of its `event` object.

## Known And Unknown Events

TwitchKit exposes dedicated Swift models for high-value EventSub payloads such as chat messages, chat notifications, stream state, subscriptions, moderation, channel points, polls, predictions, goals, Hype Train, charity campaigns, warnings, shield mode, and shoutouts.

When TwitchKit recognizes the EventSub subscription type but does not yet expose a dedicated field-level model, it returns ``TwitchKit/EventSubEvent/known(_:)`` with an ``TwitchKit/EventSubKnownEventType`` and the original JSON payload. ``TwitchKit/EventSubEvent/unknown(type:payload:)`` is reserved for future Twitch subscription types that the SDK does not recognize yet.
