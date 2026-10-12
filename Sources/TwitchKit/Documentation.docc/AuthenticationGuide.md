# Authentication

Use ``TwitchKit/TwitchAuth`` to build Twitch authorization URLs, exchange authorization codes, refresh tokens, validate tokens, revoke tokens, and run the device code flow.

## Authorization Code Flow

Authorization code flow is the right default for apps that can send the user through Twitch login and receive a redirect URI.

```swift
let auth = TwitchAuth(
    clientID: "<#Client ID#>",
    clientSecret: "<#Client Secret#>",
    redirectURI: "myapp://oauth/twitch"
)

let authorizationURL = auth.authorizationCodeURL(
    scopes: [.userReadChat, .userWriteChat],
    state: "<#CSRF Token#>"
)

try await auth.authenticate(
    withAuthorizationCode: "<#Code#>"
)
```

## Device Code Flow

Device code flow is useful for command-line tools, TV apps, and other clients where a browser redirect is awkward.

```swift
let authorization = try await auth.startDeviceCodeFlow(
    scopes: [.userReadChat]
)

print(authorization.verificationURI)
let token = try await auth.pollDeviceCode(authorization)
```

`pollDeviceCode(_:)` uses Twitch's returned polling interval, waits through `authorization_pending`, handles `slow_down`, and stops when the device code expires. Use `exchangeDeviceCode(deviceCode:scopes:)` when you intentionally want one token request instead of a polling loop. OAuth error bodies are surfaced as ``TwitchKit/HelixError/oauth(_:)`` so apps can inspect the Twitch error code and message.

## Token Storage

TwitchKit can store tokens through ``TwitchKit/TwitchTokenStore``. Apps that already have secure credential storage or a backend token exchange service can keep ownership of token persistence and pass access tokens into ``TwitchKit/TwitchClient`` with ``TwitchKit/InMemoryTokenStore`` or a custom store.

## Signing Out

``TwitchKit/TwitchAuth/logout(revokingToken:)`` deletes the stored token, then revokes it on Twitch so it stops working everywhere:

```swift
try await twitch.auth.logout()
```

The token is removed locally first, so signing out works offline. Revocation is best effort: if Twitch can't be reached, the failure is logged and the token stays valid until it expires. Call ``TwitchKit/TwitchOAuthClient/revokeToken(_:)`` directly when you need to know revocation succeeded, or pass `revokingToken: false` to only forget the token locally.

## Common Scopes

Request only the scopes your app needs. Twitch may reject or restrict applications that ask for broad permissions without a clear product reason.

| Use case | Typical scopes |
| --- | --- |
| Read authenticated user email | `.userReadEmail` |
| Read chat | `.userReadChat` |
| Send chat messages | `.userWriteChat` |
| Read current chatters | `.moderatorReadChatters` |
| Update channel title/category | `.channelManageBroadcast` |
| Manage channel points redemptions | `.channelManageRedemptions` |
| Moderate chat | `.moderatorManageBannedUsers`, `.moderatorManageChatMessages` |
| Create polls or predictions | `.channelManagePolls`, `.channelManagePredictions` |

Exact scopes depend on the endpoint and the authenticated user's relationship to the broadcaster. Use ``TwitchKit/TwitchScope`` for known Twitch scope strings and raw-scope overloads when Twitch adds a new scope before TwitchKit has been updated.
