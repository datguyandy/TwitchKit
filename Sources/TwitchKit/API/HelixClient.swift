import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "helix")

/// Client for Twitch Helix HTTP endpoints.
public struct HelixClient: Sendable {
    private let tokenProvider: any TwitchAccessTokenProvider
    private let clientId: String
    private let httpClient: any HTTPClient
    private let requestConfiguration: HelixRequestConfiguration
    private let retryPolicy: HelixRetryPolicy
    private let responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)?

    private static let baseURL = "https://api.twitch.tv/helix/"

    public init(
        tokenProvider: any TwitchAccessTokenProvider,
        clientID clientId: String,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil
    ) {
        self.tokenProvider = tokenProvider
        self.clientId = clientId
        self.httpClient = httpClient
        self.requestConfiguration = requestConfiguration
        self.retryPolicy = retryPolicy
        self.responseMetadataHandler = responseMetadataHandler
    }

    public init(
        auth: TwitchAuth,
        clientID clientId: String,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil
    ) {
        self.init(
            tokenProvider: auth,
            clientID: clientId,
            httpClient: httpClient,
            requestConfiguration: requestConfiguration,
            retryPolicy: retryPolicy,
            responseMetadataHandler: responseMetadataHandler
        )
    }

    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> HelixResponse<T> {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        return try decodeHelixResponse(T.self, from: response.data, response: response.httpResponse)
    }

    func requestNoContent(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        try validateSuccess(
            data: response.data,
            response: response.httpResponse,
            acceptedStatusCodes: [204],
            fallbackMessage: "No content response expected"
        )
    }

    func requestRawData(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        acceptedStatusCodes: Set<Int> = [200],
        fallbackMessage: String = "Helix response expected"
    ) async throws -> Data {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        _ = try validateSuccess(
            data: response.data,
            response: response.httpResponse,
            acceptedStatusCodes: acceptedStatusCodes,
            fallbackMessage: fallbackMessage
        )
        return response.data
    }

    func requestAccepted(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        fallbackMessage: String
    ) async throws {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        try validateSuccess(
            data: response.data,
            response: response.httpResponse,
            acceptedStatusCodes: [202],
            fallbackMessage: fallbackMessage
        )
    }

    func pagedRequest<T: Decodable & Sendable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<T> {
        HelixPagedSequence { cursor in
            var pagedQueryItems = queryItems ?? []
            try HelixQuery.appendPagination(to: &pagedQueryItems, first: pageSize, after: cursor)

            let response: HelixResponse<T> = try await request(
                endpoint: endpoint,
                queryItems: pagedQueryItems.isEmpty ? nil : pagedQueryItems
            )
            return response.page
        }
    }

    private func sendAuthenticatedRequest(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> HelixHTTPResponse {
        var components = URLComponents(string: Self.baseURL + endpoint)!
        components.setFormSafeQueryItems(queryItems)

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        if let timeoutInterval = requestConfiguration.timeoutInterval {
            urlRequest.timeoutInterval = timeoutInterval
        }

        let token = try await tokenProvider.accessToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(clientId, forHTTPHeaderField: "Client-Id")
        if body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            var (data, httpResponse) = try await send(urlRequest)

            if httpResponse.statusCode == 401 {
                let unauthorizedError = decodedAPIError(from: data)
                guard Self.isTokenRejection(unauthorizedError) else {
                    // A new token can't fix a missing scope or an ID
                    // mismatch; surface Twitch's message instead.
                    logger.warning("Helix \(endpoint) returned 401 that a token refresh can't fix")
                    throw HelixError.unauthorized(unauthorizedError)
                }
                logger.warning("Helix \(endpoint) returned 401; refreshing token and retrying")
                do {
                    try await tokenProvider.refreshIfNeeded(rejectedAccessToken: token)
                } catch HelixError.unauthorized(.none) {
                    // No refresh token, so nothing can renew it. Report
                    // Twitch's rejection rather than the provider's.
                    throw HelixError.unauthorized(unauthorizedError)
                }
                let newToken = try await tokenProvider.accessToken()
                urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                (data, httpResponse) = try await send(urlRequest)
            }

            var rateLimitRetries = 0
            var retriedServiceUnavailable = false
            while true {
                if httpResponse.statusCode == 429,
                   rateLimitRetries < retryPolicy.rateLimitRetries,
                   let delay = Self.rateLimitRetryDelay(for: httpResponse, policy: retryPolicy) {
                    // Twitch didn't process a rate-limited request, so any
                    // method can be retried once the bucket has refilled.
                    rateLimitRetries += 1
                    logger.warning("Helix \(endpoint) returned 429; retrying in \(delay.components.seconds)s")
                    try await Task.sleep(for: delay)
                    (data, httpResponse) = try await send(urlRequest)
                    continue
                }

                if httpResponse.statusCode == 503,
                   !retriedServiceUnavailable,
                   retryPolicy.shouldRetryServiceUnavailable(method: method) {
                    retriedServiceUnavailable = true
                    logger.warning("Helix \(endpoint) returned 503; retrying once")
                    // Jittered pause before the retry: an immediate re-request
                    // means every client hammers an already-degraded service
                    // within milliseconds of the first 503, and the jitter keeps
                    // a fleet of clients from retrying in lockstep.
                    try await Task.sleep(for: .milliseconds(Int.random(in: 100...400)))
                    (data, httpResponse) = try await send(urlRequest)
                    continue
                }

                return HelixHTTPResponse(data: data, httpResponse: httpResponse)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HelixError {
            throw error
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            if let urlError = error as? URLError {
                throw HelixError.transport(urlError)
            }
            throw HelixError.networkError(error.localizedDescription)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HelixError.invalidResponse
        }
        return (data, httpResponse)
    }

    /// How long to wait before retrying a 429, or `nil` to surface it.
    ///
    /// Waits for `Retry-After` when Twitch sends it, otherwise until
    /// `Ratelimit-Reset`, measured against the response's `Date` header so a
    /// skewed device clock doesn't stretch or skip the wait. A 429 that leaves
    /// points in the bucket isn't the per-minute rate limit (EventSub's
    /// subscription limits also answer 429), so waiting can't help and it is
    /// surfaced at once, as is a wait longer than `maxRateLimitDelay`.
    static func rateLimitRetryDelay(for response: HTTPURLResponse, policy: HelixRetryPolicy) -> Duration? {
        let rateLimit = HelixRateLimit(
            limit: intHeader("Ratelimit-Limit", from: response),
            remaining: intHeader("Ratelimit-Remaining", from: response),
            resetAt: intHeader("Ratelimit-Reset", from: response).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            retryAfter: intHeader("Retry-After", from: response)
        )
        let serverDate = response.value(forHTTPHeaderField: "Date").flatMap(httpDate(from:))
        return rateLimitRetryDelay(for: rateLimit, serverDate: serverDate, policy: policy)
    }

    static func rateLimitRetryDelay(
        for rateLimit: HelixRateLimit,
        serverDate: Date?,
        policy: HelixRetryPolicy
    ) -> Duration? {
        let delay: Duration
        if let retryAfter = rateLimit.retryAfter {
            delay = .seconds(max(0, retryAfter))
        } else {
            if let remaining = rateLimit.remaining, remaining > 0 {
                return nil
            }
            guard let secondsUntilReset = rateLimit.secondsUntilReset(relativeTo: serverDate ?? .now) else {
                return nil
            }
            // At least a second: the reset is whole-second precision, and a
            // retry at the same instant would only be rejected again.
            delay = .seconds(max(1, secondsUntilReset))
        }
        return delay <= policy.maxRateLimitDelay ? delay : nil
    }

    /// Parses an HTTP-date (RFC 9110 IMF-fixdate), e.g. `Sun, 11 Oct 2026 08:00:00 GMT`.
    private static func httpDate(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }

    private func decodeHelixResponse<T: Decodable & Sendable>(
        _ type: T.Type,
        from data: Data,
        response: HTTPURLResponse
    ) throws -> HelixResponse<T> {
        let metadata = try validateSuccess(
            data: data,
            response: response,
            acceptedStatusCodes: [200, 202],
            fallbackMessage: "Helix response expected"
        )

        do {
            let decoded = try JSONDecoder.twitch().decode(HelixResponse<T>.self, from: data)
            return HelixResponse(
                data: decoded.data,
                pagination: decoded.pagination,
                total: decoded.total,
                totalCost: decoded.totalCost,
                maxTotalCost: decoded.maxTotalCost,
                metadata: metadata
            )
        } catch {
            let rawJSON = String(data: data.prefix(500), encoding: .utf8) ?? "non-utf8"
            // The raw body must stay redacted: this catch block sits under
            // secret-bearing endpoints (stream key, extension secrets, conduit
            // shard secrets), so an explicit `.private` guards against a
            // schema drift writing live credentials to the unified log.
            logger.error("Helix decode failed for \(String(describing: type)): \(error); JSON: \(rawJSON, privacy: .private)")
            throw HelixError.decodingFailed(error.localizedDescription)
        }
    }

    @discardableResult
    private func validateSuccess(
        data: Data,
        response: HTTPURLResponse,
        acceptedStatusCodes: Set<Int>,
        fallbackMessage: String
    ) throws -> HelixResponseMetadata {
        if acceptedStatusCodes.contains(response.statusCode) {
            let metadata = responseMetadata(from: response)
            responseMetadataHandler?(metadata)
            return metadata
        }
        try throwError(data: data, response: response, fallbackMessage: fallbackMessage)
    }

    private func throwError(data: Data, response: HTTPURLResponse, fallbackMessage: String) throws -> Never {
        switch response.statusCode {
        case 400:
            throw HelixError.badRequest(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 401:
            throw HelixError.unauthorized(decodedAPIError(from: data))
        case 403:
            throw HelixError.forbidden(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 404:
            throw HelixError.notFound
        case 409:
            throw HelixError.conflict(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 422:
            throw HelixError.unprocessable(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 429:
            throw HelixError.rateLimited(rateLimit(from: response))
        case 500...599:
            throw HelixError.serverError(status: response.statusCode)
        default:
            throw HelixError.unexpectedStatus(status: response.statusCode, decodedAPIError(from: data))
        }
    }

    private func apiError(from data: Data, status: Int, fallbackMessage: String) -> TwitchAPIError {
        decodedAPIError(from: data) ?? TwitchAPIError.fallback(status: status, message: fallbackMessage)
    }

    private func decodedAPIError(from data: Data) -> TwitchAPIError? {
        try? JSONDecoder.twitch().decode(TwitchAPIError.self, from: data)
    }

    /// Whether a 401 means the access token itself was rejected, so a
    /// refresh and retry can succeed.
    ///
    /// Twitch also answers 401 for problems a new token can't fix: a missing
    /// scope, or a broadcaster/user/client ID that doesn't match the token.
    /// Refreshing for those rotates the refresh token and retries for
    /// nothing. Anything else, including a missing or unparseable body, is
    /// treated as an invalid or expired token.
    static func isTokenRejection(_ error: TwitchAPIError?) -> Bool {
        guard let message = error?.message.lowercased() else {
            return true
        }
        let nonTokenProblems = ["missing scope", "must match", "do not match", "does not match"]
        return !nonTokenProblems.contains { message.contains($0) }
    }

    private func rateLimit(from response: HTTPURLResponse) -> HelixRateLimit {
        HelixRateLimit(
            limit: Self.intHeader("Ratelimit-Limit", from: response),
            remaining: Self.intHeader("Ratelimit-Remaining", from: response),
            resetAt: Self.intHeader("Ratelimit-Reset", from: response).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            retryAfter: Self.intHeader("Retry-After", from: response)
        )
    }

    private func responseMetadata(from response: HTTPURLResponse) -> HelixResponseMetadata {
        HelixResponseMetadata(statusCode: response.statusCode, rateLimit: rateLimit(from: response))
    }

    private static func intHeader(_ field: String, from response: HTTPURLResponse) -> Int? {
        response.value(forHTTPHeaderField: field).flatMap(Int.init)
    }
}

/// Request-level configuration for Helix HTTP calls.
public struct HelixRequestConfiguration: Sendable, Equatable {
    /// Uses a 30-second request timeout.
    public static let `default` = Self(timeoutInterval: 30)

    /// Leaves URLSession's default timeout behavior unchanged.
    public static let urlSessionDefault = Self(timeoutInterval: nil)

    /// The timeout, in seconds, assigned to each Helix `URLRequest`.
    public let timeoutInterval: TimeInterval?

    /// Creates request-level configuration for Helix HTTP calls.
    ///
    /// - Parameter timeoutInterval: Timeout, in seconds, assigned to each `URLRequest`.
    ///   Pass `nil` to leave URLSession's default timeout unchanged.
    public init(timeoutInterval: TimeInterval? = 30) {
        self.timeoutInterval = timeoutInterval
    }
}

/// Controls automatic retries for Helix requests.
public struct HelixRetryPolicy: Sendable, Equatable {
    /// Retries one HTTP 503 for idempotent requests, and one rate-limited
    /// (429) request after waiting up to 60 seconds for the bucket to refill.
    public static let `default` = Self()

    /// Disables automatic retry behavior.
    public static let never = Self(retryServiceUnavailableOnce: false, rateLimitRetries: 0)

    /// Whether TwitchKit retries one HTTP 503 response before returning an error.
    public let retryServiceUnavailableOnce: Bool

    /// Whether the 503 retry also applies to POST and PATCH requests.
    ///
    /// A 503 doesn't prove Twitch didn't act on the request, so retrying a
    /// POST can, for example, send a chat message twice or start a second
    /// commercial. Off by default; GET, HEAD, PUT, and DELETE are retried.
    public let retriesNonIdempotentRequests: Bool

    /// How many times a rate-limited (429) request is retried. Twitch doesn't
    /// process a rate-limited request, so this applies to every method.
    public let rateLimitRetries: Int

    /// The longest TwitchKit waits before retrying a 429. When Twitch's
    /// headers call for a longer wait, the request fails with
    /// `HelixError.rateLimited` immediately.
    public let maxRateLimitDelay: Duration

    /// Creates a retry policy for Helix requests.
    ///
    /// - Parameters:
    ///   - retryServiceUnavailableOnce: Whether to retry one HTTP 503 response.
    ///   - retriesNonIdempotentRequests: Whether the 503 retry also applies to POST and PATCH.
    ///   - rateLimitRetries: How many times to retry a rate-limited (429) request.
    ///   - maxRateLimitDelay: The longest wait before a 429 retry.
    public init(
        retryServiceUnavailableOnce: Bool = true,
        retriesNonIdempotentRequests: Bool = false,
        rateLimitRetries: Int = 1,
        maxRateLimitDelay: Duration = .seconds(60)
    ) {
        self.retryServiceUnavailableOnce = retryServiceUnavailableOnce
        self.retriesNonIdempotentRequests = retriesNonIdempotentRequests
        self.rateLimitRetries = max(0, rateLimitRetries)
        self.maxRateLimitDelay = maxRateLimitDelay
    }

    func shouldRetryServiceUnavailable(method: String) -> Bool {
        guard retryServiceUnavailableOnce else { return false }
        if retriesNonIdempotentRequests { return true }
        return ["GET", "HEAD", "PUT", "DELETE"].contains(method.uppercased())
    }
}

private struct HelixHTTPResponse: Sendable {
    let data: Data
    let httpResponse: HTTPURLResponse
}
