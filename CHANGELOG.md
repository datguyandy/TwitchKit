# Changelog

All notable changes to TwitchKit will be documented in this file.

TwitchKit follows semantic versioning while it is pre-1.0. During the 0.x series, minor versions may include source-breaking API changes as the package matures.

## [Unreleased]

### Fixed

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
- EventSub: `events` and `connectionState` support any number of consumers. Each access returns an independent stream that receives every value, so two loops no longer split events between them, and cancelling one loop (for example a SwiftUI `.task` whose view disappears) no longer ends delivery for good. Events that arrive while nothing is iterating are still buffered for the next consumer. A new `connectionState` stream starts with the current state, and `currentConnectionState` reads it synchronously.
- Helix: rate-limited (429) requests are retried. By default TwitchKit waits for `Retry-After` or `Ratelimit-Reset` (measured against the response's `Date` header) and retries once, if the wait is at most 60 seconds. Paged sequences no longer fail mid-iteration when they hit the per-minute limit. A 429 that leaves points in the bucket, such as EventSub's subscription limits, is still surfaced immediately. Configure with `HelixRetryPolicy(rateLimitRetries:maxRateLimitDelay:)`.
- Helix: the single 503 retry no longer re-sends POST or PATCH requests, which could send a chat message twice or start a second commercial. Opt back in with `HelixRetryPolicy(retriesNonIdempotentRequests: true)`.
- Helix/Auth: when several requests are rejected with the same expired token, only the first refreshes; later ones retry with the token it produced instead of rotating the refresh token again. A 401 with no refresh token available now reports Twitch's rejection rather than the provider's generic error.

### Migration notes

- `checkUserSubscription` returns `UserSubscription?` (broadcaster and gifter details, tier) and returns `nil` when the user doesn't subscribe, instead of throwing `.notFound`.
- `banUser` returns `BanUserResponse` (`endTime` is `nil` for permanent bans). Use `fetchBannedUsersPage`/`bannedUsers` for login names and the ban reason.
- `BitsLeaderboard.dateRange` is now `BitsLeaderboard.DateRange` with optional dates.
- `AnalyticsReportType.overview` is deprecated; use `.overviewV2`.
- `HelixError.unauthorized` now carries `TwitchAPIError?` (Twitch's 401 body). Patterns like `catch HelixError.unauthorized` still match; code that constructs the error writes `.unauthorized(nil)`.
- `EventSubClient.events` and `connectionState` are now computed properties that return a new stream on each access. Iterate the property directly (`for await event in client.events`) or keep the stream you were given; code that stored one stream and iterated it from several tasks should give each task its own.
- `HelixRetryPolicy.default` now retries a 429 once after waiting up to 60 seconds, and no longer retries a 503 for POST/PATCH. Use `.never`, or set `rateLimitRetries: 0`, to keep surfacing 429s immediately.
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
