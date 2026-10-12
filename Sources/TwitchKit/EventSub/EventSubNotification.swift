import Foundation

/// Twitch's metadata for an EventSub message: which message it was, when
/// Twitch sent it, and which subscription delivered it.
public struct EventSubMetadata: Sendable, Equatable {
    /// Twitch's ID for the message. Twitch can deliver a message more than
    /// once (for example a webhook retry), with the same ID.
    public let messageID: String

    /// When Twitch sent the message.
    public let messageTimestamp: Date

    /// The ID of the subscription that delivered the message.
    public let subscriptionID: String

    /// The subscription type, for example `channel.chat.message`.
    public let subscriptionType: String

    /// The subscription version, for example `1`.
    public let subscriptionVersion: String

    /// The subscription's condition, for example
    /// `["broadcaster_user_id": "1234", "user_id": "5678"]`.
    public let condition: [String: String]

    public init(
        messageID: String,
        messageTimestamp: Date,
        subscriptionID: String,
        subscriptionType: String,
        subscriptionVersion: String,
        condition: [String: String]
    ) {
        self.messageID = messageID
        self.messageTimestamp = messageTimestamp
        self.subscriptionID = subscriptionID
        self.subscriptionType = subscriptionType
        self.subscriptionVersion = subscriptionVersion
        self.condition = condition
    }
}

/// An EventSub event with Twitch's metadata for the message that carried it.
///
/// ``EventSubClient/notifications`` yields these for the WebSocket transport,
/// and ``EventSubWebhookMessage/notification(_:)`` carries one for webhooks,
/// so one handler can serve both.
public struct EventSubNotification: Sendable {
    /// The event, including `.revocation` when Twitch revoked a subscription.
    public let event: EventSubEvent

    /// Twitch's metadata for the message. `nil` only for events the client
    /// creates itself, such as ``EventSubEvent/subscriptionFailed(_:_:)``.
    public let metadata: EventSubMetadata?

    public init(event: EventSubEvent, metadata: EventSubMetadata?) {
        self.event = event
        self.metadata = metadata
    }
}

extension EventSubEvent {
    /// Decodes an event from its subscription type and the JSON of its
    /// `event` object, for example one stored earlier or received through a
    /// transport TwitchKit doesn't handle.
    ///
    /// An event that doesn't decode into a model becomes `.known` (for a type
    /// TwitchKit models) or `.unknown`, with the raw JSON.
    public static func decode(type: String, event: Data) -> EventSubEvent {
        decode(type: type, payload: event)
    }
}

/// A request Twitch sent to an EventSub webhook callback.
///
/// Decode it with ``EventSubWebhookVerifier/message(headers:body:maxAge:now:)``,
/// which checks the signature and timestamp first, then respond:
///
/// ```swift
/// switch try verifier.message(headers: request.headers, body: request.body) {
/// case .verification(let challenge, _):
///     return Response(status: 200, contentType: "text/plain", body: challenge)
/// case .notification(let notification):
///     await handle(notification)   // also receives `.revocation` events
///     return Response(status: 204)
/// }
/// ```
public enum EventSubWebhookMessage: Sendable {
    /// Twitch is confirming you own the callback URL. Respond with HTTP 200,
    /// `Content-Type: text/plain`, and `challenge` as the whole body.
    case verification(challenge: String, metadata: EventSubMetadata)

    /// An event, or a revocation (as an ``EventSubEvent/revocation(_:)``
    /// event). Respond with a 2xx status quickly; Twitch retries otherwise,
    /// with the same message ID.
    case notification(EventSubNotification)

    /// Decodes a webhook request without checking its signature.
    ///
    /// Use ``EventSubWebhookVerifier/message(headers:body:maxAge:now:)``
    /// for requests from the network; this initializer is for requests whose
    /// signature you've already checked.
    ///
    /// - Parameters:
    ///   - headers: The request headers. Names match case-insensitively.
    ///   - body: The raw request body.
    public init(headers: [String: String], body: Data) throws {
        try self.init(body: body, header: EventSubWebhookHeaders(headers).value)
    }

    /// Decodes a webhook request without checking its signature, reading
    /// headers through `header`, for server frameworks with their own header
    /// types.
    public init(body: Data, header: (String) -> String?) throws {
        let messageType = try Self.requiredHeader(EventSubWebhookHeaders.messageType, from: header)
        let messageID = try Self.requiredHeader(EventSubWebhookHeaders.messageID, from: header)
        let timestampValue = try Self.requiredHeader(EventSubWebhookHeaders.messageTimestamp, from: header)
        guard let timestamp = TwitchDateParser.date(from: timestampValue) else {
            throw EventSubWebhookError.malformedHeader(EventSubWebhookHeaders.messageTimestamp)
        }

        let decoder = JSONDecoder.twitch()
        let envelope: EventSubWebhookBody
        do {
            envelope = try decoder.decode(EventSubWebhookBody.self, from: body)
        } catch {
            throw EventSubWebhookError.malformedBody(eventSubDecodingErrorDescription(error))
        }

        let subscription = envelope.subscription
        let metadata = EventSubMetadata(
            messageID: messageID,
            messageTimestamp: timestamp,
            subscriptionID: subscription.id,
            subscriptionType: subscription.type,
            subscriptionVersion: subscription.version,
            condition: subscription.condition
        )

        switch messageType {
        case "webhook_callback_verification":
            guard let challenge = envelope.challenge else {
                throw EventSubWebhookError.malformedBody("webhook_callback_verification without a challenge")
            }
            self = .verification(challenge: challenge, metadata: metadata)
        case "notification":
            let event = EventSubEvent.decodeNotification(
                type: subscription.type,
                envelope: body,
                shape: .webhook,
                decoder: decoder
            )
            self = .notification(EventSubNotification(event: event, metadata: metadata))
        case "revocation":
            self = .notification(EventSubNotification(event: .revocation(subscription), metadata: metadata))
        default:
            throw EventSubWebhookError.unknownMessageType(messageType)
        }
    }

    private static func requiredHeader(_ name: String, from header: (String) -> String?) throws -> String {
        guard let value = header(name), !value.isEmpty else {
            throw EventSubWebhookError.missingHeader(name)
        }
        return value
    }
}

/// Why a webhook request couldn't be turned into an ``EventSubWebhookMessage``.
public enum EventSubWebhookError: Error, Sendable, Equatable, LocalizedError {
    /// The signature didn't match the body, or the timestamp was too old.
    /// Respond with HTTP 403 and don't process the request.
    case invalidSignature
    /// A required `Twitch-Eventsub-*` header was missing or empty.
    case missingHeader(String)
    /// A header's value couldn't be parsed.
    case malformedHeader(String)
    /// The body wasn't the JSON Twitch sends.
    case malformedBody(String)
    /// `Twitch-Eventsub-Message-Type` had a value TwitchKit doesn't know.
    case unknownMessageType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSignature: "EventSub webhook signature or timestamp is invalid"
        case .missingHeader(let name): "EventSub webhook request is missing the \(name) header"
        case .malformedHeader(let name): "EventSub webhook request has a malformed \(name) header"
        case .malformedBody(let detail): "EventSub webhook body couldn't be decoded: \(detail)"
        case .unknownMessageType(let type): "Unknown EventSub webhook message type: \(type)"
        }
    }
}

extension EventSubWebhookVerifier {
    /// Checks a webhook request's signature and timestamp, then decodes it.
    ///
    /// Throws ``EventSubWebhookError/invalidSignature`` when the signature
    /// doesn't match the body or the timestamp is older than `maxAge`;
    /// respond with HTTP 403 and don't process the request. Twitch can
    /// deliver a message more than once, so skip message IDs you've already
    /// handled.
    ///
    /// - Parameters:
    ///   - headers: The request headers. Names match case-insensitively.
    ///   - body: The exact raw request body.
    ///   - maxAge: The oldest timestamp to accept. Twitch recommends 10 minutes.
    ///   - now: The current time.
    public func message(
        headers: [String: String],
        body: Data,
        maxAge: Duration = .seconds(600),
        now: Date = .now
    ) throws -> EventSubWebhookMessage {
        try message(body: body, maxAge: maxAge, now: now, header: EventSubWebhookHeaders(headers).value)
    }

    /// Checks a webhook request's signature and timestamp, then decodes it,
    /// reading headers through `header`, for server frameworks with their own
    /// header types.
    public func message(
        body: Data,
        maxAge: Duration = .seconds(600),
        now: Date = .now,
        header: (String) -> String?
    ) throws -> EventSubWebhookMessage {
        guard let messageID = header(EventSubWebhookHeaders.messageID),
              let timestamp = header(EventSubWebhookHeaders.messageTimestamp),
              let signature = header(EventSubWebhookHeaders.messageSignature),
              isValid(messageID: messageID, timestamp: timestamp, body: body, signature: signature, maxAge: maxAge, now: now)
        else {
            throw EventSubWebhookError.invalidSignature
        }
        return try EventSubWebhookMessage(body: body, header: header)
    }
}

/// Case-insensitive access to webhook request headers.
struct EventSubWebhookHeaders {
    static let messageID = "Twitch-Eventsub-Message-Id"
    static let messageType = "Twitch-Eventsub-Message-Type"
    static let messageTimestamp = "Twitch-Eventsub-Message-Timestamp"
    static let messageSignature = "Twitch-Eventsub-Message-Signature"

    private let values: [String: String]

    init(_ headers: [String: String]) {
        var values: [String: String] = [:]
        for (name, value) in headers {
            values[name.lowercased()] = value
        }
        self.values = values
    }

    func value(_ name: String) -> String? {
        values[name.lowercased()]
    }
}

private struct EventSubWebhookBody: Decodable {
    let subscription: EventSubRevocation
    let challenge: String?
}
