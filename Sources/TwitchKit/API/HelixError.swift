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

    /// Twitch no longer accepts the device code: the user denied access, the
    /// code expired, or it was already redeemed. Start a new device code
    /// flow. Carries Twitch's error body (for example
    /// `{"status":400,"message":"invalid device code"}`).
    case deviceCodeRejected(TwitchOAuthError)

    /// An OAuth redirect's `state` didn't match the value your app sent, so
    /// the redirect may be forged (CSRF). Ignore it.
    case oauthStateMismatch

    /// Twitch reports that an access token was issued to a different client
    /// ID than this app's. Using it would act on behalf of another app (token
    /// substitution), so reject it.
    case tokenClientMismatch(expected: String, actual: String?)

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
        case .deviceCodeRejected(let error): "Device code rejected: \(error.message)"
        case .oauthStateMismatch: "OAuth redirect state doesn't match the state that was sent"
        case .tokenClientMismatch(let expected, let actual):
            "Access token belongs to client ID \(actual ?? "(none)"), not \(expected)"
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

    public init(from decoder: any Decoder) throws {
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

    /// Whether Twitch reports `code`, in either the `error` or the `message`
    /// field, case-insensitively. Twitch's device code flow puts its codes in
    /// `message` alone (`{"status":400,"message":"authorization_pending"}`),
    /// while standard OAuth bodies use `error`.
    func reports(_ code: String) -> Bool {
        error.caseInsensitiveCompare(code) == .orderedSame
            || message.caseInsensitiveCompare(code) == .orderedSame
    }

    /// The user hasn't finished authorizing a device code yet; poll again.
    public var isAuthorizationPending: Bool { reports("authorization_pending") }

    /// Twitch asks the device code poller to slow down.
    public var isSlowDown: Bool { reports("slow_down") }

    /// Twitch no longer accepts the device code: it expired, was denied, or
    /// was already redeemed.
    public var isDeviceCodeRejected: Bool {
        reports("invalid device code") || reports("expired_token") || reports("access_denied")
    }
}

/// Twitch API error response shape.
public struct TwitchAPIError: Decodable, Sendable, Equatable {
    public let error: String
    public let status: Int
    public let message: String
    /// The id of the existing resource, when Twitch names one. A 409 from
    /// Create EventSub Subscription carries the id of the subscription that
    /// already exists.
    public let id: String?

    public init(error: String, status: Int, message: String, id: String? = nil) {
        self.error = error
        self.status = status
        self.message = message
        self.id = id
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

    public init(from decoder: any Decoder) throws {
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
    public init(from decoder: any Decoder) throws {
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
        decoder.keyDecodingStrategy = .custom { codingPath in
            let key = codingPath.last!
            if key.intValue != nil { return key }
            return TwitchCodingKey(stringValue: TwitchKeyCase.swiftName(fromSnakeCase: key.stringValue))
        }
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
        encoder.keyEncodingStrategy = .custom { codingPath in
            let key = codingPath.last!
            if key.intValue != nil { return key }
            return TwitchCodingKey(stringValue: TwitchKeyCase.snakeCase(fromSwiftName: key.stringValue))
        }
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(TwitchDateParser.string(from: date))
        }
        return encoder
    }
}

enum TwitchDateParser {
    // `Date.ISO8601FormatStyle` is a Sendable value type, so it needs none of the
    // locking the old `ISO8601DateFormatter` cache did. Twitch sends anywhere from
    // zero to nine fractional digits; the fractional style accepts all of them, and
    // the whole-second style is a defensive fallback.
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let standard = Date.ISO8601FormatStyle()

    static func date(from value: String) -> Date? {
        (try? fractional.parse(value)) ?? (try? standard.parse(value))
    }

    static func string(from date: Date) -> String {
        fractional.format(date)
    }
}
