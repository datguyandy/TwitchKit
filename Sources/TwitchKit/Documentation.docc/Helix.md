# Helix

Use ``TwitchKit/HelixClient`` for Twitch REST API calls. The client handles authorization headers, Client-ID headers, Twitch error payloads, retries for supported transient errors, and JSON decoding.

## User And Channel APIs

```swift
let user = try await client.api.fetchUser()

let channel = try await client.api.fetchChannelInfo(
    broadcasterID: user.id
)
```

## Updating Channel Info

Use ``TwitchKit/ChannelInfoUpdate`` to keep update call sites readable as Twitch adds more optional fields:

```swift
let update = ChannelInfoUpdate(
    gameID: "509658",
    title: "Building a Swift Twitch SDK"
)

try await client.api.updateChannelInfo(
    broadcasterID: user.id,
    with: update
)
```

## Chat

```swift
let response = try await client.api.sendChatMessage(
    broadcasterID: "<#Broadcaster ID#>",
    senderID: "<#Sender ID#>",
    message: "Hello from TwitchKit"
)

if response.isSent {
    print("Sent:", response.messageId)
}
```

Read chat metadata and current chatters:

```swift
let badges = try await client.api.fetchGlobalBadges()
let emotes = try await client.api.fetchChannelEmotes(broadcasterID: "<#Broadcaster ID#>")
let chatters = try await client.api.fetchChattersPage(
    broadcasterID: "<#Broadcaster ID#>",
    moderatorID: "<#Moderator ID#>"
)
```

## Moderation

```swift
try await client.api.banUser(
    broadcasterID: "<#Broadcaster ID#>",
    moderatorID: "<#Moderator ID#>",
    userID: "<#User ID#>",
    reason: "<#Reason#>"
)

try await client.api.deleteChatMessages(
    broadcasterID: "<#Broadcaster ID#>",
    moderatorID: "<#Moderator ID#>",
    messageID: "<#Message ID#>"
)
```

## Channel Points

```swift
let rewards = try await client.api.fetchCustomRewards(
    broadcasterID: "<#Broadcaster ID#>"
)

let redemptions = try await client.api.fetchCustomRewardRedemptionsPage(
    broadcasterID: "<#Broadcaster ID#>",
    rewardID: "<#Reward ID#>",
    status: .unfulfilled
)
```

## Clips And Videos

```swift
let clip = try await client.api.createClip(
    broadcasterID: "<#Broadcaster ID#>"
)

let videos = try await client.api.fetchVideosPage(
    userID: "<#User ID#>",
    first: 20
)
```

## Polls And Predictions

```swift
let poll = try await client.api.createPoll(
    PollCreateRequest(
        broadcasterID: "<#Broadcaster ID#>",
        title: "Which feature next?",
        choices: [
            PollChoice(title: "OAuth"),
            PollChoice(title: "EventSub"),
            PollChoice(title: "Helix")
        ],
        duration: 120
    )
)

let prediction = try await client.api.createPrediction(
    PredictionCreateRequest(
        broadcasterID: "<#Broadcaster ID#>",
        title: "Will the build pass?",
        outcomes: [
            PredictionOutcome(title: "Yes"),
            PredictionOutcome(title: "No")
        ],
        predictionWindow: 60
    )
)
```

## EventSub Management

```swift
let page = try await client.api.fetchEventSubSubscriptionsPage()

let record = try await client.api.createEventSubSubscription(
    type: "channel.chat.message",
    version: "1",
    condition: [
        "broadcaster_user_id": "<#Broadcaster ID#>",
        "user_id": "<#User ID#>"
    ],
    sessionID: "<#WebSocket Session ID#>"
)

try await client.api.deleteEventSubSubscription(id: record.id)
```

For development cleanup, delete all subscriptions matching a filter:

```swift
try await client.api.deleteAllEventSubSubscriptions(
    filter: .status(.webhookCallbackVerificationPending)
)
```

## Pagination

Many Twitch APIs return paginated ``TwitchKit/HelixResponse`` values. Page methods return one response at a time:

```swift
let page = try await client.api.fetchStreamsPage(
    userIDs: ["<#User ID#>"],
    first: 20
)

let nextCursor = page.nextCursor
```

Sequence helpers request additional pages lazily as you iterate:

```swift
for try await follower in client.api.channelFollowers(
    broadcasterID: "<#Broadcaster ID#>"
) {
    print(follower.userName)
}
```

## Retries And Rate Limits

``TwitchKit/HelixRetryPolicy`` controls automatic retries. By default:

- A rate-limited request (HTTP 429) is retried once, after waiting for `Retry-After` or Twitch's `Ratelimit-Reset`, up to 60 seconds. Twitch doesn't process a rate-limited request, so this applies to every method. A longer wait, or a 429 that leaves points in the bucket (such as EventSub's subscription limits), throws ``TwitchKit/HelixError/rateLimited(_:)`` immediately.
- A 503 is retried once for GET, HEAD, PUT, and DELETE. POST and PATCH aren't retried, because a 503 doesn't prove Twitch didn't act on the request.

```swift
let client = TwitchClient(
    clientID: "<#Client ID#>",
    retryPolicy: HelixRetryPolicy(rateLimitRetries: 3, maxRateLimitDelay: .seconds(30))
)
```

Pass `.never` to handle every 429 and 503 yourself.

## Coverage

TwitchKit includes typed helpers for the public Helix families in Twitch's API reference, including chat, moderation, EventSub management, conduits, channel points, clips/videos, schedules, subscriptions, ads, analytics, Bits, Drops entitlements, extensions, Guest Star, tags, teams, users, and whispers.
