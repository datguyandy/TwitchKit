import CryptoKit
import Foundation
import XCTest
@testable import TwitchKit

/// Webhook requests decode into typed events with Twitch's metadata, after
/// the signature and timestamp are checked.
final class EventSubWebhookMessageTests: XCTestCase {
    private static let secret = "s3cr3t-webhook-secret"
    private static let timestamp = "2024-01-01T00:00:00.634234626Z"
    // A minute after `timestamp`, so freshness checks pass.
    private static let now = Date(timeIntervalSince1970: 1_704_067_260)

    private static let streamOnlineBody = """
    {
      "subscription": {
        "id": "f1c2a387-161a-49f9-a165-0f21d7a4e1c4",
        "status": "enabled",
        "type": "stream.online",
        "version": "1",
        "condition": { "broadcaster_user_id": "1337" },
        "transport": { "method": "webhook", "callback": "https://example.com/webhooks/callback" },
        "created_at": "2019-11-16T10:11:12.634234626Z",
        "cost": 0
      },
      "event": {
        "id": "9001",
        "broadcaster_user_id": "1337",
        "broadcaster_user_login": "cool_user",
        "broadcaster_user_name": "Cool_User",
        "type": "live",
        "started_at": "2020-10-11T10:11:12.123Z"
      }
    }
    """

    private static let verificationBody = """
    {
      "challenge": "pogchamp-kappa-360noscope-vohiyo",
      "subscription": {
        "id": "f1c2a387-161a-49f9-a165-0f21d7a4e1c4",
        "status": "webhook_callback_verification_pending",
        "type": "channel.follow",
        "version": "2",
        "cost": 1,
        "condition": { "broadcaster_user_id": "12826", "moderator_user_id": "12826" },
        "transport": { "method": "webhook", "callback": "https://example.com/webhooks/callback" },
        "created_at": "2019-11-16T10:11:12.634234626Z"
      }
    }
    """

    private static let revocationBody = """
    {
      "subscription": {
        "id": "f1c2a387-161a-49f9-a165-0f21d7a4e1c4",
        "status": "authorization_revoked",
        "type": "channel.follow",
        "version": "2",
        "cost": 1,
        "condition": { "broadcaster_user_id": "12826", "moderator_user_id": "12826" },
        "transport": { "method": "webhook", "callback": "https://example.com/webhooks/callback" },
        "created_at": "2019-11-16T10:11:12.634234626Z"
      }
    }
    """

    private static func signature(messageID: String, timestamp: String, body: Data) -> String {
        var message = Data((messageID + timestamp).utf8)
        message.append(body)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: Data(secret.utf8)))
        return "sha256=" + mac.map { String(format: "%02x", $0) }.joined()
    }

    private static func headers(
        type: String,
        body: Data,
        messageID: String = "befa7b53-d79d-478f-86b9-120f112b044e"
    ) -> [String: String] {
        let timestamp = Self.timestamp
        return [
            "Twitch-Eventsub-Message-Id": messageID,
            "Twitch-Eventsub-Message-Retry": "0",
            "Twitch-Eventsub-Message-Type": type,
            "Twitch-Eventsub-Message-Signature": signature(messageID: messageID, timestamp: timestamp, body: body),
            "Twitch-Eventsub-Message-Timestamp": timestamp,
            "Twitch-Eventsub-Subscription-Type": "stream.online",
            "Twitch-Eventsub-Subscription-Version": "1",
        ]
    }

    private let verifier = try! EventSubWebhookVerifier(secret: EventSubWebhookMessageTests.secret)

    func testNotificationDecodesTheTypedEventAndMetadata() throws {
        let body = Data(Self.streamOnlineBody.utf8)

        let message = try verifier.message(headers: Self.headers(type: "notification", body: body), body: body, now: Self.now)

        guard case .notification(let notification) = message else {
            return XCTFail("Expected a notification, got \(message)")
        }
        guard case .streamOnline(let online) = notification.event else {
            return XCTFail("Expected .streamOnline, got \(notification.event)")
        }
        XCTAssertEqual(online.broadcasterUserLogin, "cool_user")
        XCTAssertEqual(online.type, .live)

        let metadata = try XCTUnwrap(notification.metadata)
        XCTAssertEqual(metadata.messageID, "befa7b53-d79d-478f-86b9-120f112b044e")
        XCTAssertEqual(metadata.messageTimestamp, TwitchDateParser.date(from: Self.timestamp))
        XCTAssertEqual(metadata.subscriptionID, "f1c2a387-161a-49f9-a165-0f21d7a4e1c4")
        XCTAssertEqual(metadata.subscriptionType, "stream.online")
        XCTAssertEqual(metadata.subscriptionVersion, "1")
        XCTAssertEqual(metadata.condition, ["broadcaster_user_id": "1337"])
    }

    func testVerificationReturnsTheChallenge() throws {
        let body = Data(Self.verificationBody.utf8)

        let message = try verifier.message(
            headers: Self.headers(type: "webhook_callback_verification", body: body),
            body: body,
            now: Self.now
        )

        guard case .verification(let challenge, let metadata) = message else {
            return XCTFail("Expected a verification, got \(message)")
        }
        XCTAssertEqual(challenge, "pogchamp-kappa-360noscope-vohiyo")
        XCTAssertEqual(metadata.subscriptionType, "channel.follow")
    }

    func testRevocationArrivesAsARevocationEvent() throws {
        let body = Data(Self.revocationBody.utf8)

        let message = try verifier.message(headers: Self.headers(type: "revocation", body: body), body: body, now: Self.now)

        guard case .notification(let notification) = message,
              case .revocation(let revocation) = notification.event else {
            return XCTFail("Expected a revocation event, got \(message)")
        }
        XCTAssertEqual(revocation.status, .authorizationRevoked)
        XCTAssertEqual(revocation.condition["broadcaster_user_id"], "12826")
        XCTAssertEqual(notification.metadata?.subscriptionVersion, "2")
    }

    func testHeaderNamesMatchCaseInsensitively() throws {
        let body = Data(Self.streamOnlineBody.utf8)
        var lowercased: [String: String] = [:]
        for (name, value) in Self.headers(type: "notification", body: body) {
            lowercased[name.lowercased()] = value
        }

        let message = try verifier.message(headers: lowercased, body: body, now: Self.now)

        guard case .notification = message else {
            return XCTFail("Expected a notification, got \(message)")
        }
    }

    func testHeaderClosureVariant() throws {
        let body = Data(Self.streamOnlineBody.utf8)
        let headers = Self.headers(type: "notification", body: body)

        let message = try verifier.message(body: body, now: Self.now) { headers[$0] }

        guard case .notification = message else {
            return XCTFail("Expected a notification, got \(message)")
        }
    }

    func testTamperedBodyIsRejected() throws {
        let body = Data(Self.streamOnlineBody.utf8)
        let headers = Self.headers(type: "notification", body: body)
        let tampered = Data(Self.streamOnlineBody.replacingOccurrences(of: "cool_user", with: "evil_user").utf8)

        XCTAssertThrowsError(try verifier.message(headers: headers, body: tampered, now: Self.now)) { error in
            XCTAssertEqual(error as? EventSubWebhookError, .invalidSignature)
        }
    }

    func testStaleTimestampIsRejected() throws {
        let body = Data(Self.streamOnlineBody.utf8)
        let headers = Self.headers(type: "notification", body: body)
        let anHourLater = Self.now.addingTimeInterval(3_600)

        XCTAssertThrowsError(try verifier.message(headers: headers, body: body, now: anHourLater)) { error in
            XCTAssertEqual(error as? EventSubWebhookError, .invalidSignature)
        }
    }

    func testMissingSignatureIsRejected() throws {
        let body = Data(Self.streamOnlineBody.utf8)
        var headers = Self.headers(type: "notification", body: body)
        headers["Twitch-Eventsub-Message-Signature"] = nil

        XCTAssertThrowsError(try verifier.message(headers: headers, body: body, now: Self.now)) { error in
            XCTAssertEqual(error as? EventSubWebhookError, .invalidSignature)
        }
    }

    func testUnverifiedDecodingReportsMissingHeadersAndUnknownTypes() throws {
        let body = Data(Self.streamOnlineBody.utf8)
        var headers = Self.headers(type: "notification", body: body)
        headers["Twitch-Eventsub-Message-Id"] = nil
        XCTAssertThrowsError(try EventSubWebhookMessage(headers: headers, body: body)) { error in
            XCTAssertEqual(error as? EventSubWebhookError, .missingHeader("Twitch-Eventsub-Message-Id"))
        }

        let unknown = Self.headers(type: "something_new", body: body)
        XCTAssertThrowsError(try EventSubWebhookMessage(headers: unknown, body: body)) { error in
            XCTAssertEqual(error as? EventSubWebhookError, .unknownMessageType("something_new"))
        }
    }

    func testUnmodeledEventKeepsItsRawJSON() throws {
        let body = Data("""
        {
          "subscription": {
            "id": "sub-1", "status": "enabled", "type": "channel.brand_new_thing", "version": "1",
            "condition": { "broadcaster_user_id": "1337" }
          },
          "event": { "value": 42 }
        }
        """.utf8)

        let message = try EventSubWebhookMessage(headers: Self.headers(type: "notification", body: body), body: body)

        guard case .notification(let notification) = message,
              case .unknown(let type, let payload) = notification.event else {
            return XCTFail("Expected an unknown event, got \(message)")
        }
        XCTAssertEqual(type, "channel.brand_new_thing")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(object["value"] as? Int, 42)
    }

    func testDecodeEventFromItsJSON() throws {
        let event = EventSubEvent.decode(type: "stream.online", event: Data("""
        {"id":"9001","broadcaster_user_id":"1337","broadcaster_user_login":"cool_user","broadcaster_user_name":"Cool_User","type":"live","started_at":"2020-10-11T10:11:12.123Z"}
        """.utf8))

        guard case .streamOnline(let online) = event else {
            return XCTFail("Expected .streamOnline, got \(event)")
        }
        XCTAssertEqual(online.id, "9001")
    }
}
