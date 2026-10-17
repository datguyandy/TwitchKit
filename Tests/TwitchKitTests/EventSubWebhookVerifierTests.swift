import Foundation
import XCTest
@testable import TwitchKit

final class EventSubWebhookVerifierTests: XCTestCase {
    static let secret = "webhook-secret-123"
    static let signature = "sha256=f89fc14bd80522e9bcdc3171460cd0cf4b724944f4c05df48fafc288b4def211"

    func test_eventSubWebhookVerifierValidatesSignature() throws {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)
        let verifier = try EventSubWebhookVerifier(secret: Self.secret)

        XCTAssertTrue(
            verifier.isSignatureValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: Self.signature
            )
        )
        XCTAssertFalse(
            verifier.isSignatureValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=invalid"
            )
        )
    }

    /// The four-argument `isValid` spelling used to resolve to a
    /// signature-only overload and accepted a replayed 2024 message.
    func test_defaultSpelledIsValidRejectsStaleTimestamp() throws {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)
        let verifier = try EventSubWebhookVerifier(secret: Self.secret)

        XCTAssertFalse(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: Self.signature
            )
        )
        XCTAssertFalse(
            EventSubWebhookVerifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: Self.signature,
                secret: Self.secret
            )
        )
    }

    func test_verifierRejectsSecretsTwitchWouldRefuse() throws {
        XCTAssertThrowsError(try EventSubWebhookVerifier(secret: "short")) { error in
            XCTAssertEqual(error as? EventSubWebhookSecretError, .invalidLength(5))
        }
        XCTAssertThrowsError(try EventSubWebhookVerifier(secret: String(repeating: "a", count: 101))) { error in
            XCTAssertEqual(error as? EventSubWebhookSecretError, .invalidLength(101))
        }
        XCTAssertThrowsError(try EventSubWebhookVerifier(secret: "sécret-sécret")) { error in
            XCTAssertEqual(error as? EventSubWebhookSecretError, .nonASCII)
        }
        XCTAssertNoThrow(try EventSubWebhookVerifier(secret: String(repeating: "a", count: 10)))
        XCTAssertNoThrow(try EventSubWebhookVerifier(secret: String(repeating: "a", count: 100)))
    }

    func test_verifierRedactsSecret() throws {
        let verifier = try EventSubWebhookVerifier(secret: Self.secret)
        var dumped = ""
        dump(verifier, to: &dumped)

        for output in [String(describing: verifier), String(reflecting: verifier), "\(verifier)", dumped] {
            XCTAssertFalse(output.contains(Self.secret), output)
        }
    }

    func test_eventSubWebhookVerifierExtractsChallenge() throws {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)

        let challenge = try EventSubWebhookVerifier.challenge(from: body)

        XCTAssertEqual(challenge, "abc123")
    }

    func test_eventSubWebhookVerifierAcceptsFreshTimestamp() {
        // 2024-01-01T00:00:00Z
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(60)
            )
        )
        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00.500Z",
                now: sent.addingTimeInterval(60)
            )
        )
        // Exactly at the 10-minute boundary is still fresh.
        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(600)
            )
        )
    }

    func test_eventSubWebhookVerifierRejectsStaleTimestamp() {
        // 2024-01-01T00:00:00Z, evaluated 11 minutes later.
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        XCTAssertFalse(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(660)
            )
        )
    }

    func test_eventSubWebhookVerifierRejectsUnparseableTimestamp() {
        XCTAssertFalse(EventSubWebhookVerifier.isTimestampFresh("not-a-date", now: .now))
        XCTAssertFalse(EventSubWebhookVerifier.isTimestampFresh("", now: .now))
    }

    func test_eventSubWebhookVerifierRejectsFarFutureTimestamp() {
        // 2024-01-01T00:00:00Z
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        // 6 minutes ahead of "now" exceeds the 5-minute forward skew allowance.
        XCTAssertFalse(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(-360)
            )
        )
        // 1 minute ahead of "now" is tolerated as clock skew.
        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(-60)
            )
        )
    }

    func test_eventSubWebhookVerifierValidatesSignatureAndFreshness() {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)
        let verifier = try! EventSubWebhookVerifier(secret: Self.secret)
        // 2024-01-01T00:00:00Z, matching the timestamp signed below.
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        // Valid signature and a fresh timestamp passes.
        XCTAssertTrue(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: Self.signature,
                now: sent.addingTimeInterval(60)
            )
        )
        // A valid signature does not save a stale (replayed) message.
        XCTAssertFalse(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: Self.signature,
                now: sent.addingTimeInterval(660)
            )
        )
        // A fresh timestamp does not save an invalid signature.
        XCTAssertFalse(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=invalid",
                now: sent.addingTimeInterval(60)
            )
        )
        // The static overload applies the same freshness check.
        XCTAssertFalse(
            EventSubWebhookVerifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: Self.signature,
                secret: Self.secret,
                now: sent.addingTimeInterval(660)
            )
        )
    }
}
