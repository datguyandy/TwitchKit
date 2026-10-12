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

## App Access Tokens

Some Helix calls need an app access token instead of a user token, such as creating EventSub webhook or conduit subscriptions and managing conduits. Create the client with your client secret and use ``TwitchKit/TwitchClient/appAPI``:

```swift
let twitch = TwitchClient(clientID: "<#Client ID#>", clientSecret: "<#Client Secret#>")
let conduits = try await twitch.appAPI!.fetchConduits()
```

``TwitchKit/TwitchAppTokenProvider`` behind it requests a token with the client credentials flow on first use, keeps it in memory, requests a new one shortly before it expires or when Twitch rejects it, and shares one request between concurrent callers. You can also use it directly with any `HelixClient`:

```swift
let appTokens = TwitchAppTokenProvider(clientID: "<#Client ID#>", clientSecret: "<#Client Secret#>")
let appAPI = HelixClient(tokenProvider: appTokens, clientID: "<#Client ID#>")
```

The client credentials flow needs your client secret, so use it only where the secret stays private, such as on a server.

## Validating Tokens

Twitch requires apps to validate tokens when they start and hourly after that, and to stop using a token it rejects. ``TwitchKit/TwitchAuth/validations(every:)`` validates now and then every hour for as long as you iterate it, refreshing a rejected token when it can:

```swift
.task {
    for await result in twitch.auth.validations() {
        switch result {
        case .valid(let info):
            print("Signed in as \(info.login ?? "?"), expires \(String(describing: info.expiresAt))")
        case .invalid:
            showSignIn()        // rejected and couldn't be refreshed
        case .signedOut, .failed:
            break               // .failed (offline, outage) is retried next interval
        }
    }
}
```

To validate once, call ``TwitchKit/TwitchAuth/validateToken()``. It returns a ``TwitchKit/TwitchTokenInfo`` with the token's user ID, login, granted scopes and expiry, or `nil` when there's no token. ``TwitchKit/TwitchOAuthClient/validate(_:)`` validates any access token without refreshing it.

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
