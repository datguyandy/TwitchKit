import CryptoKit
import Foundation

/// Why ``EventSubWebhookVerifier/init(secret:)`` or a webhook transport
/// rejected a webhook secret.
///
/// Twitch requires the secret to be an ASCII string 10 to 100 characters long.
public enum EventSubWebhookSecretError: Error, Sendable, Equatable, LocalizedError {
    /// The secret is shorter than 10 or longer than 100 characters. Carries the length.
    case invalidLength(Int)
    /// The secret contains a non-ASCII character.
    case nonASCII

    public var errorDescription: String? {
        switch self {
        case .invalidLength(let length):
            "EventSub webhook secret must be 10–100 ASCII characters; got \(length)"
        case .nonASCII:
            "EventSub webhook secret must contain only ASCII characters"
        }
    }
}

/// Verifies Twitch EventSub webhook signatures and callback verification challenges.
///
/// The secret never appears in `description`, `debugDescription` or
/// `dump(_:)` output.
public struct EventSubWebhookVerifier: Sendable {
    private let secretValue: String

    /// The webhook secret.
    @available(*, deprecated, message: "The verifier no longer exposes its secret. Keep your own copy if you need it.")
    public var secret: String { secretValue }

    /// Creates a verifier for the secret you passed when creating the webhook subscription.
    ///
    /// - Throws: ``EventSubWebhookSecretError`` when the secret isn't 10–100
    ///   ASCII characters, the range Twitch accepts.
    public init(secret: String) throws {
        try Self.validateSecret(secret)
        self.secretValue = secret
    }

    /// Checks that `secret` is a webhook secret Twitch accepts: 10 to 100 ASCII characters.
    ///
    /// - Throws: ``EventSubWebhookSecretError``.
    public static func validateSecret(_ secret: String) throws {
        guard secret.unicodeScalars.allSatisfy(\.isASCII) else {
            throw EventSubWebhookSecretError.nonASCII
        }
        let length = secret.utf8.count
        guard (10...100).contains(length) else {
            throw EventSubWebhookSecretError.invalidLength(length)
        }
    }

    /// Returns `true` when the EventSub webhook request signature matches the request body
    /// **and** the message timestamp is fresh.
    ///
    /// Build `messageID`, `timestamp`, and `signature` from Twitch's
    /// `Twitch-Eventsub-Message-Id`, `Twitch-Eventsub-Message-Timestamp`, and
    /// `Twitch-Eventsub-Message-Signature` headers. Pass the exact raw HTTP body bytes as `body`.
    ///
    /// A captured webhook request carries a signature that stays valid forever, so an attacker
    /// can replay it long after Twitch sent it. Checking freshness alongside the signature
    /// closes that gap; Twitch recommends rejecting messages older than 10 minutes, which is
    /// the default `maxAge`. See ``isTimestampFresh(_:maxAge:now:)`` for the freshness rules.
    /// Use ``isSignatureValid(messageID:timestamp:body:signature:)`` only when you check
    /// freshness yourself.
    public func isValid(
        messageID: String,
        timestamp: String,
        body: Data,
        signature: String,
        maxAge: Duration = .seconds(600),
        now: Date = .now
    ) -> Bool {
        Self.isValid(
            messageID: messageID,
            timestamp: timestamp,
            body: body,
            signature: signature,
            secret: secretValue,
            maxAge: maxAge,
            now: now
        )
    }

    /// Returns `true` when the EventSub webhook request signature matches the request body,
    /// **without** checking that the timestamp is fresh.
    ///
    /// A signature alone doesn't stop a replayed request. Prefer
    /// ``isValid(messageID:timestamp:body:signature:maxAge:now:)``, which also
    /// rejects stale timestamps.
    public func isSignatureValid(messageID: String, timestamp: String, body: Data, signature: String) -> Bool {
        Self.isSignatureValid(messageID: messageID, timestamp: timestamp, body: body, signature: signature, secret: secretValue)
    }

    /// Returns `true` when the EventSub webhook request signature matches the request body,
    /// **without** checking that the timestamp is fresh.
    ///
    /// Prefer ``isValid(messageID:timestamp:body:signature:secret:maxAge:now:)``,
    /// which also rejects stale timestamps.
    public static func isSignatureValid(
        messageID: String,
        timestamp: String,
        body: Data,
        signature: String,
        secret: String
    ) -> Bool {
        var message = Data()
        message.reserveCapacity(messageID.utf8.count + timestamp.utf8.count + body.count)
        message.append(contentsOf: messageID.utf8)
        message.append(contentsOf: timestamp.utf8)
        message.append(body)

        let key = SymmetricKey(data: Data(secret.utf8))
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: message, using: key)
        guard let signatureBytes = signatureBytes(from: signature) else { return false }
        return constantTimeEqual(authenticationCode, signatureBytes)
    }

    /// Returns `true` when the EventSub webhook request signature matches the request body
    /// **and** the message timestamp is fresh.
    ///
    /// A captured webhook request carries a signature that stays valid forever, so an attacker
    /// can replay it long after Twitch sent it. Checking freshness alongside the signature
    /// closes that gap; Twitch recommends rejecting messages older than 10 minutes, which is
    /// the default `maxAge`. See ``isTimestampFresh(_:maxAge:now:)`` for the freshness rules.
    public static func isValid(
        messageID: String,
        timestamp: String,
        body: Data,
        signature: String,
        secret: String,
        maxAge: Duration = .seconds(600),
        now: Date = .now
    ) -> Bool {
        guard isTimestampFresh(timestamp, maxAge: maxAge, now: now) else { return false }
        return isSignatureValid(messageID: messageID, timestamp: timestamp, body: body, signature: signature, secret: secret)
    }

    /// Returns `true` when a `Twitch-Eventsub-Message-Timestamp` header value is recent
    /// enough to process.
    ///
    /// A valid signature alone does not stop replay attacks: a captured request verifies
    /// forever. Twitch therefore recommends rejecting messages whose timestamp is older than
    /// 10 minutes, which is the default `maxAge`. A timestamp is fresh when
    /// `now - timestamp <= maxAge`. Unparseable timestamps are rejected. Timestamps up to
    /// 5 minutes in the future are accepted to tolerate clock skew; anything further in the
    /// future is rejected.
    public static func isTimestampFresh(
        _ timestamp: String,
        maxAge: Duration = .seconds(600),
        now: Date = .now
    ) -> Bool {
        guard let date = TwitchDateParser.date(from: timestamp) else { return false }

        let age = now.timeIntervalSince(date)
        guard age >= -allowedFutureSkew else { return false }

        let maxAgeSeconds = Double(maxAge.components.seconds)
            + Double(maxAge.components.attoseconds) / 1e18
        return age <= maxAgeSeconds
    }

    /// Extracts the challenge string from a webhook callback verification request body.
    public static func challenge(from body: Data) throws -> String? {
        try JSONDecoder.twitch().decode(EventSubWebhookVerification.self, from: body).challenge
    }

    /// Forward clock skew, in seconds, tolerated by ``isTimestampFresh(_:maxAge:now:)``.
    private static let allowedFutureSkew: TimeInterval = 300

    private static func signatureBytes(from signature: String) -> [UInt8]? {
        let prefix = Array("sha256=".utf8)
        let bytes = Array(signature.utf8)
        guard bytes.count == prefix.count + SHA256.byteCount * 2 else { return nil }

        for index in prefix.indices where bytes[index] != prefix[index] {
            return nil
        }

        var result: [UInt8] = []
        result.reserveCapacity(SHA256.byteCount)
        var index = prefix.count
        while index < bytes.count {
            guard let high = hexNibble(bytes[index]),
                  let low = hexNibble(bytes[index + 1]) else { return nil }
            result.append((high << 4) | low)
            index += 2
        }
        return result
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: byte - 48
        case 65...70: byte - 55
        case 97...102: byte - 87
        default: nil
        }
    }

    private static func constantTimeEqual(_ lhs: HMAC<SHA256>.MAC, _ rhs: [UInt8]) -> Bool {
        guard rhs.count == SHA256.byteCount else { return false }

        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

extension EventSubWebhookVerifier: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "EventSubWebhookVerifier(secret: \(redactedPlaceholder))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(self, children: ["secret": redactedPlaceholder], displayStyle: .struct)
    }
}

private struct EventSubWebhookVerification: Decodable {
    let challenge: String?
}
