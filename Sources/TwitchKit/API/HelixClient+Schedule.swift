import Foundation

extension HelixClient {
    /// Gets one page of a broadcaster's stream schedule.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segmentIDs: Optional schedule segment IDs.
    ///   - startTime: Optional lower bound for returned segments.
    ///   - utcOffset: Optional offset such as `"-05:00"`.
    ///   - first: Optional page size. Twitch currently allows up to 25 for schedules.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A schedule page.
    /// - SeeAlso: [Get Channel Stream Schedule](https://dev.twitch.tv/docs/api/reference/#get-channel-stream-schedule)
    public func fetchChannelStreamSchedulePage(
        broadcasterID broadcasterId: String,
        segmentIDs: [String] = [],
        startTime: Date? = nil,
        utcOffset: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> ChannelStreamSchedulePage {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        queryItems += HelixQuery.items("id", values: segmentIDs)
        HelixQuery.append(startTime.map { URLQueryItem(name: "start_time", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        HelixQuery.append(HelixQuery.item("utc_offset", utcOffset), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, validRange: 1...25)

        let data = try await requestRawData(
            endpoint: "schedule",
            queryItems: queryItems
        )
        let envelope = try decodeScheduleEnvelope(from: data)
        return ChannelStreamSchedulePage(
            schedule: envelope.data,
            pagination: envelope.pagination,
            metadata: nil
        )
    }

    /// Gets a broadcaster's schedule as an iCalendar string.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Raw iCalendar text.
    /// - SeeAlso: [Get Channel iCalendar](https://dev.twitch.tv/docs/api/reference/#get-channel-icalendar)
    public func fetchChannelICalendar(broadcasterID broadcasterId: String) async throws -> String {
        let data = try await requestRawData(
            endpoint: "schedule/icalendar",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Updates a broadcaster's stream schedule settings.
    ///
    /// Twitch accepts these settings as query parameters, not a request body,
    /// so the provided fields are serialized into the request URL.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - settings: Schedule settings to update.
    /// - SeeAlso: [Update Channel Stream Schedule](https://dev.twitch.tv/docs/api/reference/#update-channel-stream-schedule)
    public func updateChannelStreamSchedule(
        broadcasterID broadcasterId: String,
        with settings: ChannelStreamScheduleSettingsUpdate
    ) async throws {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        HelixQuery.append(
            settings.isVacationEnabled.map { URLQueryItem(name: "is_vacation_enabled", value: String($0)) },
            to: &queryItems
        )
        HelixQuery.append(
            settings.vacationStartTime.map { URLQueryItem(name: "vacation_start_time", value: TwitchDateParser.string(from: $0)) },
            to: &queryItems
        )
        HelixQuery.append(
            settings.vacationEndTime.map { URLQueryItem(name: "vacation_end_time", value: TwitchDateParser.string(from: $0)) },
            to: &queryItems
        )
        HelixQuery.append(HelixQuery.item("timezone", settings.timezone), to: &queryItems)

        try await requestNoContent(
            endpoint: "schedule/settings",
            method: "PATCH",
            queryItems: queryItems
        )
    }

    /// Creates a stream schedule segment.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segment: The segment to create.
    /// - Returns: The created schedule.
    /// - SeeAlso: [Create Channel Stream Schedule Segment](https://dev.twitch.tv/docs/api/reference/#create-channel-stream-schedule-segment)
    public func createChannelStreamScheduleSegment(
        broadcasterID broadcasterId: String,
        segment: ChannelStreamScheduleSegmentCreate
    ) async throws -> ChannelStreamSchedule {
        let data = try await requestRawData(
            endpoint: "schedule/segment",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)],
            body: try JSONEncoder.twitch().encode(segment)
        )
        return try decodeScheduleEnvelope(from: data).data
    }

    /// Updates a stream schedule segment.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segmentId: The schedule segment ID.
    ///   - update: Segment fields to update.
    /// - Returns: The updated schedule.
    /// - SeeAlso: [Update Channel Stream Schedule Segment](https://dev.twitch.tv/docs/api/reference/#update-channel-stream-schedule-segment)
    public func updateChannelStreamScheduleSegment(
        broadcasterID broadcasterId: String,
        segmentID segmentId: String,
        with update: ChannelStreamScheduleSegmentUpdate
    ) async throws -> ChannelStreamSchedule {
        let data = try await requestRawData(
            endpoint: "schedule/segment",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "id", value: segmentId)
            ],
            body: try JSONEncoder.twitch().encode(update)
        )
        return try decodeScheduleEnvelope(from: data).data
    }

    /// Deletes a stream schedule segment.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segmentId: The schedule segment ID.
    /// - SeeAlso: [Delete Channel Stream Schedule Segment](https://dev.twitch.tv/docs/api/reference/#delete-channel-stream-schedule-segment)
    public func deleteChannelStreamScheduleSegment(
        broadcasterID broadcasterId: String,
        segmentID segmentId: String
    ) async throws {
        try await requestNoContent(
            endpoint: "schedule/segment",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "id", value: segmentId)
            ]
        )
    }

    private func decodeScheduleEnvelope(from data: Data) throws -> ScheduleEnvelope {
        do {
            return try JSONDecoder.twitch().decode(ScheduleEnvelope.self, from: data)
        } catch {
            throw HelixError.decodingFailed(error.localizedDescription)
        }
    }
}

/// Schedule endpoints return `data` as a single object — not the usual
/// Helix `data` array — so `HelixResponse` cannot decode them.
private struct ScheduleEnvelope: Decodable {
    let data: ChannelStreamSchedule
    let pagination: Pagination?
}

public struct ChannelStreamSchedulePage: Sendable, Equatable {
    public let schedule: ChannelStreamSchedule
    public let pagination: Pagination?
    public let metadata: HelixResponseMetadata?

    public var nextCursor: String? {
        pagination?.cursor
    }
}

public struct ChannelStreamSchedule: Decodable, Sendable, Equatable {
    public let segments: [ChannelStreamScheduleSegment]
    public let broadcasterId: String
    public let broadcasterName: String
    public let broadcasterLogin: String
    public let vacation: ChannelStreamScheduleVacation?
}

public struct ChannelStreamScheduleSegment: Decodable, Sendable, Equatable {
    public let id: String
    public let startTime: Date
    public let endTime: Date
    public let title: String
    public let canceledUntil: Date?
    public let category: Category?
    public let isRecurring: Bool

    public struct Category: Decodable, Sendable, Equatable {
        public let id: String
        public let name: String
    }
}

public struct ChannelStreamScheduleVacation: Codable, Sendable, Equatable {
    public let startTime: Date
    public let endTime: Date
}

public struct ChannelStreamScheduleSettingsUpdate: Encodable, Sendable, Equatable {
    public let isVacationEnabled: Bool?
    public let vacationStartTime: Date?
    public let vacationEndTime: Date?
    public let timezone: String?

    public init(
        isVacationEnabled: Bool? = nil,
        vacationStartTime: Date? = nil,
        vacationEndTime: Date? = nil,
        timezone: String? = nil
    ) {
        self.isVacationEnabled = isVacationEnabled
        self.vacationStartTime = vacationStartTime
        self.vacationEndTime = vacationEndTime
        self.timezone = timezone
    }
}

public struct ChannelStreamScheduleSegmentCreate: Encodable, Sendable, Equatable {
    public let startTime: Date
    public let timezone: String
    public let isRecurring: Bool
    public let duration: String?
    public let categoryId: String?
    public let title: String?

    public init(
        startTime: Date,
        timezone: String,
        isRecurring: Bool,
        duration: String? = nil,
        categoryID categoryId: String? = nil,
        title: String? = nil
    ) {
        self.startTime = startTime
        self.timezone = timezone
        self.isRecurring = isRecurring
        self.duration = duration
        self.categoryId = categoryId
        self.title = title
    }
}

public struct ChannelStreamScheduleSegmentUpdate: Encodable, Sendable, Equatable {
    public let startTime: Date?
    public let duration: String?
    public let categoryId: String?
    public let title: String?
    public let isCanceled: Bool?
    public let timezone: String?

    public init(
        startTime: Date? = nil,
        duration: String? = nil,
        categoryID categoryId: String? = nil,
        title: String? = nil,
        isCanceled: Bool? = nil,
        timezone: String? = nil
    ) {
        self.startTime = startTime
        self.duration = duration
        self.categoryId = categoryId
        self.title = title
        self.isCanceled = isCanceled
        self.timezone = timezone
    }
}
