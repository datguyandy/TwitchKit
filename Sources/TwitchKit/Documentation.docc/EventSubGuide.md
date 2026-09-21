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

Keep the returned subscription ID when your app needs to remove the subscription later:

```swift
try await eventSub.unsubscribe(id: record.id)
```

TwitchKit reconnects automatically after disconnects and re-creates the subscriptions you requested through ``TwitchKit/EventSubClient/subscribe(_:)``. Duplicate EventSub messages are ignored by message ID. Duplicate tracking is bounded, and EventSub notifications use `.bufferingNewest(1_000)` by default so a slow consumer cannot grow memory without limit.

Configure the buffering policy on ``TwitchKit/TwitchClient`` when your app needs a different tradeoff:

```swift
let client = TwitchClient(
    clientId: "<#Client ID#>",
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
    case .known(let event):
        print("Known EventSub payload:", event.type.rawValue)
    case .unknown(let type, _):
        print("Unhandled future EventSub payload:", type)
    default:
        break
    }
}
```

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

For webhook transports, verify Twitch's request signature before decoding or acting on a notification. Use the raw HTTP request body bytes exactly as received.

```swift
let verifier = EventSubWebhookVerifier(secret: eventSubSecret)
let isValid = verifier.isValid(
    messageID: request.headers["Twitch-Eventsub-Message-Id"],
    timestamp: request.headers["Twitch-Eventsub-Message-Timestamp"],
    body: requestBody,
    signature: request.headers["Twitch-Eventsub-Message-Signature"],
    maxAge: .seconds(600)
)
```

When Twitch sends a webhook callback verification request, respond with the challenge string:

```swift
let challenge = try EventSubWebhookVerifier.challenge(from: requestBody)
```

Only process the request when `isValid` is true. Before applying side effects, atomically check and record `Twitch-Eventsub-Message-Id` in your handler’s deduplication store. Ignore an ID already processed, and retain IDs for the full accepted timestamp window (the 600-second maximum age plus the verifier’s 300-second future-clock tolerance). Signature and timestamp checks alone do not prevent duplicate delivery within that window.

## Known And Unknown Events

TwitchKit exposes dedicated Swift models for high-value EventSub payloads such as chat messages, chat notifications, stream state, subscriptions, moderation, channel points, polls, predictions, goals, Hype Train, charity campaigns, warnings, shield mode, and shoutouts.

When TwitchKit recognizes the EventSub subscription type but does not yet expose a dedicated field-level model, it returns ``TwitchKit/EventSubEvent/known(_:)`` with an ``TwitchKit/EventSubKnownEventType`` and the original JSON payload. ``TwitchKit/EventSubEvent/unknown(type:payload:)`` is reserved for future Twitch subscription types that the SDK does not recognize yet.
