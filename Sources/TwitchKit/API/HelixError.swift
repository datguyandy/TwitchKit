import Foundation

/// Errors returned by TwitchKit's Helix and OAuth helpers.
public enum HelixError: Error, Sendable, LocalizedError {
    // Auth
    /// HTTP 401. Carries Twitch's error body when one was returned — its
    /// message distinguishes an invalid token from a missing scope or an ID
    /// that doesn't match the token. `nil` when no token could be refreshed
    /// or Twitch's body couldn't be parsed.
    case unauthorized(TwitchAPIError?)
    case forbidden(TwitchAPIError)

    // Client errors
    case badRequest(TwitchAPIError)
    /// HTTP 404. Lookups that can legitimately find nothing (for example
    /// `fetchUser(id:)` or `fetchStream(userID:)`) return `nil` instead.
    case notFound
    case conflict(TwitchAPIError)
    case unprocessable(TwitchAPIError)
    case rateLimited(HelixRateLimit)
    case oauth(TwitchOAuthError)

    /// An HTTP status TwitchKit has no dedicated case for, outside 5xx: for
    /// example 410 for a retired endpoint, or 405. Carries Twitch's error
    /// body when one could be parsed.
    case unexpectedStatus(status: Int, TwitchAPIError?)

    // Server errors
    /// HTTP 5xx.
    case serverError(status: Int)

    // Client-side
    case notAuthenticated
    case missingClientSecret
    case invalidResponse
    /// Twitch answered a request that always returns an item (a write, or a
    /// read such as `fetchChatSettings`) with a successful but empty `data`.
    case emptyResponse
    case decodingFailed(String)
    case networkError(String)

    /// A transport-level failure surfaced by URLSession, preserving the underlying
    /// `URLError` so callers can distinguish failures (offline, timeout, TLS, …)
    /// via `error.code`.
    case transport(URLError)

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let error):
            if let error {
                "Unauthorized: \(error.message)"
            } else {
                "Unauthorized — token invalid or expired"
            }
        case .forbidden(let error): "Forbidden: \(error.message)"
        case .badRequest(let error): "Bad request: \(error.message)"
        case .notFound: "Not found"
        case .conflict(let error): "Conflict: \(error.message)"
        case .unprocessable(let error): "Unprocessable: \(error.message)"
        case .rateLimited(let rateLimit):
            if let retryDelay = rateLimit.recommendedRetryDelay {
                "Rate limited — retry after \(retryDelay)s"
            } else {
                "Rate limited"
            }
        case .oauth(let error): "OAuth error: \(error.message)"
        case .unexpectedStatus(let status, let error):
            if let error {
                "Unexpected HTTP \(status): \(error.message)"
            } else {
                "Unexpected HTTP \(status)"
            }
        case .serverError(let status): "Server error (HTTP \(status))"
        case .notAuthenticated: "Not authenticated — login required"
        case .missingClientSecret: "Client secret required for this OAuth flow"
        case .invalidResponse: "Invalid HTTP response"
        case .emptyResponse: "Twitch returned a successful response without the expected data"
        case .decodingFailed(let msg): "JSON decode failed: \(msg)"
        case .networkError(let msg): "Network error: \(msg)"
        case .transport(let error): "Network error: \(error.localizedDescription) (URLError code \(error.code.rawValue))"
        }
    }
}

/// Rate-limit metadata returned by Twitch Helix responses.
public struct HelixRateLimit: Sendable, Equatable {
    /// The rate at which points are added to the rate-limit bucket.
    public let limit: Int?

    /// The number of points remaining in the rate-limit bucket.
    public let remaining: Int?

    /// The time when Twitch says the rate-limit bucket resets to full.
    public let resetAt: Date?

    /// A direct retry delay, when a response includes a retry header.
    public let retryAfter: Int?

    /// Creates rate-limit metadata from Twitch response headers.
    ///
    /// - Parameters:
    ///   - limit: Value from `Ratelimit-Limit`, if present.
    ///   - remaining: Value from `Ratelimit-Remaining`, if present.
    ///   - resetAt: Time from `Ratelimit-Reset`, if present.
    ///   - retryAfter: Value from `Retry-After`, if present.
    public init(limit: Int? = nil, remaining: Int? = nil, resetAt: Date? = nil, retryAfter: Int? = nil) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
        self.retryAfter = retryAfter
    }

    /// The number of seconds until `resetAt`, rounded up to avoid retrying too early.
    public func secondsUntilReset(relativeTo date: Date = .now) -> Int? {
        guard let resetAt else { return nil }
        return max(0, Int(ceil(resetAt.timeIntervalSince(date))))
    }

    /// The preferred retry delay for a rate-limited request.
    public var recommendedRetryDelay: Int? {
        retryAfter ?? secondsUntilReset()
    }
}

/// HTTP metadata returned with a Helix response.
public struct HelixResponseMetadata: Sendable, Equatable {
    /// The HTTP status code returned by Twitch.
    public let statusCode: Int

    /// Rate-limit metadata returned with the response, when present.
    public let rateLimit: HelixRateLimit

    /// Creates response metadata for a Helix HTTP response.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by Twitch.
    ///   - rateLimit: Rate-limit metadata parsed from Twitch response headers.
    public init(statusCode: Int, rateLimit: HelixRateLimit = HelixRateLimit()) {
        self.statusCode = statusCode
        self.rateLimit = rateLimit
    }
}


/// Twitch OAuth error response shape.
public struct TwitchOAuthError: Decodable, Sendable, Equatable {
    public let error: String
    public let status: Int?
    public let message: String
    public let errorDescription: String?

    public init(error: String, status: Int? = nil, message: String? = nil, errorDescription: String? = nil) {
        self.error = error
        self.status = status
        self.message = message ?? errorDescription ?? error
        self.errorDescription = errorDescription
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case status
        case message
        case errorDescription
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let error = try container.decodeIfPresent(String.self, forKey: .error) ?? "oauth_error"
        let status = try container.decodeIfPresent(Int.self, forKey: .status)
        let message = try container.decodeIfPresent(String.self, forKey: .message)
        let errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        self.init(error: error, status: status, message: message, errorDescription: errorDescription)
    }

    static func fallback(status: Int, message: String) -> Self {
        Self(error: "HTTP \(status)", status: status, message: message)
    }
}

/// Twitch API error response shape.
public struct TwitchAPIError: Decodable, Sendable, Equatable {
    public let error: String
    public let status: Int
    public let message: String

    public init(error: String, status: Int, message: String) {
        self.error = error
        self.status = status
        self.message = message
    }

    static func fallback(status: Int, message: String) -> Self {
        Self(error: "HTTP \(status)", status: status, message: message)
    }
}

/// Response wrapper for Helix endpoints.
///
/// The `metadata` property is populated for responses returned by `HelixClient`.
/// It is `nil` when decoding this type directly from JSON.
public struct HelixResponse<T: Decodable & Sendable>: Decodable, Sendable {
    /// Items returned in Twitch's top-level `data` array.
    public let data: [T]

    /// Cursor pagination information, when the endpoint is paginated.
    public let pagination: Pagination?

    /// Total number of matching items, when Twitch includes a total.
    public let total: Int?

    /// Total EventSub subscription cost, when returned by Twitch.
    public let totalCost: Int?

    /// Maximum EventSub subscription cost allowed, when returned by Twitch.
    public let maxTotalCost: Int?

    /// HTTP metadata attached by `HelixClient`.
    public let metadata: HelixResponseMetadata?

    public init(
        data: [T],
        pagination: Pagination? = nil,
        total: Int? = nil,
        totalCost: Int? = nil,
        maxTotalCost: Int? = nil,
        metadata: HelixResponseMetadata? = nil
    ) {
        self.data = data
        self.pagination = pagination
        self.total = total
        self.totalCost = totalCost
        self.maxTotalCost = maxTotalCost
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case data
        case pagination
        case total
        case totalCost
        case maxTotalCost
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([T].self, forKey: .data)
        pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        totalCost = try container.decodeIfPresent(Int.self, forKey: .totalCost)
        maxTotalCost = try container.decodeIfPresent(Int.self, forKey: .maxTotalCost)
        metadata = nil
    }

    public var page: HelixPage<T> {
        HelixPage(data: data, pagination: pagination, total: total, metadata: metadata)
    }
}

/// Cursor pagination returned by Twitch Helix endpoints.
public struct Pagination: Decodable, Sendable, Equatable {
    /// Cursor used to request the next page, or `nil` on the last page.
    public let cursor: String?

    /// Creates pagination metadata.
    ///
    /// - Parameter cursor: Cursor used to request the next page. An empty
    ///   string is treated as `nil` (no more pages).
    public init(cursor: String?) {
        self.cursor = cursor?.isEmpty == true ? nil : cursor
    }

    private enum CodingKeys: String, CodingKey {
        case cursor
    }

    /// Normalizes `"cursor": ""` to `nil`. Sending an empty cursor back as
    /// `after=` restarts at the first page, so a paged sequence would loop.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(cursor: try container.decodeIfPresent(String.self, forKey: .cursor))
    }
}

/// A single page of elements returned by a paginated Helix endpoint.
public struct HelixPage<Element: Sendable>: Sendable {
    /// Items on this page.
    public let data: [Element]

    /// Cursor pagination information, when more pages are available.
    public let pagination: Pagination?

    /// Total number of matching items, when Twitch includes a total.
    public let total: Int?

    /// HTTP metadata attached by `HelixClient`.
    public let metadata: HelixResponseMetadata?

    public init(
        data: [Element],
        pagination: Pagination? = nil,
        total: Int? = nil,
        metadata: HelixResponseMetadata? = nil
    ) {
        self.data = data
        self.pagination = pagination
        self.total = total
        self.metadata = metadata
    }

    /// Cursor used to fetch the next page.
    public var nextCursor: String? {
        pagination?.cursor
    }
}

extension HelixPage: Equatable where Element: Equatable {}

/// An async sequence that lazily follows Helix cursor pagination.
public struct HelixPagedSequence<Element: Sendable>: AsyncSequence, Sendable {
    public typealias AsyncIterator = Iterator

    private let initialCursor: String?
    private let fetchPage: @Sendable (String?) async throws -> HelixPage<Element>

    public init(
        startingAfter initialCursor: String? = nil,
        fetchPage: @escaping @Sendable (String?) async throws -> HelixPage<Element>
    ) {
        self.initialCursor = initialCursor
        self.fetchPage = fetchPage
    }

    /// Creates an iterator for the paged sequence.
    public func makeAsyncIterator() -> Iterator {
        Iterator(nextCursor: initialCursor, fetchPage: fetchPage)
    }

    /// Iterator for a `HelixPagedSequence`.
    public struct Iterator: AsyncIteratorProtocol {
        private var buffer: [Element] = []
        private var bufferIndex = 0
        private var nextCursor: String?
        private var shouldFetchPage = true
        private let fetchPage: @Sendable (String?) async throws -> HelixPage<Element>

        init(
            nextCursor: String?,
            fetchPage: @escaping @Sendable (String?) async throws -> HelixPage<Element>
        ) {
            self.nextCursor = nextCursor
            self.fetchPage = fetchPage
        }

        /// Returns the next element, fetching another page when needed.
        public mutating func next() async throws -> Element? {
            while bufferIndex >= buffer.count {
                guard shouldFetchPage else {
                    return nil
                }

                let requestedCursor = nextCursor
                let page = try await fetchPage(requestedCursor)
                buffer = page.data
                bufferIndex = 0
                nextCursor = page.nextCursor
                // Stop when Twitch hands back the cursor that was just
                // requested: following it would fetch the same page forever.
                shouldFetchPage = page.nextCursor != nil && page.nextCursor != requestedCursor

                if buffer.isEmpty, !shouldFetchPage {
                    return nil
                }
            }

            let element = buffer[bufferIndex]
            bufferIndex += 1
            if bufferIndex == buffer.count {
                buffer.removeAll(keepingCapacity: true)
                bufferIndex = 0
            }
            return element
        }
    }
}

/// Factory for configured JSONDecoder — NOT shared (JSONDecoder is not Sendable).
extension JSONDecoder {
    static func twitch() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = TwitchDateParser.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Twitch ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static func twitch() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(TwitchDateParser.string(from: date))
        }
        return encoder
    }
}

enum TwitchDateParser {
    private static let cache = TwitchISO8601DateFormatterCache()

    static func date(from value: String) -> Date? {
        cache.date(from: value)
    }

    static func string(from date: Date) -> String {
        cache.string(from: date)
    }
}

private final class TwitchISO8601DateFormatterCache: @unchecked Sendable {
    // ISO8601DateFormatter is mutable and not Sendable; the lock serializes all access.
    private let lock = NSLock()
    private let fractionalFormatter: ISO8601DateFormatter
    private let standardFormatter: ISO8601DateFormatter

    init() {
        fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
    }

    func date(from value: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }

    func string(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return fractionalFormatter.string(from: date)
    }
}
