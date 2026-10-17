import Foundation

extension HelixClient {
    /// Starts a commercial on the specified channel.
    public func startCommercial(broadcasterID: String, length: Int) async throws -> CommercialStart {
        let response: HelixResponse<CommercialStart> = try await request(
            endpoint: "channels/commercial",
            method: "POST",
            body: try JSONEncoder.twitch().encode(StartCommercialRequest(
                broadcasterId: broadcasterID,
                length: length
            ))
        )
        guard let commercial = response.data.first else { throw HelixError.emptyResponse }
        return commercial
    }

    /// Gets ad schedule information for a broadcaster.
    public func fetchAdSchedule(broadcasterID: String) async throws -> AdSchedule {
        let response: HelixResponse<AdSchedule> = try await request(
            endpoint: "channels/ads",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        guard let schedule = response.data.first else { throw HelixError.emptyResponse }
        return schedule
    }

    /// Snoozes the broadcaster's next scheduled ad.
    public func snoozeNextAd(broadcasterID: String) async throws -> AdSnooze {
        let response: HelixResponse<AdSnooze> = try await request(
            endpoint: "channels/ads/schedule/snooze",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        guard let snooze = response.data.first else { throw HelixError.emptyResponse }
        return snooze
    }
}

private struct StartCommercialRequest: Encodable {
    let broadcasterId: String
    let length: Int
}

public struct CommercialStart: Decodable, Sendable, Equatable {
    public let length: Int
    public let message: String
    public let retryAfter: Int

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        length: Int,
        message: String,
        retryAfter: Int
    ) {
        self.length = length
        self.message = message
        self.retryAfter = retryAfter
    }
}

public struct AdSchedule: Decodable, Sendable, Equatable {
    public let snoozeCount: Int?
    public let snoozeRefreshAt: Date?
    public let nextAdAt: Date?
    public let duration: Int?
    public let lastAdAt: Date?
    public let prerollFreeTime: Int?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        snoozeCount: Int? = nil,
        snoozeRefreshAt: Date? = nil,
        nextAdAt: Date? = nil,
        duration: Int? = nil,
        lastAdAt: Date? = nil,
        prerollFreeTime: Int? = nil
    ) {
        self.snoozeCount = snoozeCount
        self.snoozeRefreshAt = snoozeRefreshAt
        self.nextAdAt = nextAdAt
        self.duration = duration
        self.lastAdAt = lastAdAt
        self.prerollFreeTime = prerollFreeTime
    }

    private enum CodingKeys: String, CodingKey {
        case snoozeCount, snoozeRefreshAt, nextAdAt, duration, lastAdAt, prerollFreeTime
    }

    /// Custom decoding solely for the date fields: Twitch sends `""` — an
    /// empty string, not null — for `snooze_refresh_at`, `next_ad_at`, and
    /// `last_ad_at` when the channel is offline or has never run an ad. The
    /// keys are present, so `Date?` + the date strategy would try to parse
    /// "" and throw. Decode the raw strings and map non-parsing values
    /// (incl. empty) to nil instead.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snoozeCount = try container.decodeIfPresent(Int.self, forKey: .snoozeCount)
        snoozeRefreshAt = try container.decodeIfPresent(String.self, forKey: .snoozeRefreshAt)
            .flatMap(TwitchDateParser.date(from:))
        nextAdAt = try container.decodeIfPresent(String.self, forKey: .nextAdAt)
            .flatMap(TwitchDateParser.date(from:))
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        lastAdAt = try container.decodeIfPresent(String.self, forKey: .lastAdAt)
            .flatMap(TwitchDateParser.date(from:))
        prerollFreeTime = try container.decodeIfPresent(Int.self, forKey: .prerollFreeTime)
    }
}

public struct AdSnooze: Decodable, Sendable, Equatable {
    public let snoozeCount: Int
    public let snoozeRefreshAt: Date?
    public let nextAdAt: Date?

    /// Creates a value directly, for example in tests or SwiftUI previews.
    public init(
        snoozeCount: Int,
        snoozeRefreshAt: Date? = nil,
        nextAdAt: Date? = nil
    ) {
        self.snoozeCount = snoozeCount
        self.snoozeRefreshAt = snoozeRefreshAt
        self.nextAdAt = nextAdAt
    }

    enum CodingKeys: String, CodingKey {
        case snoozeCount
        case snoozeRefreshAt
        case nextAdAt
    }

    // Same Twitch quirk `AdSchedule` tolerates: date fields can arrive as
    // empty strings, which must not fail the whole decode.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snoozeCount = try container.decode(Int.self, forKey: .snoozeCount)
        snoozeRefreshAt = try container.decodeIfPresent(String.self, forKey: .snoozeRefreshAt)
            .flatMap(TwitchDateParser.date(from:))
        nextAdAt = try container.decodeIfPresent(String.self, forKey: .nextAdAt)
            .flatMap(TwitchDateParser.date(from:))
    }
}
