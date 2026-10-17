# Changelog

All notable changes to TwitchKit will be documented in this file.

TwitchKit follows semantic versioning while it is pre-1.0. During the 0.x series, minor versions may include source-breaking API changes as the package matures.

## [Unreleased]

### Added

- EventSub: `lastDisconnectReason` says why the connection last ended, as an `EventSubDisconnectReason`: `.closedByServer(EventSubCloseCode, reason:)` with Twitch's close code (4000 internal server error through 4007 invalid reconnect, for example `.connectionUnused` when no subscription was created within 10 seconds, or `.other(Int)`), `.connectionLost`, `.keepaliveTimeout`, `.reconnectFailed`, `.untrustedReconnectURL` or `.requested`. It's set before `connectionState` moves to `.reconnecting`, `.waitingForNetwork` or `.disconnected`, and is logged. `EventSubWebSocket` gains `serverCloseCode` and `serverCloseReason`, with defaults returning `nil` so custom sockets keep compiling; `URLSessionWebSocketTask` reports Twitch's codes through them.

### Fixed

- Cancelling a task that's waiting on shared work now returns `CancellationError` at once: a `connect()` (directly, or through `subscribe()` or `joinChat`), a token refresh (including the one a Helix request starts after a 401), and an app-token request. Previously the caller stayed suspended until the shared work finished, which could take up to the 15-second connect timeout. The shared work isn't cancelled: other callers still get its result, and a caller arriving after a cancellation joins it rather than starting a second `connect()` or refresh, which would race it (two refreshes would spend the same single-use refresh token).

## [0.5.0] - 2026-10-18

### Added

- Auth: `TwitchAppTokenProvider` supplies app access tokens from the client credentials flow, for Helix calls that need one (EventSub webhook and conduit subscriptions, conduits) and for server-side apps. It requests a token on first use, keeps it in memory, requests a new one shortly before expiry (`renewalMargin`, 5 minutes by default) or when Twitch rejects it, shares one request between concurrent callers, and can `revoke()` its token. `TwitchClient.appAPI` is a `HelixClient` built on it, available when the client is created with a `clientSecret`; `api` keeps using the user's token.
- Auth: hourly token validation, which Twitch requires. `validations(every:)` on `TwitchAuth` and `TwitchTokenProvider` validates now and then every interval (an hour by default) for as long as the stream is iterated, yielding `.valid(TwitchTokenInfo)`, `.invalid(error)` (Twitch rejected the token and it couldn't be refreshed), `.signedOut`, or `.failed(error)` (offline or an outage; the token is left alone and retried next interval). A rejected token is refreshed when possible.
- Auth: `TwitchTokenInfo` carries what Twitch reports about a token: client ID, user ID and login (`nil` for app tokens), granted scopes (`hasScope(_:)`), `expiresIn` and `expiresAt`. `TwitchOAuthClient.validate(_:)` returns it, or `nil` for a token Twitch rejects.
- EventSub webhooks: `EventSubWebhookVerifier.message(headers:body:)` checks a request's signature and timestamp, then decodes it into an `EventSubWebhookMessage`: `.verification(challenge:metadata:)`, or `.notification(EventSubNotification)` with the same typed events the WebSocket client yields (revocations arrive as `.revocation` events). A failed check throws `EventSubWebhookError.invalidSignature`. Header names match case-insensitively, and a `header:` closure variant works with any server framework's header type. `EventSubWebhookMessage(headers:body:)` decodes without verifying, and `EventSubEvent.decode(type:event:)` decodes a single event's JSON. Previously webhook users could verify requests but had no way to get typed events.
- EventSub: `notifications`, `notifications(for:)` and `ChatRoom.notifications` yield `EventSubNotification` values, pairing each event with Twitch's `EventSubMetadata`: message ID and timestamp, and the delivering subscription's ID, type, version and condition. `metadata` is `nil` only for events the client creates itself (`.subscriptionFailed`). `events` is unchanged.
- EventSub: an event that doesn't decode into a model keeps its raw JSON for batched notifications too, which carry an `events` array instead of `event`.
- Helix: `deleteChatMessage(broadcasterID:moderatorID:messageID:)` deletes one message and `clearChat(broadcasterID:moderatorID:)` clears the chat. They replace `deleteChatMessages(broadcasterID:moderatorID:messageID:)`, which cleared the whole chat when the optional `messageID` was left out. An empty message ID is rejected without calling Twitch.
- OAuth: `TwitchOAuthClient.revokeToken(_:)` revokes an access token. A token Twitch already considers invalid counts as revoked.
- `HelixError.unexpectedStatus(status:_:)` for HTTP statuses without a dedicated case outside 5xx (for example 410 for a retired endpoint), carrying Twitch's error body when one was sent.
- EventSub: `joinChat(broadcasterID:userID:additionalSubscriptions:)` joins a channel's chat in one call. It connects if needed, creates the six chat subscriptions (`channel.chat.message`, `.notification`, `.clear`, `.clear_user_messages`, `.message_delete` and `channel.chat_settings.update`) in parallel, and returns a `ChatRoom` whose `events` stream carries only that channel's events. Joining is all-or-nothing: if Twitch rejects any subscription, the ones just created are removed and `JoinChatError` lists each failure. `room.leave()` removes the room's subscriptions. Rooms on the same channel share subscriptions, so leaving one doesn't affect the others, and subscriptions the app created with `subscribe` are never removed by a room.
- EventSub: `events(for: broadcasterID)` returns a stream of one channel's events. Events are routed by the condition of the subscription that delivered them (`broadcaster_user_id`, or either side of a raid or shoutout), so every subscription type works, including ones TwitchKit doesn't model yet; the channel's revocations and `.subscriptionFailed` events are included. A filtered stream receives only events sent after it's created, so create it before subscribing.
- Public memberwise initializers for the 215 response and EventSub event models that lacked one (for example `TwitchUser(id:login:displayName:…)`), so apps can build fixtures for tests and SwiftUI previews without decoding JSON. Parameters follow each model's property order; optional properties default to `nil`.

- Typed status enums for 17 fields that were plain `String`s: `TwitchPoll`/`EventSubPoll.status` (`TwitchPollStatus`), `TwitchPrediction`/`EventSubPrediction.status` (`TwitchPredictionStatus`), `UnbanRequest.status` (`UnbanRequestStatus`), `DropsEntitlement.fulfillmentStatus`, `DropsEntitlementUpdateResult.status` (`DropsEntitlementUpdateStatus`), `SuspiciousUserAction.status` and the EventSub `lowTrustStatus` fields (`SuspiciousUserStatus`), `GuestStarInvite.status`/`EventSubGuestStarGuestUpdate.state` (`GuestStarGuestState`), `EventSubConduitShard`/`EventSubConduitShardDisabled.status` (`ConduitShardStatus`), `TwitchExtension.state` (`ExtensionState`), `EventSubAutoModMessage.status` (`AutoModMessageStatus`) and `EventSubChatUserMessageModeration.status` (`ChatUserMessageStatus`). Each keeps an `.unknown(String)` case so new Twitch values still decode, and matches case-insensitively, since Helix sends `ACTIVE` where EventSub sends `active`.

- Requirements: iOS 18 / macOS 15 and Swift 6.2 tools (Xcode 26). Every target builds in Swift 6 mode with `ExistentialAny`, `MemberImportVisibility`, `InferIsolatedConformances` and `NonisolatedNonsendingByDefault`; the HTTP transport, Helix request and OAuth request paths are `@concurrent`, so JSON decoding never runs on the caller's actor (for example the main actor in a SwiftUI app).
- EventSub `channel.chat.notification`: `gifted_drops_summary` and `shared_chat_gifted_drops_summary` (Twitch changelog 2026-10-01) as `GiftedDropsSummary`; the `source_broadcaster_user_*`, `source_message_id` and `source_badges` fields; and the nine `shared_chat_*` payloads (`sharedChatSub`, `sharedChatRaid`, …) that previously decoded as empty. `noticeType` is a forward-compatible `EventSubChatNoticeType`.
- EventSub `channel.bits.use`: `customPowerUp` (`title`, `rewardID`) and `PowerUp.messageEffectID`; `type` is a forward-compatible `EventSubBitsUseType` (`cheer`, `power_up`, `custom_power_up`).
- `TwitchFollow` carries the v2 `broadcasterUserID/Login/Name`; `TwitchUser.type` (`TwitchUserType`: admin, global mod, staff, normal).
- `TwitchAPIError.id`: Create EventSub Subscription returns the existing subscription's ID with a 409, and `EventSubClient` records it so `unsubscribe` can delete a subscription that already existed.
- OAuth: `TwitchOAuthClient.makeState()` and `parseCallback(_:expectedState:)` (constant-time `state` check, `error` handling, fragment or query) returning `TwitchOAuthCallback`; `TwitchAuth.authenticate(withCallbackURL:expectedState:)` validates the token and its client ID before storing it. The authorization URL builders add a random `state` when none is passed.
- OAuth: `HelixError.deviceCodeRejected` for a device code the user denied or that expired, `.oauthStateMismatch`, and `.tokenClientMismatch(expected:actual:)`; `TwitchOAuthClient.clientID`, `verifyClientID(of:)`, `validateOwnToken(_:)`; `TwitchTokenInfo.isIssued(toClientID:)`.
- Webhooks: `EventSubWebhookVerifier.isSignatureValid(...)` for signature-only checks; `EventSubWebhookSecretError` for secrets outside Twitch's 10–100 ASCII-character rule.
- Keychain: `KeychainError` is public (`status`, `isInteractionNotAllowed` for `errSecInteractionNotAllowed`, which is worth retrying after unlock), and `KeychainTokenStore(…, accessGroup:)` shares tokens with app extensions.
- `URLSessionHTTPClient.ephemeralSession` / `ephemeralConfiguration()`: no URL cache, cookie or credential storage.
- A `PrivacyInfo.xcprivacy` manifest (no tracking, no collected data, no required-reason APIs).

### Changed

- **Breaking — ID/URL casing:** every model property, initializer parameter and enum case follows the API Design Guidelines' acronym rule, matching the argument labels: `userId` → `userID`, `broadcasterUserId` → `broadcasterUserID`, `thumbnailUrl` → `thumbnailURL`, `userIds` → `userIDs`, `verificationUri` → `verificationURI`, `imageUrl1x` → `imageURL1x` (100 names). `JSONDecoder`/`JSONEncoder` use a Twitch key strategy that maps `user_id` ↔ `userID` and `user_ids` ↔ `userIDs`; EventSub condition dictionaries keep their snake_case keys.
- **Breaking — default scopes:** `TwitchAuth.defaultScopeCases` / `defaultScopes`, used when an OAuth helper gets no `scopes:`, are now just `user:read:chat` and `user:write:chat`. `user:read:email`, `moderator:read:followers`, `channel:read:subscriptions`, `channel:manage:broadcast` and `channel:read:stream_key` must be requested explicitly. Twitch asks apps to request only the scopes they use.
- **Breaking — webhook verification:** the four-argument `EventSubWebhookVerifier.isValid(messageID:timestamp:body:signature:)` now always checks the timestamp (it previously resolved to the signature-only overload, so replayed requests passed). `EventSubWebhookVerifier(secret:)` throws for an invalid secret, and `secret` is deprecated. Webhook subscription and conduit-shard transports are validated locally: https, port 443 (or none), valid secret.
- Networking: `URLSessionHTTPClient()` and the EventSub WebSocket factory default to `ephemeralSession` instead of `URLSession.shared`, and Helix/OAuth requests set `.reloadIgnoringLocalCacheData`, so authenticated responses (stream keys, emails, token validation) never reach the on-disk URL cache and `id.twitch.tv` cookies aren't kept.
- Auth: validation rejects a token issued to another client ID (`.invalid(.tokenClientMismatch)`) and forgets it; a rejected token without a refresh token is forgotten locally instead of being handed out again. `TwitchTokenInfo.clientID` is `String?`.
- Auth: Keychain updates and legacy-item migration apply `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so items written by older versions are upgraded.
- Auth: `OAuthToken`, `DeviceCodeAuthorization`, `TwitchOAuthClient`, `EventSubWebhookVerifier`, `EventSubSubscriptionTransport` and `EventSubConduitShardTransport` redact secrets from `description`, `debugDescription` and `dump(_:)`.
- Dates: `Date.ISO8601FormatStyle` replaces the locked `ISO8601DateFormatter` cache; sub-millisecond precision in Twitch's nanosecond timestamps is now kept instead of truncated.
- Logging: non-secret context (endpoints, subscription types, retry delays, error descriptions) is logged `.public`; tokens, bodies, session IDs and decode-error descriptions that can echo chat text stay `.private`.
- Removed the retired stream-tag endpoints (`fetchAllStreamTags`, `fetchStreamTags`, `StreamTag`) and `UserAuthorization.clientId`, which Twitch never returns.
- EventSub: `TwitchAppTokenProvider.revoke()` waits for an in-flight token request and revokes that token too.
- EventSub: `subscribe()` connects first when the client isn't connected, instead of throwing "call connect() first". `disconnect(forgettingSubscriptions: true)` also forgets the subscriptions the client would re-create on the next `connect()`, for sign-out and account switches; previously the next account's session re-created the previous user's subscriptions. A plain `disconnect()` still keeps them.
- Auth: `TwitchScope` is now a struct wrapping the scope string instead of a closed enum. Every documented scope is still a static member (`.userReadChat`), and any other scope string works through `TwitchScope("…")` or a string literal, so a scope Twitch adds can be requested before TwitchKit lists it, mixed with listed ones in the same array. That makes the 16 `rawScopes: [String]` overloads on `TwitchOAuthClient` and `TwitchAuth` redundant; they're deprecated and forward to the `scopes:` versions. `TwitchTokenInfo.scopes` is `[TwitchScope]`.
- Auth: `validateToken()` on `TwitchAuth` and `TwitchTokenProvider` returns the current token's `TwitchTokenInfo` (discardable, so existing calls compile unchanged). After refreshing a rejected token it validates the new one, which costs one extra request.
- Auth: `logout()` on `TwitchAuth` and `TwitchTokenProvider` now revokes the access token on Twitch after deleting it locally, as the authentication guide already described. Revocation is best effort: a failure is logged, not thrown, so signing out still works offline. `logout(revokingToken: false)` only forgets the token locally. A refresh that Twitch rejects still logs out without revoking.
- Helix: `deleteChatMessages(broadcasterID:moderatorID:messageID:)` is deprecated in favor of `deleteChatMessage` and `clearChat`.
- Helix: an HTTP status without a dedicated `HelixError` case now throws `.unexpectedStatus` with Twitch's error body instead of `.serverError`, which is now only used for 5xx. A 410 used to read as "Server error (HTTP 410)".
- EventSub: the `isLive` reconnect closure on `TwitchClient` and `EventSubClient` is renamed `shouldKeepReconnecting`, which says what it controls: while it returns `true` the client retries forever with a 5s-capped backoff; while it returns `false` the client gives up after 5 attempts (~31s). It's called before each attempt, so it can depend on app state rather than on whether a channel is live, for example `{ await appState.hasOpenChat && appState.isInForeground }`. `isLive:` still compiles as a deprecated spelling.
- EventSub: clients keep reconnecting by default. `shouldKeepReconnecting` now defaults to `{ true }` on `TwitchClient` (it was `{ false }`), and `EventSubClient` gets the same default instead of requiring the closure. Previously a default client gave up about 31 seconds after the socket dropped and stayed disconnected until the network changed or the app called `connect()`.
- API naming: every argument label now spells acronyms uniformly (`broadcasterID`, `userID`, `clientID`, `redirectURI`), and the `for` prefix most endpoints never used is gone (`fetchChannelInfo(broadcasterID:)`, not `fetchChannelInfo(forBroadcasterID:)`). Model properties use the same casing (see the ID/URL rename below). The previous argument-label spellings remain as deprecated forwarders with fix-its and will be removed before 1.0.
- Helix: single-item fetches follow one rule. Lookups that can legitimately find nothing (`fetchUser(id:)`, `fetchUser(login:)`, `fetchGame(id:)`, `fetchGame(name:)`, `fetchChannelInfo(broadcasterID:)`) now return `nil`, joining `fetchStream`, `fetchCharityCampaign`, `fetchHypeTrainStatus` and the other optional reads. Reads that always have a result (`fetchUser()`, `fetchChatSettings`, `fetchAdSchedule`, …) and every write return their result directly. If Twitch answers one of those with empty `data`, the call throws the new `HelixError.emptyResponse`. `HelixError.notFound` now only ever means HTTP 404; it was previously also thrown for empty responses at about 40 call sites.

### Fixed

- OAuth: Device Code Flow polling no longer throws on the first poll. Twitch's pending response is `{"status":400,"message":"authorization_pending"}` with no `error` key; `authorization_pending` and `slow_down` now match on either field. The token exchange sends `scopes` (as documented) instead of `scope`.
- EventSub: a subscription whose create request outlived its session is no longer recorded as active on the new session (where it never existed); it's re-created there.
- EventSub: after `disconnect(forgettingSubscriptions: true)`, leaving a room joined earlier no longer deletes a newer room's subscriptions, and a `ChatRoom` dropped without `leave()` releases its subscriptions.
- EventSub: a network restore during `connect()` no longer starts a competing reconnect ladder that failed the connect; `disconnect()` stops a `connect()` waiting on an interrupted ladder.
- EventSub: a channel's late events are no longer replayed into a `joinChat`/`events(for:)` stream created later.
- EventSub: the reconnect attempt count resets after a successful reconnect, so "gives up after 5 attempts" applies per outage rather than over the client's lifetime.
- EventSub: a `session_reconnect` URL is followed only if it's `wss://` on `twitch.tv`; anything else falls back to the normal reconnect.
- EventSub decoding: payloads that previously decoded as `.unknown` because a field Twitch marks optional or nullable was required — `Resubscription.isPrime`, `channel.chat.user_message_hold` `status`, Guest Star guest-update guest fields and `state`, `user.authorization.revoke` login/name, gigantify `power_up.emote` (`{id, name}`), `channel.subscription.message` emotes, automatic reward v2 messages, and the charity campaign `broadcaster_*` keys.
- EventSub: `connect()` while the client is reconnecting after a dropped socket no longer fails. The two attempts superseded each other's welcome wait, and the failing one's cleanup cancelled every receive loop, including the one that had connected. `connect()` now stops the reconnect attempt and connects on its own; if that fails, the client goes back to reconnecting.
- EventSub: network-path monitoring works again after `disconnect()` followed by `connect()`. `NWPathNetworkMonitor` reused an `NWPathMonitor`, which can't be restarted once cancelled, so the second session never saw path changes; if the network was down at `disconnect()`, reconnects stayed parked on `.waitingForNetwork` for good. The monitor now creates a new `NWPathMonitor` and `pathUpdates` stream on each start, and `disconnect()` no longer carries a stale "offline" into the next session. Custom `NetworkPathMonitoring` implementations must also support `start()` after `cancel()`.
- EventSub: `connect()` re-creates the subscriptions the client still wants (for example after `disconnect()`, or after the non-live reconnect ladder gave up) before returning. Previously the new session started empty: Twitch closed the unused socket after about 10 seconds, and chat only came back after the reconnect that followed. A subscription Twitch rejects is reported as `.subscriptionFailed`; a transient failure doesn't fail `connect()`, and the client retries in the background.
- Helix: `checkUserSubscription` decodes Twitch's Check User Subscription response. It previously reused the EventSub `channel.subscribe` model, which requires subscriber fields this endpoint never returns, so every successful call threw `.decodingFailed`.
- Helix: `banUser` decodes Twitch's Ban User response (`broadcaster_id`, `moderator_id`, `user_id`, `created_at`, `end_time`). It previously expected the Get Banned Users shape, so the ban was applied and the call then threw `.decodingFailed`.
- Helix: `deleteVideos` decodes the plain string array Twitch returns; successful deletes previously threw `.decodingFailed`.
- Helix and OAuth: `+` in query values is now percent-encoded. Twitch reads a literal `+` as a space, which altered values such as `utc_offset=+05:30`, the `Etc/GMT+5` timezone, searches for `C++`, pagination cursors, and OAuth `state` values.
- Helix: `fetchBitsLeaderboard` tolerates the empty-string dates Twitch returns when `started_at` is omitted (including the default no-argument call), and reports decode failures as `HelixError.decodingFailed` instead of a raw `DecodingError`.
- Helix: extension and game analytics reports decode Twitch's uppercase `URL` key, which `.convertFromSnakeCase` never mapped to `url`, so every analytics call failed to decode. `AnalyticsReportType.overviewV2` sends `overview_v2`, the only report type Twitch accepts.
- Helix: an empty pagination cursor (`"cursor": ""`) is treated as the last page, and paged sequences stop if Twitch returns the cursor that was just requested, instead of looping forever.
- Helix: a 401 for a missing scope or a broadcaster/user/client ID that doesn't match the token no longer triggers a token refresh and retry. Twitch's message now reaches the caller on `HelixError.unauthorized` instead of being discarded.
- EventSub: a revoked subscription is no longer re-created on every reconnect. The client forgets it when the `revocation` message arrives, instead of retrying a create Twitch will reject.
- EventSub: one subscription Twitch rejects during a post-reconnect resubscribe (a 400/401/403/404/422 that isn't about the token or the session) no longer stalls the reconnect ladder or blocks the remaining subscriptions. The client drops it, yields the new `EventSubEvent.subscriptionFailed(subscription, error)`, and continues. A ladder that gives up while the socket is still connected no longer emits `.disconnected`.
- EventSub: `unsubscribe(id:)` accepts the id `subscribe()` returned after reconnects have re-created the subscription under a new id, and deletes the live record. `unsubscribe` also forgets the subscription before its first await, so an in-flight resubscribe can't leave it live, and restores its state if the delete fails.
- EventSub: `events` and `connectionState` support any number of consumers. Each access returns an independent stream that receives every value, so two loops no longer split events between them, and cancelling one loop (for example a SwiftUI `.task` whose view disappears) no longer ends delivery for good. Events that arrive while nothing at all is iterating are buffered for up to 30 seconds for the next consumer. A new `connectionState` stream starts with the current state, and `currentConnectionState` reads it synchronously.
- Helix: rate-limited (429) requests are retried. By default TwitchKit waits for `Retry-After` or `Ratelimit-Reset` (measured against the response's `Date` header) and retries once, if the wait is at most 60 seconds. Paged sequences no longer fail mid-iteration when they hit the per-minute limit. A 429 that leaves points in the bucket, such as EventSub's subscription limits, is still surfaced immediately. Configure with `HelixRetryPolicy(rateLimitRetries:maxRateLimitDelay:)`.
- Helix: the single 503 retry no longer re-sends POST or PATCH requests, which could send a chat message twice or start a second commercial. Opt back in with `HelixRetryPolicy(retriesNonIdempotentRequests: true)`.
- Helix/Auth: when several requests are rejected with the same expired token, only the first refreshes; later ones retry with the token it produced instead of rotating the refresh token again. A 401 with no refresh token available now reports Twitch's rejection rather than the provider's generic error.

### Migration notes

- **ID/URL casing:** rename property accesses and initializer labels (`stream.userId` → `stream.userID`, `TwitchUser(…profileImageUrl:…)` → `profileImageURL:`). Code that decodes TwitchKit models with its own `JSONDecoder` should use `.convertFromSnakeCase` only for its own types; TwitchKit models expect `JSONDecoder.twitch()`'s key strategy.
- **Platforms:** apps must target iOS 18 / macOS 15 or later and build with Swift 6.2 (Xcode 26).
- **Scopes:** code relying on the old default scopes should pass them explicitly, for example `scopes: TwitchAuth.defaultScopeCases + [.moderatorReadFollowers, .channelReadSubscriptions]`.
- **Webhooks:** add `try` to `EventSubWebhookVerifier(secret:)`. Use `isSignatureValid` only if you check freshness yourself. Webhook secrets must be 10–100 ASCII characters.
- **New `HelixError` cases** (`.deviceCodeRejected`, `.oauthStateMismatch`, `.tokenClientMismatch`) need cases in exhaustive switches. Device-code polling past the deadline now throws `.deviceCodeRejected` instead of `.oauth(expired_token)`.
- **Optional/enum changes:** `noticeType` and `EventSubBitsUse.type` are enums (literal comparisons still compile; use `.rawValue` for a `String`); `Resubscription.isPrime`, `ChatUserMessageModeration.status`, `GuestStarGuestUpdate.guestUser*`/`state` and `UserAuthorization.userLogin`/`userName` are optional; `BitsUse.PowerUp.emote`, `SubscriptionMessage.message` and `AutomaticRewardRedemption.message` have their own types (`.text`/`.id` access still compiles).
- **Behaviour:** `events`/`notifications` keep events for at most 30 seconds while nothing is iterating, and once any stream exists, events no stream wants are dropped. `subscribe()` with no session now succeeds and creates the subscription on the next connect. A `connect()` interrupted by `disconnect()` throws.
- `checkUserSubscription` returns `UserSubscription?` (broadcaster and gifter details, tier) and returns `nil` when the user doesn't subscribe, instead of throwing `.notFound`.
- `banUser` returns `BanUserResponse` (`endTime` is `nil` for permanent bans). Use `fetchBannedUsersPage`/`bannedUsers` for login names and the ban reason.
- `BitsLeaderboard.dateRange` is now `BitsLeaderboard.DateRange` with optional dates.
- `AnalyticsReportType.overview` is deprecated; use `.overviewV2`.
- `HelixError.unauthorized` now carries `TwitchAPIError?` (Twitch's 401 body). Patterns like `catch HelixError.unauthorized` still match; code that constructs the error writes `.unauthorized(nil)`.
- `EventSubClient.events` and `connectionState` are now computed properties that return a new stream on each access. Iterate the property directly (`for await event in client.events`) or keep the stream you were given; code that stored one stream and iterated it from several tasks should give each task its own.
- The status fields listed under Added are enums instead of `String`. Comparisons with string literals (`poll.status == "ACTIVE"`) still compile because the enums accept string literals; use `.rawValue` where a `String` is needed. `ConduitShardStatus`, `DropsEntitlementFulfillmentStatus` and `SuspiciousUserStatus` (previously closed `String` enums used only as parameters) gain an `.unknown` case and a non-failable `init(rawValue:)`; `SuspiciousUserStatus` adds `.noTreatment` and `ConduitShardStatus` the four newer `websocket_*` statuses. `UnbanRequestStatusFilter` is renamed `UnbanRequestStatus` (the old name is a deprecated alias).
- `fetchUser(id:)`, `fetchUser(login:)`, `fetchGame(id:)`, `fetchGame(name:)` and `fetchChannelInfo(broadcasterID:)` return optionals; replace `catch HelixError.notFound` around them with `guard let … else`. Code that caught `.notFound` from a write or an always-present read should catch `.emptyResponse`. The deprecated `fetchChannelInfo(forBroadcasterID:)` keeps its non-optional result and still throws `.notFound`. `HelixError` gains `.emptyResponse`, so exhaustive switches need a case for it.
- Renamed argument labels (deprecated forwarders keep the old ones compiling; apply Xcode's fix-its): `clientId:` → `clientID:` and `redirectUri:` → `redirectURI:` on `TwitchClient`, `TwitchAuth`, `TwitchOAuthClient`, `HelixClient` and `KeychainTokenStore`; `forBroadcasterID:`/`forBroadcasterIDs:`/`forUserID:` → `broadcasterID:`/`broadcasterIDs:`/`userID:` on 23 Helix methods; `sendChatMessage(broadcasterID:senderID:message:replyParentMessageID:)`; `createEventSubSubscription(…sessionID:)`; and the `broadcasterID:`, `gameID:`, `categoryID:` and `msgID:` labels on `PollCreateRequest`, `PredictionCreateRequest`, `ChannelInfoUpdate`, `ChannelStreamScheduleSegmentCreate`/`Update` and `AutoModMessage`. `TwitchClient.clientId` → `clientID` and `TwitchAuth.redirectUri` → `redirectURI`.
- `HelixRetryPolicy.default` now retries a 429 once after waiting up to 60 seconds, and no longer retries a 503 for POST/PATCH. Use `.never`, or set `rateLimitRetries: 0`, to keep surfacing 429s immediately.
- A `TwitchClient` created without `isLive`/`shouldKeepReconnecting` now keeps reconnecting instead of giving up after 5 attempts. Pass `shouldKeepReconnecting: { false }` for the old behavior, or a closure that returns `false` once the app no longer needs the connection.
- `TwitchScope` is a struct: `TwitchScope(rawValue:)` no longer returns an optional, and a `switch` over scopes needs a `default`. Replace `rawScopes: strings` with `scopes: strings.map { TwitchScope($0) }`, or pass literals directly.
- `HelixError` gains `.unexpectedStatus(status:_:)`. Code that caught `.serverError` for a non-5xx status (for example 410) should catch `.unexpectedStatus`; exhaustive switches need a case for it.
- `logout()` now makes a network call to revoke the token. It still signs out locally first and doesn't throw when revocation fails; pass `revokingToken: false` to skip the call.
- Custom `NetworkPathMonitoring` types must support `start()` after `cancel()`, returning a new `pathUpdates` stream, because `EventSubClient` restarts the monitor on every `connect()`.
- `EventSubEvent` gains `.subscriptionFailed(EventSubSubscription, HelixError)`; exhaustive `switch` statements over `EventSubEvent` need a case for it.
- `TwitchAccessTokenProvider` gains `refreshIfNeeded(rejectedAccessToken:)`. A default implementation calls `refreshIfNeeded()`, so existing custom providers keep compiling; implement it to skip refreshes for tokens you've already replaced.

## [0.4.0] - 2026-09-21

### Added

- September 2026 API compatibility: GIF chat fragments, stream-offline IDs, AutoMod v2 blocked-link details, watch-streak/modiversary notifications, source-only announcements, and clip title/duration options.
- Auth: `OAuthToken` now records `obtainedAt` (stamped when stored) and exposes `expiresAt`/`isExpired(within:at:)`; the token provider proactively refreshes tokens within 60 seconds of expiry instead of paying a failed 401 round-trip.
- EventSub: an injectable `EventSubWebSocket` seam (`socketFactory` on `EventSubClient`/`TwitchClient`) so the WebSocket message-handling, dedup, keepalive, reconnect, and resubscribe paths are testable; ships with socket-driven tests.
- EventSub: `EventSubWebhookVerifier.isTimestampFresh` and combined signature+freshness `isValid` overloads reject replayed webhook requests older than Twitch's 10-minute window.
- Helix: `HelixError.transport(URLError)` preserves the underlying transport failure so callers can distinguish offline, timeout, and TLS errors.
- Helix: async paged-sequence helpers for clips, videos, moderators, VIPs, banned users, unban requests, blocked terms, moderated channels, custom reward redemptions, polls, predictions, drops entitlements, user emotes, extension transactions, the user block list, and conduit shards.
- Helix: batch-size and required-filter validation across the endpoint layer (emote sets, chat colors, redemptions, clip downloads, video deletion, drops entitlements, polls, streams, clips, videos, stream markers, teams), and per-endpoint page-size bounds — Get Chatters now accepts up to 1,000 per page.

### Changed

- Auth: Keychain items are scoped with `kSecAttrService`; legacy service-less items are migrated in place on first read and removed on logout.
- EventSub: the message dedup cache survives reconnects (Twitch replays notifications across them); exhausting the non-live reconnect ladder now emits `.disconnected` instead of parking silently; the give-up behavior of the default `isLive: { false }` is documented on both initializers.
- Helix: `updateConduitShards` returns `ConduitShardUpdateResult`, surfacing Twitch's per-shard `errors` array that was previously discarded.
- Helix: `fetchAllStreamTags`/`fetchStreamTags` are deprecated (Twitch retired stream tags in 2023).
- CI runs with code coverage enabled and gates on the DocC build.

### Fixed

- Restored pinned-chat endpoints and Send Chat Message's `pin` option, with duration and incompatible-parameter validation. The earlier audit incorrectly described these documented endpoints as nonexistent.
- Custom Power-ups now use `bits/custom_power_ups`, support ID filters, decode the documented `bits`/reward fields, and subscribe using EventSub version 1. Redemption events now decode `custom_power_up`, `user_input`, and `status` instead of requiring a nonexistent `type` field.
- Token validation now distinguishes a 401 from service failures; an outage no longer triggers token refresh. In-flight refresh success/rejection and token loads cannot overwrite a newer login or undo logout.
- User authorization now uses `authorization/users`, supports up to ten user IDs, and decodes `has_authorized` without requiring a nonexistent `client_id`.
- OAuth error classification preserves the HTTP status when JSON omits it; server outages cannot be mistaken for rejected credentials.
- Conduit shard updates enforce Twitch's documented 1–100 shard batch size.
- Helix: `CustomRewardImage` used pre-conversion snake_case `CodingKeys` raw values (`"url_1x"`), which `.convertFromSnakeCase` can never match — every Get/Create/Update Custom Reward call failed to decode. `CustomRewardLimitSetting.value` now also decodes Twitch's endpoint-specific keys (`max_per_stream` / `max_per_user_per_stream`); it previously silently decoded as `nil` on every response.
- Auth: `TwitchOAuthClient` wraps transport-level `URLError`s as `HelixError.transport`, matching `HelixClient`, so token-endpoint callers can distinguish offline/timeout/TLS failures with one error type.
- EventSub: an `unsubscribe()` that raced an in-flight resubscribe round (actor reentrancy across the create's `await`) is no longer resurrected — the freshly created server-side subscription is deleted instead of being written back into the client's maps.
- EventSub: the `session_reconnect` handoff task captures the client weakly, matching every other stored task, instead of pinning the actor until the handoff resolves.
- EventSub: client-initiated socket teardown sends close code `goingAway` instead of `abnormalClosure` (1006), which RFC 6455 reserves for *reporting* abnormal closes and forbids sending on the wire.
- Helix: `deleteAllEventSubSubscriptions` tolerates a 404 on an individual delete (already removed by a concurrent operation) instead of aborting the run and losing the deletion count.
- Helix: `AdSnooze.snoozeRefreshAt`/`nextAdAt` are now optional and tolerate Twitch's empty-string dates, matching the hardening `AdSchedule` received.
- Helix: the single 503 retry now waits 100–400 ms (jittered) instead of re-requesting an already-degraded service immediately.
- Privacy: the raw response body logged when a Helix decode fails is explicitly `.private` (the path sits under stream-key/extension-secret/conduit-secret endpoints), and EventSub envelope-decode failures no longer force raw payload prefixes (which can carry chat content) to `.public`.
- Performance: `EventSubClient` reuses one actor-isolated `JSONDecoder` for the envelope and typed-notification passes instead of allocating two decoders per received message.
- Auth: a failed token refresh no longer logs the user out on transient errors (network timeouts, token-endpoint outages). The stored token is only destroyed when the OAuth server definitively rejects the refresh (a 400/401/403 OAuth error). Concurrent `refreshIfNeeded()` calls now coalesce onto a single in-flight refresh instead of racing the same refresh token, which Twitch rotates on use.
- EventSub: the client can now deallocate after being dropped. Its path-monitor, receive-loop, keepalive-watchdog, and reconnect tasks previously retained the actor while suspended, making `deinit` (and its socket/monitor cleanup) unreachable once connected. The reconnect ladder also no longer grows an async frame per failed attempt.
- EventSub: `connect(timeout:)` now honors its deadline. The internal session-welcome wait is cancellation-aware, so a connected-but-silent server fails the connect at the configured timeout instead of blocking until the socket errors.
- EventSub: a partial resubscribe failure after reconnecting no longer wedges the reconnect ladder re-creating already-active subscriptions (409 conflicts are treated as already-subscribed), and stale subscription record IDs are pruned instead of accumulating.
- Helix: `deleteAllEventSubSubscriptions` re-fetches the first page after each round of deletions instead of following a cursor invalidated by the deletes, which skipped subscriptions when more than one page existed.
- Helix: `ExtensionLiveChannelsPage` decodes the plain-string pagination cursor Get Extension Live Channels actually returns; a second page previously failed the whole decode.
- Helix: `ChannelPointsRedemptionStatus` now sends and returns Twitch's required uppercase values (`UNFULFILLED`/`FULFILLED`/`CANCELED`); the lowercase values previously caused 400s on redemption endpoints and made decoded statuses land in `.unknown`. Decoding remains tolerant of lowercase inputs.
- Helix: stream schedule endpoints now decode Twitch's single-object `data` envelope (they could never decode before), and `updateChannelStreamSchedule` sends vacation settings as query parameters instead of a JSON body Twitch silently ignored.
- Helix: `ShieldModeStatus.lastActivatedAt` is now optional and tolerates the empty string Twitch sends when Shield Mode was never activated; `AdSchedule`'s date fields tolerate the empty strings sent for offline channels. Both previously failed the whole response decode.

### Migration notes

- `updateConduitShards` now returns `ConduitShardUpdateResult`; read `updated` and `errors` to handle partial failures.
- `ShieldModeStatus.lastActivatedAt` is optional; handle channels that have never enabled Shield Mode.
- User-authorization responses now expose `hasAuthorized`; `clientId` is optional and deprecated because Twitch does not return it. Use `fetchAuthorization(userID:)` or `fetchAuthorizations(userIDs:)` with an app access token.

- `CustomPowerUp.sku` and `EventSubCustomPowerUpRedemption.type`/`message` were not fields in Twitch's response and have been removed. Use `CustomPowerUp.bits` (the former `cost` remains a deprecated alias), and the redemption's `customPowerUp`, `userInput`, and `status`. `redeemedAt` is now required by the documented redemption contract.
- `AdSnooze` dates are optional, matching the defensive handling of empty date strings in `AdSchedule`.

## [0.3.4] - 2026-06-12

### Fixed

- `TwitchStream` now decodes successfully when Helix returns `"tags": null` (which `Get Streams` / `Get Followed Streams` send for streams that have no tags set). Previously the non-optional `tags` array threw `DecodingError.valueNotFound`, failing the entire response decode. A null or absent `tags` field now decodes to an empty array.

## [0.3.0] - 2026-06-01

### Added

- EventSub: network-path-aware reconnect plus a public `connectionState` stream (`ConnectionState`) consumers can observe to drive UI such as a "Reconnecting…" indicator.
- Added the `NetworkPathMonitoring` protocol, `NetworkPathStatus` enum, and `NWPathMonitor`-backed `NWPathNetworkMonitor`. `EventSubClient` and `TwitchClient` gained a defaulted `pathMonitor` parameter; all new API is additive and existing call sites compile unchanged.

### Changed

- EventSub now pauses its reconnect loop while the network path is unsatisfied and reconnects immediately (resetting backoff) the instant the path is satisfied again, instead of burning retry attempts into a dead network. The `isLive` backoff ladder still governs non-network socket drops.

## [0.2.3] - 2026-05-28

### Changed

- Reused TwitchKit's locked ISO-8601 date formatter cache for analytics, schedule, and media query dates to avoid creating duplicate formatter helpers.
- Switched OAuth device-code polling expiration to `ContinuousClock` so polling is not affected by wall-clock changes.
- Simplified Twitch emote image URL template replacement.

## [0.2.2] - 2026-05-28

### Added

- Added configurable EventSub notification buffering through `TwitchClient(eventBufferingPolicy:)`.
- Documented EventSub subscription record returns, unsubscribe flows, bulk cleanup helpers, webhook signature verification, and bounded EventSub event buffering.
- Expanded DocC Helix examples for chat, moderation, channel points, clips/videos, polls/predictions, EventSub management, and pagination.
- Added common Twitch scope guidance and smoke-test command examples to README and DocC.

### Changed

- Bounded EventSub duplicate-message tracking to prevent unbounded memory growth during long-lived WebSocket sessions.
- EventSub notifications now buffer the newest 1,000 events by default instead of using unbounded buffering.
- Hardened EventSub WebSocket lifecycle cleanup and overlapping connect attempts.
- Updated README status/planned-work language to match current Helix coverage.

## [0.2.1] - 2026-05-27

### Changed

- Lowered the Swift tools requirement from 6.2 to 6.0 so Swift 6.0 and 6.1 toolchains can load the package.

## [0.2.0] - 2026-05-26

### Added

- Added remaining broad Helix API coverage for ads, analytics, Bits, EventSub conduits, Drops entitlements, extension management, user extension activation, Guest Star, tags, teams, user block/authorization helpers, followed streams, and whispers.
- Added request-construction tests for the newly covered Helix endpoint families.

### Changed

- Promoted `0.2.0` to the first non-prerelease package release.

## [0.2.0-beta.4] - 2026-05-26

### Changed

- Lowered declared platform requirements to iOS 16 and macOS 13 without code changes.
- Renamed the smoke-test executable source away from `main.swift` so Xcode package builds can compile the `@main` entry point on iOS.

## [0.2.0-beta.3] - 2026-05-26

### Added

- Added typed EventSub notification payloads for the remaining current Twitch subscription type families, including AutoMod, Bits use, ads, shared chat, Guest Star, custom power-up redemptions, suspicious users, conduits, drops, extension Bits transactions, user authorization/update, and whispers.
- Added EventSub decoding coverage tests for remaining typed payload families.

## [0.2.0-beta.2] - 2026-05-26

### Added

- Added typed EventSub notification payloads for chat notifications, user message hold/update, channel moderation actions, channel points reward changes, automatic reward redemptions, polls, predictions, goals, Hype Train, charity campaigns, and charity donations.
- Added README support tables for Helix and EventSub coverage.
- Added Swift Package Index badges and `.spi.yml` documentation target configuration.

## [0.2.0-beta.1] - 2026-05-26

### Added

- Expanded Helix creator and channel-management coverage for followed channels, editors, content classification labels, search, schedules, charity, Hype Train, polls, predictions, raids, stream markers, goals, channel points rewards, subscriptions, clips, and videos.
- Expanded Helix chat coverage for chatters, emote sets, user emotes, chat settings, shared chat sessions, announcements, shoutouts, pinned messages, and user chat colors.
- Expanded Helix moderation coverage for AutoMod, bans/timeouts, unban requests, blocked terms, chat message deletion, moderated channels, moderators, VIPs, Shield Mode, warnings, and suspicious-user status.
- Expanded EventSub subscription factories across chat, subscriptions, moderation, channel points, polls, predictions, goals, Hype Train, charity, user, and whisper events.
- Typed EventSub payload decoding for key chat moderation, subscription lifecycle, unban request, VIP, Shield Mode, shoutout, and warning events.
- EventSub subscription creation now supports Twitch's batching flag for Drop entitlement subscriptions.

## [0.1.0-alpha.3] - 2026-05-25

### Added

- Grouped EventSub subscription factories for chat, channel, stream, moderation, and channel points domains.
- Typed EventSub event payloads for channel updates, stream online/offline, raids, cheers, bans, unbans, moderator changes, and custom reward redemptions.
- EventSub subscription listing, pagination, filtering, cost metadata, and deletion helpers.
- Forward-compatible `RawRepresentable` enums for Twitch stream types, EventSub transport methods, EventSub subscription statuses, chat domains, and channel points redemption statuses.
- Local validation for EventSub subscription management calls that would otherwise be rejected by Twitch.
- `TwitchKitSmokeTest` executable target for live Twitch API, EventSub, chat, and cleanup smoke checks.
- Typed Helix rate-limit metadata and configurable retry policy for Twitch's recommended 503 retry.
- Successful Helix page responses and optional client callbacks now expose response metadata.
- Configurable Helix request timeouts and cancellation-preserving network error handling.
- EventSub connection timeout cleanup and reconnect cancellation when disconnecting.

### Changed

- Public documentation comments for newer Helix metadata, retry, timeout, and facade APIs.

## [0.1.0-alpha.2] - 2026-05-25

### Added

- `TwitchOAuthClient` for OAuth URL construction and token exchange.
- `TwitchTokenStore`, `KeychainTokenStore`, and `InMemoryTokenStore` for configurable token persistence.
- `TwitchTokenProvider` for loading, validating, refreshing, and supplying access tokens.
- `HelixClient` initializer that accepts any `TwitchAccessTokenProvider`.
- Helix pagination primitives and channel followers pagination helpers.
- Shared Helix query helpers for repeated parameters, optional parameters, and cursor pagination.
- Helix user lookup helpers for fetching users by ID and login.
- Helix stream and game/category helpers, including paginated streams and top games.
- Typed Send Chat Message request encoding and response coverage, including `for_source_only` and `pin`.
- EventSub subscription transport support for webhook, WebSocket, and conduit creation requests.

### Changed

- `TwitchAuth` is now a convenience facade over the OAuth client and token provider.
- `HelixClient` endpoint methods are organized into focused extension files by API area.
- Keychain writes now use an add-or-update flow and device-only background-safe accessibility.
- Helix errors preserve Twitch's structured error response.
- Helix response handling is shared across standard data responses, accepted responses, and no-content responses.
- Helix pages now preserve response `total` values when Twitch includes them.

## [0.1.0-alpha.1] - 2026-05-25

### Added

- Initial Swift Package for Twitch Helix API and EventSub WebSocket support.
- `TwitchClient` facade that exposes authentication, Helix API, and EventSub clients.
- OAuth helpers for:
  - OAuth implicit grant
  - OAuth authorization code grant
  - OIDC implicit grant
  - OIDC authorization code grant
  - OAuth client credentials grant
  - OAuth device code grant
  - External token injection
- `TwitchScope` catalog covering Twitch API, EventSub, IRC chat, and PubSub-specific chat scopes.
- Keychain-backed token storage with client/account namespacing.
- Helix helpers for:
  - Authenticated user profile
  - Stream key
  - Channel information
  - Channel updates
  - Global and channel emotes
  - Global and channel badges
  - Chat message sending
  - EventSub subscription creation
- EventSub WebSocket client with:
  - Async event stream
  - Welcome timeout
  - Keepalive timeout handling
  - Reconnect handling
  - Automatic resubscription after full reconnect
  - Duplicate message filtering
  - Revocation events
- Typed models for selected Twitch API and EventSub payloads.
- Forward-compatible enums for selected Twitch string domains:
  - `ChatMessageType`
  - `ChatFragmentType`
  - `SubscriptionTier`
  - `BadgeClickAction`
- `ChannelInfoUpdate` request type for channel updates.
- Model decoding and API design tests.
- GitHub Actions CI workflow running `swift test`.

### Notes

- This is an alpha prerelease. Public APIs may change before `1.0.0`.
- The package currently targets Swift 6.0 tools, Swift 6 language mode, iOS 16, and macOS 13.
- TwitchKit currently covers a focused subset of Helix and EventSub. More endpoints and typed EventSub subscriptions are planned.
