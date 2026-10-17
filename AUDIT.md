# TwitchKit Code Audit

## Current audit — 2026-10-18

**Starting state:** `main` at `2cb0b1d` (0.4.0), clean. Two unmerged branches: `claude/audit-round-2-fixes` (all of its fixes and tests were already on `main`; left in place for the owner to delete) and `claude/affectionate-einstein-0yfloq` (25 commits, based on `main`'s tip, 332 passing tests), which was fast-forwarded into `main` and then corrected by the findings below.

**Method:** four independent reviews, each read-only and verified against code paths: (1) a correctness review of the 25 branch commits, (2) a field-level comparison with Twitch's current docs — the changelog since August 2026, all 149 Helix method/path pairs, all 77 EventSub type/version pairs, ~60 payloads and all 81 scopes, (3) Swift 6 concurrency and API Design Guidelines, and (4) security, privacy and Apple-platform requirements. Fixes were made with a regression test each; the EventSub lifecycle tests were checked to fail with their fix removed.

### Findings addressed

| Priority | Area | Finding | Resolution |
| --- | --- | --- | --- |
| P0 | OAuth | Device Code Flow threw on the first poll: Twitch's pending body has `message: "authorization_pending"` and no `error` key | Match `error` or `message`, case-insensitively; typed `.deviceCodeRejected`; send `scopes` |
| High | EventSub | A subscribe that outlived its session was recorded active on the new session, where it didn't exist — events silently never arrived | Session check after the create; re-create on the current session |
| High | EventSub | After a forgetting disconnect, an old `ChatRoom.leave()` deleted a newer room's subscriptions (common in SwiftUI account switches) | Rooms carry their subscription generation; stale leaves are no-ops |
| High | Security | The four-argument webhook `isValid` resolved to the signature-only overload, so replayed requests passed | `isValid` always checks freshness; `isSignatureValid` is explicit |
| Medium | EventSub | Network restore during `connect()` started a racing ladder that failed the connect | No ladder while a connect is in flight |
| Medium | EventSub | Late events were replayed into chat rooms joined later | Backlog only while there are no consumers, max 30 s; filtered streams never replay |
| Medium | EventSub | Reconnect attempts never reset, so the "5 attempts" limit was per client lifetime | Reset on `session_welcome` and successful reconnects |
| Medium | EventSub | `ChatRoom` dropped without `leave()` leaked its subscription claims | Released from `deinit` |
| Medium | EventSub | A 409 on create discarded the existing subscription's ID, so it could never be deleted | `TwitchAPIError.id`, recorded on conflict |
| Medium | Security | Authenticated responses could be written to the shared on-disk `URLCache`; `id.twitch.tv` cookies persisted | Ephemeral session by default, per-request cache policy, WebSocket included |
| Medium | Security | A valid token issued to another client ID was accepted | `client_id` checked on validation and callback; mismatches are forgotten |
| Medium | Security | No OAuth `state` generation or check; implicit callbacks unparsed | `makeState()`, `parseCallback(_:expectedState:)`, `authenticate(withCallbackURL:expectedState:)` |
| Medium | API | `channel.chat.notification` missed the 2026-10-01 gifted-drops notices and every `shared_chat_*` payload; six other event types decoded as `.unknown` because optional fields were required | Fields added; optionality corrected against the reference |
| Medium | Privacy | Default scopes requested the stream key, email and broadcast management | Defaults are chat-only (owner-approved) |
| Low | EventSub/Auth | `disconnect()` didn't stop a waiting `connect()`; lazy path-update read; rejected token without refresh token kept in use; app-token revoke race; unchecked `session_reconnect` host | Each fixed with a test |
| Low | Security | Keychain accessibility not applied on update/migration; secrets visible in `print`/`dump`; webhook/conduit secrets and callbacks unchecked; decode errors that can echo chat logged `.public` | Fixed; `PrivacyInfo.xcprivacy` added |
| Low | Swift | Swift 6.0 tools, iOS 16/macOS 13, ~80 bare existentials, a per-call `DateFormatter`, a locked `ISO8601DateFormatter` cache, `Id`/`Url` property casing | Swift 6.2 + upcoming features, iOS 18/macOS 15 (owner-approved), `@concurrent` network paths, `Date.ISO8601FormatStyle`, ID/URL rename (owner-approved) with a Twitch key strategy |

### Twitch changes checked

- [Documentation changelog](https://dev.twitch.tv/docs/change-log/): one entry since the previous audit (2026-10-01, gifted-drops notice types). No deprecations, decommissions, EventSub version bumps or new scopes; the [announcements forum](https://discuss.dev.twitch.com/c/announcements/13) has had no posts since 2026-05-01.
- [API reference](https://dev.twitch.tv/docs/api/reference/), [EventSub reference](https://dev.twitch.tv/docs/eventsub/eventsub-reference/), [subscription types](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/), [OAuth flows](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/), [scopes](https://dev.twitch.tv/docs/authentication/scopes/), [token validation](https://dev.twitch.tv/docs/authentication/validate-tokens/).

### Remaining limits and deferred work

- Verified with mocked HTTP/WebSocket transports and recorded Twitch-documented payloads. No authenticated Twitch calls, iOS device runs, or signed-Keychain behaviour were exercised.
- `channel.moderate` v2 lacks its `shared_chat_*`/`source_*` fields, Guest Star updates lack `host_*`, and the v1 automatic-reward `unlockedEmote` can't decode `{id, name}` (TwitchKit subscribes to v2).
- `HelixError.networkError(String)` still flattens non-`URLError` failures; a typed underlying error would be source-breaking and is left for a later release. Public `TimeInterval` parameters have no `Duration` overloads yet.
- Tests are XCTest (398); a Swift Testing migration and clock injection to replace the remaining fixed sleeps are worthwhile but not done. About 2,000 public declarations, mostly model properties, lack doc comments.
- `AsyncBroadcaster` and `NWPathNetworkMonitor` keep `NSLock`-guarded `@unchecked Sendable` state; both were reviewed as correct. `Date.HTTPFormatStyle` parsing needs iOS/macOS 26, so the cached `DateFormatter` stays.
- Apps still own webhook message-ID deduplication and OIDC `id_token` verification (documented in the README).

### Verification

- `swift build --build-tests`: no warnings, no errors (Swift 6.4, macOS).
- `swift test`: **398 tests, 0 failures**.
- `swift package generate-documentation --target TwitchKit`: no warnings.

## Previous audit — 2026-09-21

**Starting state:** clean `claude/audit-round-2-fixes` at `2c2a137`, two commits ahead of `main`. Switched to `main` and fetched/pulled successfully; upstream remains `72b0666`. Last tagged release is `0.3.4`; the larger July audit is merged but unreleased. The old branch is preserved. Its two commits' changes were reviewed and incorporated into the working tree, without moving `main` or rewriting history.

**Method:** reviewed authentication/token lifecycle, HTTP requests and errors, EventSub lifecycle/cleanup, webhook verification, endpoint routes, recent payload changes, tests, smoke example, CI, and documentation. Compared every literal Helix route against the live API reference and inspected affected request/response contracts. This is a targeted correctness and API-compatibility audit, not a claim of exhaustive field-by-field coverage of every Twitch endpoint.

### Findings addressed

| Priority | Finding | Resolution |
| --- | --- | --- |
| High | Earlier audit incorrectly removed real pinned-chat endpoints | Restored GET/PUT/PATCH/DELETE `chat/pins`, response model, and send-message `pin`; validated duration and incompatible parameters. |
| High | Custom Power-up endpoint and models did not match Twitch | Corrected route to `bits/custom_power_ups`, ID filters, `bits`/reward settings, EventSub v1, and redemption payload. |
| High | User authorization endpoint and model could not work | Corrected route to `authorization/users`, added batch lookup and `has_authorized`, stopped requiring nonexistent `client_id`. |
| High | Late refresh success/rejection could undo logout or affect a new login | Added token revision checks across refresh, validation, and initial storage loads. |
| High | OAuth outage could trigger refresh or delete credentials | Only validation 401 is invalid-token; preserve actual HTTP status even when an OAuth error body omits status. |
| Medium | Reward image and limit settings failed or silently lost values | Incorporated unmerged image-key and endpoint-specific limit fixes. |
| Medium | Unsubscribe during resubscribe could resurrect a subscription | Incorporated the reentrancy fix and retained failed cleanup deletions for reconnect retries. |
| Medium | Transport/cancellation and WebSocket close behavior | Unified typed transport errors, preserved OAuth cancellation, stopped sending reserved WebSocket close code 1006. |
| Medium | Current EventSub fields were silently discarded | Added GIF fragments, offline stream IDs, blocked-link/AutoMod details, watch streaks, modiversary fields, and source-only metadata. |
| Medium | Missing documented request options/limits | Added clip title/duration, source-only announcements, and 1–100 conduit shard validation. |
| Medium | Concurrent subscription deletion aborted bulk cleanup | Treat already-deleted subscriptions as absent and continue draining. |
| Low | Sensitive payload prefixes could enter diagnostics | Private logging for Helix response bodies and EventSub message prefixes. |
| Low | Webhook examples selected signature-only overload | Explicit `maxAge` now selects signature plus freshness checking in README/DocC. |

### Twitch changes checked

- [Documentation changelog](https://dev.twitch.tv/docs/change-log/): September 16 blocked-link reason, July 16 GIF fragments, June offline IDs/modiversary/goal types/conduit batch limit, May pinned-chat general availability and custom Power-up v1, and earlier 2026 clip/announcement/authorization changes.
- [API reference](https://dev.twitch.tv/docs/api/reference/): pinned chat, custom Power-ups, authorization by user, clip creation, announcements, ads, and conduit updates.
- [EventSub reference](https://dev.twitch.tv/docs/eventsub/eventsub-reference/): notification payloads and custom Power-up redemptions.
- [EventSub subscription types](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/): version/condition checks.

Goal types already use strings, team image fields are already optional, Hype Train builders already use v2, and subscription filtering already supports conduit IDs. Extensions CSP and IRC-only changes do not affect this package's transport implementation.

### Compatibility and remaining limits

- Correcting previously unusable Power-up models removes nonexistent `sku`, redemption `type`, and redemption `message` fields; `cost` remains a deprecated alias. See CHANGELOG migration notes. New fields are optional where older valid payloads can omit them.
- Verified with local mocked HTTP/WebSocket tests, not authenticated Twitch calls. No live messages, subscriptions, clips, or channel settings were changed. iOS device/runtime and signed Keychain behavior were not exercised.
- Existing deferred work remains: cancellation responsiveness of callers awaiting shared connect/refresh tasks, full fidelity for other EventSub variants, public model construction APIs, and optional test/style modernization. Timestamp formatters remain unchanged to avoid an unrelated parsing regression.
- Custom asynchronous token stores still own the ordering/durability of their save/delete operations; revision guards protect stale network/load results, not arbitrary storage implementations.
- Signature-only webhook verification remains available for compatibility; use the explicit freshness overload and deduplicate message IDs in the host webhook handler.
- CodeRabbit's first review raised cleanup retry and cancellation findings; both were addressed. Its second review identified webhook deduplication guidance and clip-duration precision; both were addressed and the compatibility tests rerun. Final verification results are recorded below.


### Verification

- `swift test --enable-code-coverage`: **192 tests passed, zero failures**, on Apple Swift 6.4 / macOS.
- After the final clip-duration precision change, all 14 compatibility regression tests passed again.
- DocC generation for `TwitchKit`: **passed without documentation warnings**.
- `git diff --check`: passed.
- The smoke-test executable compiles with the corrected Power-up fields. Authenticated smoke execution was not performed.

## Historical audit — July 2026

> The report below is historical. Its claim that pinned-chat endpoints do not exist is incorrect and is superseded by the current audit above.


**Date:** 2026-07-09 · **Commit audited:** `35d7b63` · **Scope:** all of `Sources/`, `Tests/`, `Examples/`, package manifest, CI, and docs (~10,300 lines of Swift).

> **Status update (2026-07-09):** the P0, P1, and P2 items below have been fixed on this branch — see CHANGELOG.md's Unreleased section for the full list. Findings text is left as originally written for the record. Still open, deliberately deferred pending a local `swift test` run (this environment has no Swift toolchain): the Swift Testing migration, the `Date.ISO8601FormatStyle` swap (§4.2 — must not regress nanosecond-timestamp parsing), `connect()` cancellation-responsiveness (§2), the model-fidelity items in §2 (EventSub payload variants, missing broadcaster identity on follow/subscribe events, memberwise initializers), and a lint config.

**Method:** full manual read of the core subsystems (auth/token lifecycle, HTTP layer, EventSub WebSocket client, webhook verifier), plus a systematic sweep of all ~25 Helix endpoint extension files, the model layer, and the test suite, with endpoint behavior cross-checked against the Twitch Helix API reference. Findings that depend on Twitch server behavior that could not be re-verified live are tagged **(unverified-external)**. The audit was static — the sandbox has no Swift toolchain, so nothing here was compiled or executed.

---

## Executive summary

TwitchKit is a genuinely well-built pre-1.0 package. It is fully in Swift 6 language mode with strict concurrency, uses actors and `AsyncStream` idiomatically, has ~4,000 lines of tests that assert real behavior, ships CI + DocC + a Swift Package Index manifest, and shows real care in hard places (constant-time webhook HMAC verification, connect-coalescing, forward-compatible string enums, known Twitch JSON quirks handled and documented in-code).

The problems cluster in four areas:

1. **Token lifecycle** — a failed refresh logs the user out even on transient network errors, refreshes aren't coalesced (races Twitch's rotating refresh tokens), and expiry is never tracked.
2. **EventSub client lifetime & timeout** — long-running tasks retain the actor so it can never deallocate; the connect timeout can hang far past its deadline.
3. **Helix endpoint fidelity** — a handful of endpoints can never work as written (Schedule envelope, redemption status casing, extension live-channels pagination), and one group of chat-pin endpoints doesn't exist in the Twitch API at all.
4. **Decode fragility** — several EventSub/Helix models will throw (or silently degrade) on documented payload variants.

None of these are architectural; all are fixable in place.

---

## 1. High-severity findings

### 1.1 Failed token refresh destroys the session on transient errors
`Sources/TwitchKit/Auth/TwitchTokenProvider.swift:59-66`

```swift
} catch {
    try await logout()   // deletes the stored token on ANY error
    throw error
}
```

`refreshIfNeeded()` deletes the stored token on **any** refresh failure — including timeouts, airplane mode, or a flaky proxy. A refresh attempted while offline permanently signs the user out even though the refresh token is still valid. Because `HelixClient` calls `refreshIfNeeded()` on every 401 (`HelixClient.swift:176-186`), one unlucky network blip during a 401-retry wipes credentials.

**Fix:** only logout on definitive OAuth rejections (`invalid_grant` / HTTP 400–401 from the token endpoint, i.e. `HelixError.oauth`); rethrow transport errors without touching the store.

### 1.2 Concurrent token refreshes are not coalesced
`Sources/TwitchKit/Auth/TwitchTokenProvider.swift:52-67`

Actors are reentrant: when several Helix requests hit 401 concurrently, each calls `refreshIfNeeded()`, the actor suspends at `await oauthClient.refreshAccessToken(...)`, and multiple refresh requests race using the **same** refresh token. Twitch rotates refresh tokens for public clients, so the second request can fail with `invalid_grant` — which, combined with 1.1, logs the user out. The repo already solved this exact problem for `EventSubClient.connect()` (in-flight task coalescing, `EventSubClient.swift:101-133`); the same pattern belongs here.

### 1.3 Token expiry is never tracked
`Sources/TwitchKit/Auth/TwitchAuth.swift:97-117`, `TwitchTokenProvider.swift`

`OAuthToken` stores `expiresIn` (a relative duration) but nothing records *when* the token was obtained. There is no `expiresAt`, so:
- `accessToken()` happily returns expired tokens; every expiry costs a failed request + 401 retry round-trip.
- A token loaded from the Keychain after app relaunch has a meaningless `expiresIn`.
- Nothing performs the hourly `/validate` call Twitch requires for user access tokens (`validateToken()` exists but nothing schedules it, and `validateAccessToken` returns only a `Bool`, discarding the scopes/user_id/expires_in payload callers need).

**Fix:** stamp `obtainedAt` on save, expose `expiresAt`, refresh proactively (e.g. within 60s of expiry) inside `accessToken()`.

### 1.4 EventSubClient can never deallocate once started
`Sources/TwitchKit/EventSub/EventSubClient.swift:158-164` (path monitor), `:310-323` (receive loop), `:401-404` (keepalive)

Each long-running task does `[weak self]` followed by a single `guard let self` and then holds the **strong** reference for the entire `while`/`for await` loop:

```swift
pathMonitorTask = Task { [weak self] in
    guard let self else { return }
    for await status in self.pathMonitor.pathUpdates { ... }   // strong self for the life of the stream
}
```

The path-monitor stream never finishes until `cancel()`, and the receive loop runs until socket error — so once `connect()` has been called, these tasks retain the actor indefinitely. The careful cleanup in `deinit` (`:63-75`) is unreachable in practice: dropping the last external reference leaks the actor, the WebSocket, and the `NWPathMonitor` unless the app remembers to call `disconnect()`.

**Fix:** keep `self` weak and re-acquire per iteration (`while let self = weakSelf.value` pattern / `guard let self` inside the loop body), or make the loops exit via cancellation triggered by something that doesn't require deinit.

### 1.5 `connect(timeout:)` can hang far beyond its deadline
`Sources/TwitchKit/EventSub/EventSubClient.swift:205-217`, `:500-517`

`waitForWelcome()` suspends on a `CheckedContinuation` that is **not cancellation-aware**. In the timeout race:

```swift
try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { try await self.waitForWelcome() }      // parks on a continuation
    group.addTask { try await Task.sleep(for: timeout); throw ... }
    defer { group.cancelAll() }
    try await group.next()
}
```

when the timeout child throws first, the group cancels the welcome child — but cancelling a task parked on a plain `CheckedContinuation` does nothing, and a task group **must await all children before returning**. The group therefore blocks until something else resumes the continuation (a late welcome, a socket error, `disconnect()`, or a superseding attempt). Against a TCP-connected-but-silent server, `connect(timeout: .seconds(15))` blocks for however long URLSession takes to give up, not 15 seconds. The same pattern exists in `waitForWelcome(timeout:)` used by `reconnectTo` (`:507-517`).

**Fix:** wrap the continuation in `withTaskCancellationHandler` and resume it (throwing `CancellationError`) from the handler.

### 1.6 Channel-points redemption status uses the wrong casing → endpoints 400
`Sources/TwitchKit/Models/TwitchStringEnum.swift:226-257`; used in `HelixClient+ChannelPoints.swift:74,101`

`ChannelPointsRedemptionStatus` raw values are lowercase (`"fulfilled"`, …) but Twitch requires and returns **uppercase** (`FULFILLED`, `UNFULFILLED`, `CANCELED`) for both the `status` query parameter of *Get Custom Reward Redemption* and the PATCH body of *Update Redemption Status*. As written:
- `fetchCustomRewardRedemptionsPage(status: .fulfilled)` sends `status=fulfilled` → 400.
- `updateCustomRewardRedemptionStatus(...)` sends `{"status":"fulfilled"}` → 400.
- Every decoded redemption's status becomes `.unknown("FULFILLED")`, so `== .fulfilled` checks silently fail.

### 1.7 Stream Schedule endpoints can never decode successfully
`Sources/TwitchKit/API/HelixClient+Schedule.swift:29,83,106`

Get/Create/Update Channel Stream Schedule are decoded via `HelixResponse<ChannelStreamSchedule>` whose `data` is `[T]`, but Twitch returns `data` as a single **object** for these endpoints (`{"data": {"segments": [...], "broadcaster_id": ..., "vacation": ...}, "pagination": {}}`). All three methods will throw `HelixError.decodingFailed` on a successful 200 response. **(unverified-external** on the exact envelope, but this matches the published reference examples.**)**

### 1.8 `updateChannelStreamSchedule` is a silent no-op
`Sources/TwitchKit/API/HelixClient+Schedule.swift:60-70`

Vacation settings are sent as a JSON body, but *Update Channel Stream Schedule* takes `is_vacation_enabled` / `vacation_start_time` / `vacation_end_time` / `timezone` as **query parameters**. Twitch ignores the unrecognized body and returns 204 — the call "succeeds" and changes nothing. **(unverified-external)**

### 1.9 Chat-pin API surface does not exist in Helix
`Sources/TwitchKit/API/HelixClient+ChatExtended.swift:143-198`; `HelixClient+Chat.swift:72-109`

`fetchPinnedChatMessage` / `pinChatMessage` / `updatePinnedChatMessage` / `unpinChatMessage` call a `chat/pins` endpoint that is not part of the Helix API — all four will 404. Similarly, *Send Chat Message* has no `pin` body field (documented body: `broadcaster_id`, `sender_id`, `message`, `reply_parent_message_id`, `for_source_only`), so `sendChatMessage(pin: true)` silently does nothing. This block appears to have been written from memory rather than the reference; it should be removed or clearly gated until Twitch ships such an API.

### 1.10 Extension live-channels pagination decodes the wrong type
`Sources/TwitchKit/API/HelixClient+Extensions.swift:60-70`, `:213-216`

*Get Extension Live Channels* returns `pagination` as a plain **string** cursor, but `ExtensionLiveChannelsPage.pagination` is typed as the `Pagination` object. The code already bypasses the standard envelope via `requestRawData` (correctly anticipating the deviation) but then decodes into the wrong shape — any response with a second page throws. **(unverified-external)**

### 1.11 Shield Mode status fails for channels that never used it
`Sources/TwitchKit/API/HelixClient+Moderation.swift:607`

`ShieldModeStatus.lastActivatedAt: Date` is non-optional, but Twitch sends `last_activated_at: ""` when Shield Mode has never been activated; the date strategy throws on empty strings, so `getShieldModeStatus` fails for exactly those channels. The repo already fixed this identical class of bug for `SearchChannel.startedAt` (`HelixClient+Search.swift:111-134`) — the same decode-raw-string-and-map approach is needed here. Related: `AdSchedule.snoozeRefreshAt/nextAdAt/lastAdAt` (`HelixClient+Ads.swift:53-56`) are `Date?`, which protects against null/absent but **not** against present-but-empty `""`, which Twitch documents for offline channels **(unverified-external)**; and `BannedUser.expiresAt` (`HelixClient+Moderation.swift:527`) dodged the same problem by being `String?` — inconsistent with every other timestamp in the library.

---

## 2. Medium-severity findings

### Auth & HTTP layer

- **`HelixError.networkError(String)` discards the underlying error** (`HelixClient.swift:202-207`). Wrapping `error.localizedDescription` means callers can't distinguish offline vs timeout vs TLS failure, and can't implement retry policies. Carry the underlying `Error`/`URLError` in the case payload.
- **Keychain items lack `kSecAttrService`** (`Auth/KeychainStore.swift`). Items are keyed only by `kSecClass` + `kSecAttrAccount`. It works because the account string is namespaced, but it's non-standard, risks collisions with other generic-password items, and precludes access-group/iCloud-sync options. Add `kSecAttrService` (migrating existing items on first read).
- **503 retry is immediate** (`HelixClient.swift:188-195`) — no delay or jitter before the single retry; during a real outage the retry is nearly always wasted. A short randomized backoff (~250–1000 ms) matches Twitch guidance better. 429 responses surface `Retry-After` nicely but there's no opt-in automatic honor-the-header retry.
- **Device-code token exchange sends `scope`, but Twitch's DCF token endpoint documents `scopes`** (`TwitchOAuthClient.swift:232-239`). Works today only if the server ignores the parameter. **(unverified-external)**
- **`isAuthenticated` swallows store errors** (`TwitchTokenProvider.swift:30`): a Keychain read failure reads as "signed out".

### EventSub

- **`attemptReconnect` recurses on failure** (`EventSubClient.swift:495-497`): `catch { await attemptReconnect() }` adds an async frame per failed attempt; live channels retry forever with a 5s cap, so a long outage accumulates unbounded recursion depth. Use a loop.
- **Partial resubscribe can wedge the reconnect loop** (`EventSubClient.swift:556-562`). If `resubscribeAll()` throws midway, the retry re-enters `openConnection` (early-returns — session already up) and then re-creates **all** desired subscriptions, including ones already created on this session; Twitch answers 409 for duplicates, which throws, which retries, indefinitely. Track which subscriptions succeeded, or treat "already exists" as success. Also `desiredSubscriptionsById` accumulates stale record IDs across reconnects. **(unverified-external** on the exact 409 behavior**)**
- **Message dedup cache is wiped on every disconnect** (`handleDisconnect` → `clearSeenMessageIds`). Twitch can redeliver notifications across a reconnect within its replay window; those replays pass through undeduped. The cache is already bounded (4,096) — keep it across reconnects.
- **Default `isLive: { false }` silently parks reconnection after 5 attempts** (`TwitchClient.swift:43` + `ReconnectDecision.swift:40-44`). A default-configured `TwitchClient` stops reconnecting after ~31s of backoff following an outage, with no state that tells the user why (the `.disconnected` state isn't even emitted — it parks silently). At minimum document this loudly; better, make the non-live ladder emit a terminal state, or default to the persistent ladder.
- **`connect()` is not cancellation-responsive** (`EventSubClient.swift:132`): awaiting `attempt.value` does not propagate the caller's cancellation, so a cancelled caller still blocks until welcome/timeout resolves.

### Helix endpoint layer

- **`deleteAllEventSubSubscriptions` skips items** (`HelixClient+EventSub.swift:79-93`): it deletes every item on a page, then follows the pre-deletion cursor; deletions shift the collection, so with >1 page some subscriptions survive a successful "delete all". Re-fetch the first page until empty instead.
- **`updateConduitShards` discards per-shard errors** (`HelixClient+Conduits.swift:60-73`): Twitch returns both `data` (successes) and an `errors` array; only `data` is decoded, so partial failures look like total success.
- **Pagination bound is hard-coded at 1...100** (`HelixQuery.swift:24-29`) but per-endpoint limits differ: Get Chatters allows up to 1,000 (valid values rejected client-side); schedule caps at 25 and redemptions at 50 (invalid values accepted locally, then 400 server-side). The doc comment at `HelixClient+Schedule.swift:11` says "up to 25" while the code permits 100.
- **Input validation is inconsistent**: `fetchUsers`/`fetchGames`/`fetchChannelsInfo` enforce the 100-ID cap, but `fetchEmoteSets` (max 25), `fetchUserChatColors` (100), redemption `ids` (50), `fetchClipDownloads` (10, no empty check), `deleteVideos` (5, no empty check → guaranteed 400), `updateDropsEntitlements` (100), `fetchPollsPage` ids (20), and `fetchStreamsPage` filters (100 each) validate nothing. Endpoints with "exactly one filter" requirements (`fetchClipsPage`, `fetchVideosPage`, `fetchStreamMarkersPage`, `fetchTeams`) can be called with zero or multiple filters and are guaranteed to 400.
- **Extension endpoints silently require a JWT the client can't send** (`HelixClient+Extensions.swift:5-105`): configuration segments, PubSub, secrets, extension chat, and Get Extensions require a signed extension JWT, but `HelixClient` always sends the OAuth bearer token — these methods 401 unconditionally unless the user abuses `TwitchAccessTokenProvider`. Document it or provide a JWT-credential seam.
- **Paged-sequence helpers cover only ~9 of ~24 paginated endpoints.** Clips, videos, moderators, VIPs, banned users, unban requests, blocked terms, moderated channels, redemptions, polls, predictions, drops, user emotes, conduit shards, extension transactions, analytics, and the block list expose only `fetch...Page`, forcing consumers to hand-roll cursor loops the library already abstracts.
- **Deprecated tag endpoints shipped without deprecation** (`HelixClient+DiscoveryUsers.swift:5-22`): `fetchAllStreamTags`/`fetchStreamTags` wrap endpoints that have returned empty data since 2023 and are scheduled for 410. Annotate with `@available(*, deprecated, ...)`.

### Models / EventSub payloads

- **`EventSubUserAuthorization.userLogin/userName` are non-optional** (`EventSubEvents.swift:974-975`) but `user.authorization.revoke` sends null when the user no longer exists — the event silently degrades to `.known` instead of `.userAuthorizationRevoke`.
- **`EventSubChannelPointsAutomaticRewardRedemption` mismatches both payload versions** (`EventSubEvents.swift:311-329`): v1's `unlocked_emote {id,name}` fails `TwitchEmote`'s non-optional `format/scale/themeMode`, and v1's `message {text,emotes}` fails `ChatMessageBody`; on the default v2 subscription the fields are named `channel_points`/`emote`, so `cost` and `unlockedEmote` are silently always nil. **(v2 names unverified-external)**
- **`TwitchFollow` and `TwitchSubscription` omit broadcaster identity** (`Models/TwitchFollow.swift:10-22`, `Models/TwitchSubscription.swift:9-24`): the payloads carry `broadcaster_user_id/login/name`, but the models drop them — with one merged `events` stream serving multiple channels, a consumer cannot tell which channel a follow/sub belongs to.
- **`EventSubUnbanRequest` discards resolution data** (`EventSubEvents.swift:859-868`): shared between `.create` and `.resolve` but has no `status`/`resolution_text`/moderator fields, so resolve events lose their outcome.
- **`TwitchEmote.template` is always nil** (`Models/TwitchEmote.swift:43`): Helix returns `template` as a sibling of `data` in the envelope, which `HelixResponse` drops; `imageURL` only works via the hardcoded fallback CDN string.
- **Batched drop entitlements are unreachable as a typed event** (`EventSubEvents.swift:934-950` + `EventSubMessage.swift:506-512`): the notification envelope reads only `payload.event`, but batched `drop.entitlement.grant` uses `payload.events` — every such event falls back to `.known`. (Webhook/app-token-only anyway, so latent.)

### Tests & tooling

- **The EventSub WebSocket client has no socket seam** — `handleMessage` (welcome/keepalive/reconnect/revocation/dedup), the keepalive watchdog, `session_reconnect` socket swap, and `resubscribeAll` are all untested (the tests themselves note this, `EventSubConnectionStateTests.swift:8`). This is the most race-sensitive code in the package and its headline reliability features are unverified. Injecting the WebSocket (protocol over `URLSessionWebSocketTask`) is the single highest-leverage testability fix.
- **`refreshIfNeeded`'s destructive logout path and `validateToken` are untested** (`TwitchTokenProvider.swift:59-81`), as are `twitchFormEncoded` (secrets containing `&`/`+` would be mangled undetected), the Keychain store, the 403/404/409/422 error mapping, device-code expiry, and the 401-retry-also-401s path.
- **README Quick-Start EventSub sample does not compile** (`README.md:142-159`): the `switch` covers 5 of ~90 `EventSubEvent` cases with no `default:`. The first thing a new user copy-pastes fails.
- **CI runs `swift test` only** (`.github/workflows/ci.yml`): no lint step, no code coverage, no DocC build check (SPI doc builds can break silently). No `.swiftlint.yml`/`.swift-format` anywhere.

---

## 3. Security review

Overall solid. Notable points:

| Area | Assessment |
|---|---|
| Webhook signature verification | **Good.** Constant-time comparison, careful hex/prefix parsing, correct HMAC construction (`EventSubWebhookVerifier.swift`). |
| Replay protection | **Gap.** No timestamp-freshness helper; Twitch recommends rejecting messages older than 10 minutes. Add an `isValid(..., maxAge:)` overload and document it. |
| Token storage | Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and data-protection keychain on macOS — good defaults. Missing `kSecAttrService` (see §2). |
| Secrets in logs | Clean — session IDs and endpoints are logged, never tokens or secrets. Decode-failure logs print up to 500 bytes of response JSON (`HelixClient.swift:233`), which for Helix responses is benign but worth keeping in mind. |
| Client secret on device | The API makes it easy to pass `clientSecret` into a shipped app. The library rightly supports the device-code flow for public clients; docs should explicitly steer mobile apps there and away from embedding secrets. |
| Form encoding | `twitchFormEncoded` correctly escapes `&`, `+`, `=`; silently drops empty-valued fields (intentional, but untested). |
| Auth URL construction | `state`/`nonce` supported but not generated or verified by the library; callers must do CSRF-state validation themselves — worth a doc note. |

---

## 4. "Latest Swift standards" assessment

What's already modern:

- `swift-tools-version: 6.0`, Swift 6 language mode on all source targets — strict concurrency is on and the codebase is warning-clean by construction (actors, `Sendable` value types everywhere, only one `@unchecked Sendable`, correctly lock-guarded).
- `async`/`await` throughout; `AsyncStream.makeStream`; `Duration`/`ContinuousClock` for time; `AsyncSequence` pagination.
- DocC catalog + swift-docc-plugin + `.spi.yml`; platforms (`iOS 16 / macOS 13`) exactly match the APIs used.

Recommended modernization (roughly in order of value):

1. **Migrate tests to Swift Testing** (`@Test`, `#expect`, parameterized tests). The suite is XCTest end-to-end; the big table-style tests in `APIDesignTests`/`HTTPClientTests` collapse dramatically under parameterized `@Test(arguments:)`. Mechanical, not urgent.
2. **Replace the `NSLock`-guarded `ISO8601DateFormatter` cache with `Date.ISO8601FormatStyle`** (`HelixQuery.swift:382-406`) — `FormatStyle`/`ParseStrategy` are `Sendable`, faster, and delete the lock and the `@unchecked Sendable`.
3. **Adopt `withTaskCancellationHandler`** around the EventSub welcome continuation and `connect()`'s `attempt.value` await (fixes 1.5 and the cancellation-responsiveness gap — modern structured-concurrency hygiene, not just style).
4. **Consider typed throws** (`throws(HelixError)`) on the Helix surface — Swift 6 supports it and the library already funnels everything into `HelixError`; would make the error contract compiler-checked. Optional; ecosystem adoption is still young.
5. **Enable `ExistentialAny` and other upcoming features** in `swiftSettings` — the code already writes `any` consistently; the flag makes it enforced. Add `swiftSettings` to the test target for symmetry.
6. **`Duration`-based conveniences** where the API traffics in second-counts (`startCommercial(length:)`, ban durations, poll durations), keeping the raw-Int versions for parity with the wire format.
7. Minor API-guideline consistency: three coexisting argument-label conventions (`forBroadcasterID broadcasterId:` vs `broadcasterID:` vs `broadcasterId:` — `HelixClient+Chat.swift:77` is the outlier); acronym casing (`userId` properties vs `userID` parameters); `TwitchSubscription` (an event) vs `EventSubSubscription` (a request) is confusable; models lack public memberwise initializers, which hurts consumers' tests/previews/fixtures.

---

## 5. What's notably good

- **Connect-coalescing** in `EventSubClient.connect()` is correct, deliberate, and unusually well-commented (owner-lifetime task so a cancelled initiator doesn't tear down the handshake for coalesced waiters).
- **The nil-token non-latching logic** in `TwitchTokenProvider.currentToken()` (transient Keychain misses during prewarming don't poison the provider) shows real production experience, and the comment explains *why*.
- **`ReconnectDecision` extracted as a pure function** — the backoff ladder is unit-tested without sockets or sleeps.
- **Forward-compatible enums**: every string enum decoded from Twitch uses a non-throwing `.unknown(String)` fallback — zero closed enums that could break on new server values.
- **Graceful EventSub degradation**: undecodable or unknown notifications become `.known`/`.unknown` with raw payload and detailed logged diagnostics instead of being dropped.
- **Test quality**: `MockHTTPClient` is a proper actor-based transport double; tests assert exact URLs, methods, headers, bodies, error taxonomy, 401-refresh-retry, 503 retry opt-out, cancellation preservation, cursor threading, and real Twitch JSON quirks (nanosecond timestamps, `tags: null`, `url_1x` snake-case).
- **SmokeTest harness**: all credentials from env vars, destructive operations double-gated behind explicit env flags.

---

## 6. Prioritized recommendations

**P0 — correctness (small diffs, high impact)**
1. Stop logging out on transient refresh failures; coalesce concurrent refreshes (§1.1, §1.2).
2. Fix `ChannelPointsRedemptionStatus` casing (§1.6).
3. Fix Schedule envelope decoding + move vacation settings to query params (§1.7, §1.8).
4. Remove (or gate) the nonexistent chat-pin API surface and the `pin` field on send-chat (§1.9).
5. Fix the EventSub task retain pattern so `deinit` is reachable (§1.4) and make the welcome wait cancellation-aware (§1.5).
6. Make `ShieldModeStatus.lastActivatedAt` (and the Ads dates) tolerant of `""` (§1.11).

**P1 — robustness**
7. Track token expiry; refresh proactively (§1.3).
8. Preserve the underlying error in `networkError`; add `kSecAttrService`; fix `deleteAllEventSubSubscriptions` cursor bug; surface conduit-shard errors; fix `ExtensionLiveChannelsPage.pagination`.
9. Fix resubscribe-partial-failure wedging; keep the dedup cache across reconnects; convert `attemptReconnect` recursion to a loop; rethink the `isLive: { false }` default (§2).
10. Fix the non-compiling README sample.

**P2 — testability & polish**
11. Inject the WebSocket (socket seam) and test `handleMessage`/keepalive/reconnect/resubscribe paths.
12. Add per-endpoint `first`/count validation or drop client-side caps entirely (be consistent).
13. Extend `HelixPagedSequence` coverage to all paginated endpoints.
14. Add a webhook timestamp-freshness check; migrate to Swift Testing; add lint + coverage + DocC build to CI; adopt `Date.ISO8601FormatStyle`.
