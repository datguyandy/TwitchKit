# ``TwitchKit``

Build Swift apps and tools that talk to Twitch Helix APIs and EventSub WebSocket notifications.

## Overview

TwitchKit is a Swift Package Manager library for authenticated Twitch API clients. It provides typed models and async APIs for common Helix workflows, OAuth helpers for Twitch authorization flows, and EventSub WebSocket support for real-time channel, chat, moderation, and creator events.

Use ``TwitchKit/TwitchClient`` as the main entry point:

```swift
let client = TwitchClient(
    clientID: "<#Client ID#>",
    tokenStore: InMemoryTokenStore(
        token: OAuthToken(accessToken: "<#Access Token#>")
    )
)

let user = try await client.api.fetchUser()
// `nil` when no broadcaster has this ID.
let channel = try await client.api.fetchChannelInfo(
    broadcasterID: user.id
)
```

For EventSub WebSockets, connect ``TwitchKit/TwitchClient/eventSub`` and subscribe to the events you need:

```swift
let eventSub = client.eventSub
try await eventSub.connect()

for await event in eventSub.events {
    switch event {
    case .chatMessage(let message):
        print(message.message.text)
    case .known(let event):
        print("Known EventSub type:", event.type.rawValue)
    case .unknown(let type, _):
        print("Future EventSub type:", type)
    default:
        break
    }
}
```

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:AuthenticationGuide>

### Twitch APIs

- <doc:Helix>
- <doc:EventSubGuide>

### Client Types

- ``TwitchKit/TwitchClient``
- ``TwitchKit/HelixClient``
- ``TwitchKit/EventSubClient``
- ``TwitchKit/ChatRoom``

### Authentication

- ``TwitchKit/TwitchAuth``
- ``TwitchKit/TwitchAppTokenProvider``
- ``TwitchKit/TwitchTokenInfo``
- ``TwitchKit/TokenValidationResult``
- ``TwitchKit/TwitchScope``
- ``TwitchKit/TwitchTokenStore``

### EventSub

- ``TwitchKit/EventSubSubscription``
- ``TwitchKit/EventSubEvent``
- ``TwitchKit/EventSubNotification``
- ``TwitchKit/EventSubMetadata``
- ``TwitchKit/EventSubWebhookMessage``
- ``TwitchKit/EventSubKnownEvent``
- ``TwitchKit/EventSubKnownEventType``
