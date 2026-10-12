# TwitchKit

[![CI](https://github.com/AndrewBeshay/TwitchKit/actions/workflows/ci.yml/badge.svg)](https://github.com/AndrewBeshay/TwitchKit/actions/workflows/ci.yml)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FAndrewBeshay%2FTwitchKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/AndrewBeshay/TwitchKit)
[![SPI Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FAndrewBeshay%2FTwitchKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/AndrewBeshay/TwitchKit)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/tag/AndrewBeshay/TwitchKit?include_prereleases&label=release)](https://github.com/AndrewBeshay/TwitchKit/releases)

TwitchKit is a Swift Package for working with the Twitch Helix API, Twitch OAuth, and EventSub WebSocket transport from modern Swift apps.

The package is currently pre-1.0. It provides typed authentication, token storage, Helix request helpers, EventSub subscription builders, and EventSub WebSocket delivery while the public API continues to settle.

## Requirements

- Swift 6.0 or newer
- iOS 16 or newer
- macOS 13 or newer

## Installation

Add TwitchKit as a Swift Package dependency:

```swift
.package(url: "https://github.com/AndrewBeshay/TwitchKit.git", from: "0.4.0")
```

Then add the product to your target:

```swift
.product(name: "TwitchKit", package: "TwitchKit")
```

## Quick Start

```swift
import TwitchKit

let twitch = TwitchClient(
    clientID: "<your client id>",
    tokenNamespace: "primary-account"
)

let authURL = twitch.auth.implicitGrantURL(
    scopes: [
        .userReadEmail,
        .userReadChat,
        .userWriteChat,
    ],
    state: "<csrf token>"
)
```

For server-backed apps that can protect a client secret:

```swift
let twitch = TwitchClient(
    clientID: "<your client id>",
    clientSecret: "<your client secret>",
    tokenNamespace: "primary-account"
)

let authURL = twitch.auth.authorizationCodeURL(
    scopes: [
        .userReadEmail,
        .channelManageBroadcast,
    ],
    state: "<csrf token>"
)
```

After your app receives an authorization code:

```swift
try await twitch.auth.authenticate(withAuthorizationCode: code)
```

If your host app or backend owns OAuth, inject an existing token:

```swift
try await twitch.auth.setToken(
    OAuthToken(
        accessToken: "<access token>",
        refreshToken: nil,
        expiresIn: nil,
        scope: nil,
        tokenType: "bearer"
    )
)
```

## Helix API

```swift
let user = try await twitch.api.fetchUser()
let channel = try await twitch.api.fetchChannelInfo(broadcasterID: user.id)
let emotes = try await twitch.api.fetchGlobalEmotes()
```

Lookups that can legitimately find nothing return an optional: `fetchUser(id:)`, `fetchUser(login:)`, `fetchGame(id:)`, `fetchChannelInfo(broadcasterID:)`, `fetchStream(userID:)` (`nil` while offline), and similar. Reads that always have a result, such as `fetchUser()` for the token's user or `fetchChatSettings`, and every write return their result directly. `HelixError.notFound` always means Twitch answered HTTP 404.

Current Helix coverage includes users, channels, streams, games, chat, moderation, EventSub management, ads, analytics, Bits, conduits, entitlements, extensions, Guest Star, followed channels/streams, channel editors, search, schedules, charity, Hype Train, polls, predictions, raids, stream markers, goals, channel points rewards/redemptions, subscriptions, clips, tags, teams, videos, and whispers.

Paginated endpoints are available as either single pages or lazy async sequences:

```swift
let firstPage = try await twitch.api.fetchChannelFollowersPage(
    broadcasterID: user.id,
    first: 100
)

for try await follower in twitch.api.channelFollowers(broadcasterID: user.id) {
    print("Follower:", follower.userName)
}
```

Sending a chat message:

```swift
let result = try await twitch.api.sendChatMessage(
    broadcasterID: "<broadcaster id>",
    senderID: "<sender id>",
    message: "Hello from TwitchKit"
)

if result.isSent {
    print("Sent message:", result.messageId)
}
```

## EventSub WebSocket

Connect to EventSub and subscribe to typed subscription requests:

```swift
try await twitch.eventSub.connect()

try await twitch.eventSub.subscribe(
    .makeChannelChatMessage(
        broadcasterID: "<broadcaster id>",
        userID: "<user id>"
    )
)

for await event in twitch.eventSub.events {
    switch event {
    case .chatMessage(let message):
        print("\(message.chatterUserName): \(message.message.text)")

    case .follow(let follow):
        print("New follower:", follow.userName)

    case .subscription(let subscription):
        print("New subscription:", subscription.userName)

    case .revocation(let revocation):
        print("Subscription revoked:", revocation.status)

    case .unknown(let type, _):
        print("Unhandled EventSub event:", type)

    default:
        break // dozens of other typed events — see EventSubEvent
    }
}
```

EventSub reconnects automatically and re-creates desired subscriptions after a full disconnect. Reconnect is network-path aware: while the OS reports no usable network path the retry loop parks instead of burning attempts into a dead connection, and it reconnects immediately — resetting backoff — the moment the path is restored. Duplicate EventSub messages are ignored by message ID. TwitchKit bounds duplicate-message tracking and buffers the newest 1,000 EventSub notifications by default so a slow consumer cannot grow memory without limit.

Each access to `eventSub.events` returns its own stream, so several parts of an app (for example a chat view and a moderation panel) can iterate at the same time and each receives every event. Cancelling one loop, such as a SwiftUI `.task` whose view disappears, ends only that stream; iterate `events` again to resume. Events that arrive while nothing is iterating are buffered for the next consumer.

### Observing connection state

`eventSub.connectionState` is an `AsyncStream<ConnectionState>` you can observe to drive UI such as a "Reconnecting…" indicator. Like `events`, each access returns an independent stream; it starts with the current state, so an observer that starts late still learns where the client is. `eventSub.currentConnectionState` reads the latest state synchronously.

```swift
Task {
    for await state in twitch.eventSub.connectionState {
        switch state {
        case .connecting:        print("Connecting…")
        case .connected:         print("Live")
        case .reconnecting:      print("Reconnecting…")
        case .waitingForNetwork: print("Waiting for network…")
        case .disconnected:      print("Disconnected")
        }
    }
}

try await twitch.eventSub.connect()
```

The network monitor is injectable for testing via the defaulted `pathMonitor:` parameter on `TwitchClient`/`EventSubClient` (any `NetworkPathMonitoring`); it defaults to an `NWPathMonitor`-backed implementation.

If your app needs a different EventSub buffering tradeoff, configure the client at initialization:

```swift
let twitch = TwitchClient(
    clientID: "<#Client ID#>",
    eventBufferingPolicy: .bufferingNewest(5_000)
)
```

`subscribe(_:)` returns the `EventSubSubscriptionRecord` created by Twitch, including the subscription ID. Keep that ID if you want to remove the subscription later; it keeps working after reconnects re-create the subscription:

```swift
let record = try await twitch.eventSub.subscribe(
    .makeChannelChatMessage(
        broadcasterID: "<#Broadcaster ID#>",
        userID: "<#User ID#>"
    )
)

try await twitch.eventSub.unsubscribe(id: record.id)
```

You can also manage EventSub subscriptions directly through Helix:

```swift
let page = try await twitch.api.fetchEventSubSubscriptionsPage(
    filter: .status(.enabled)
)

try await twitch.api.deleteEventSubSubscription(id: page.data[0].id)

let deletedCount = try await twitch.api.deleteAllEventSubSubscriptions(
    filter: .status(.webhookCallbackVerificationPending)
)
```

### EventSub Webhooks

For webhook transports, verify Twitch's signature before decoding or acting on a notification. Pass the exact raw request body bytes you received from your HTTP server:

```swift
let verifier = EventSubWebhookVerifier(secret: eventSubSecret)
let isValid = verifier.isValid(
    messageID: request.headers["Twitch-Eventsub-Message-Id"],
    timestamp: request.headers["Twitch-Eventsub-Message-Timestamp"],
    body: requestBody,
    signature: request.headers["Twitch-Eventsub-Message-Signature"],
    maxAge: .seconds(600)
)

let challenge = try EventSubWebhookVerifier.challenge(from: requestBody)
```

Only process the request when `isValid` is true. Before applying side effects, atomically check and record `Twitch-Eventsub-Message-Id` in your handler’s deduplication store. Ignore an ID already processed, and retain IDs for the full accepted timestamp window (the 600-second maximum age plus the verifier’s 300-second future-clock tolerance). Signature and timestamp checks alone do not prevent duplicate delivery within that window.

## Supported APIs

### Helix

| Area | Coverage |
| --- | --- |
| Users | Authenticated user, users by ID/login |
| Channels | Channel info, channel updates, followers, followed channels, editors, content classification labels |
| Streams and games | Streams, stream lookup, stream key, top games, games by ID/name/IGDB ID |
| Chat | Global/channel badges, global/channel emotes, emote sets, user emotes, chatters, chat settings, shared chat sessions, pinned messages, announcements, shoutouts, user chat colors, Send Chat Message |
| Moderation | AutoMod status/settings, bans/timeouts, unban requests, blocked terms, delete chat message, moderated channels, moderators, VIPs, Shield Mode, warnings, suspicious users |
| EventSub management | Create/list/delete subscriptions, bulk cleanup helper, WebSocket/webhook/conduit transports, batching flag |
| Creator tools | Schedules, charity campaigns/donations, Hype Train status, polls, predictions, raids, stream markers, goals |
| Channel points | Custom rewards and custom reward redemptions |
| Media | Clips, clip downloads, videos, video deletion |
| Subscriptions | Broadcaster subscriptions and user subscription checks |

### EventSub

| Area | Subscription builders | Typed notification payloads |
| --- | --- | --- |
| Chat | Chat messages, notifications, clear events, message deletion, chat settings, user message hold/update, shared chat sessions | Chat messages, notifications, clear events, message deletion, chat settings, user message hold/update |
| Subscriptions | Subscribe, end, gift, message | Subscribe, end, gift, message |
| Moderation | Ban, unban, moderator add/remove, moderate, unban requests, VIP add/remove, warnings, Shield Mode, suspicious users | Ban, unban, moderator add/remove, moderate, unban requests, VIP add/remove, warnings, Shield Mode |
| Channel points | Automatic redemptions, custom rewards, custom reward redemptions, power-up redemptions | Automatic redemptions, custom rewards, custom reward redemptions |
| Creator engagement | Polls, predictions, goals, Hype Train, charity campaigns/donations, raids, shoutouts, follows, cheers | Polls, predictions, goals, Hype Train, charity campaigns/donations, raids, shoutouts, follows, cheers |
| Streams and users | Stream online/offline, user authorization grant/revoke, user update, whispers | Stream online/offline |
| Platform/specialized | AutoMod, conduits, drops, extension bits, Guest Star, user authorization/update, whispers | AutoMod, conduits, drops, extension bits, Guest Star, user authorization/update, whispers |

Known EventSub subscription types that do not yet have dedicated field-level models decode as `.known(EventSubKnownEvent)` with the original JSON payload preserved. Future Twitch types decode as `.unknown(type:payload:)`.

## OAuth Support

TwitchKit exposes helpers for Twitch-supported OAuth flows:

- OAuth implicit grant
- OAuth authorization code grant
- OIDC implicit grant
- OIDC authorization code grant
- OAuth client credentials grant
- OAuth device code grant
- Token injection for apps that manage OAuth outside the package

For iOS apps, avoid shipping a client secret in the app bundle. Prefer implicit grant, device code flow, or a backend-owned authorization code exchange depending on your app model.

OAuth is split into composable pieces:

- `TwitchOAuthClient` builds OAuth URLs and exchanges grants for tokens.
- `TwitchTokenStore` abstracts token persistence.
- `KeychainTokenStore` is the default Apple-platform token store.
- `InMemoryTokenStore` is useful for tests, previews, and backend-owned OAuth.
- `TwitchTokenProvider` loads, validates, refreshes, and supplies access tokens.
- `TwitchAuth` is a convenience facade that composes the pieces above.

Apps that already receive tokens from a backend can bypass Keychain storage entirely:

```swift
let twitch = TwitchClient(
    clientID: "<your client id>",
    tokenStore: InMemoryTokenStore(
        token: OAuthToken(accessToken: "<backend issued access token>")
    )
)
```

## Scope Catalog

`TwitchScope` includes the current Twitch API, EventSub, IRC chat, and PubSub-specific scope strings documented by Twitch.

Use `TwitchAuth.defaultScopes` for the small starter set used by TwitchKit convenience APIs, or `TwitchAuth.allScopes` when you need the complete catalog. OAuth helper methods prefer typed `[TwitchScope]` values and also provide raw-scope overloads for newly added Twitch scopes.

Request only the scopes your app needs. Twitch warns that requesting unnecessary scopes can put API access at risk.

### Common Scopes

| Use case | Typical scopes |
| --- | --- |
| Read authenticated user email | `.userReadEmail` |
| Read chat through Helix/EventSub | `.userReadChat` |
| Send chat messages | `.userWriteChat` |
| Subscribe to `channel.chat.message` over EventSub | `.userReadChat`, `.userBot` or broadcaster/moderator chat permissions depending on your app model |
| Read chatters | `.moderatorReadChatters` |
| Update channel title/category | `.channelManageBroadcast` |
| Read or manage channel points rewards | `.channelReadRedemptions`, `.channelManageRedemptions` |
| Moderate chat | `.moderatorManageBannedUsers`, `.moderatorManageChatMessages`, `.moderatorReadChatters` |
| Create polls or predictions | `.channelManagePolls`, `.channelManagePredictions` |
| Read subscriptions/followers | `.channelReadSubscriptions`, `.moderatorReadFollowers` |

Exact requirements vary by endpoint and whether the authenticated user is the broadcaster, moderator, or bot account, so check Twitch's endpoint docs before requesting production app review.

## Smoke Test Example

The package includes `TwitchKitSmokeTest`, a small command-line target for trying real Twitch API calls locally. It reads credentials from environment variables:

```bash
export TWITCH_CLIENT_ID="<#Client ID#>"
export TWITCH_ACCESS_TOKEN="<#Access Token#>"
export TWITCH_BROADCASTER_ID="<#Broadcaster/User ID#>"

swift run TwitchKitSmokeTest all
swift run TwitchKitSmokeTest eventsub-list
swift run TwitchKitSmokeTest eventsub-connect
```

Side-effecting checks require explicit opt-in:

```bash
TWITCH_SMOKE_SEND_CHAT=1 swift run TwitchKitSmokeTest send-chat
TWITCH_SMOKE_CLEANUP=1 swift run TwitchKitSmokeTest eventsub-cleanup
```

Use a development Twitch application and avoid checking tokens into source control.

## Status

TwitchKit is pre-1.0 and the public API may change. Current coverage includes:

- OAuth helper flows and Keychain-backed token storage
- Broad Helix creator, chat, channel-management, moderation, media, and EventSub-management APIs
- EventSub WebSocket connection management, network-path-aware reconnect, an observable `connectionState` stream, and subscription re-creation
- EventSub subscription factories for the current Twitch subscription type catalog
- Typed models for Twitch's current EventSub subscription type catalog, with raw fallbacks for future Twitch types and decode-resilience
- Swift 6 `Sendable` annotations and actor-isolated auth/EventSub clients

Planned areas for expansion:

- iOS OAuth example app
- More focused examples for common broadcaster, moderator, and chat-bot workflows
- Continued DocC expansion as new Twitch API surfaces are added

## License

TwitchKit is available under the MIT License. See [LICENSE](LICENSE).
