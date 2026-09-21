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
        clientId: String,
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
        clientId: String,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil
    ) {
        self.init(
            tokenProvider: auth,
            clientId: clientId,
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
        components.queryItems = queryItems

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
            let (data, response) = try await httpClient.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HelixError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                logger.warning("Helix \(endpoint) returned 401; refreshing token and retrying")
                try await tokenProvider.refreshIfNeeded()
                let newToken = try await tokenProvider.accessToken()
                urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await httpClient.data(for: urlRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw HelixError.invalidResponse
                }
                return HelixHTTPResponse(data: retryData, httpResponse: retryHttp)
            }

            if retryPolicy.shouldRetryServiceUnavailable, httpResponse.statusCode == 503 {
                logger.warning("Helix \(endpoint) returned 503; retrying once")
                // Jittered pause before the retry: an immediate re-request
                // means every client hammers an already-degraded service
                // within milliseconds of the first 503, and the jitter keeps
                // a fleet of clients from retrying in lockstep.
                try await Task.sleep(for: .milliseconds(Int.random(in: 100...400)))
                let (retryData, retryResponse) = try await httpClient.data(for: urlRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw HelixError.invalidResponse
                }
                return HelixHTTPResponse(data: retryData, httpResponse: retryHttp)
            }

            return HelixHTTPResponse(data: data, httpResponse: httpResponse)
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
            throw HelixError.unauthorized
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
        default:
            throw HelixError.serverError(status: response.statusCode)
        }
    }

    private func apiError(from data: Data, status: Int, fallbackMessage: String) -> TwitchAPIError {
        (try? JSONDecoder.twitch().decode(TwitchAPIError.self, from: data))
            ?? TwitchAPIError.fallback(status: status, message: fallbackMessage)
    }

    private func rateLimit(from response: HTTPURLResponse) -> HelixRateLimit {
        HelixRateLimit(
            limit: intHeader("Ratelimit-Limit", from: response),
            remaining: intHeader("Ratelimit-Remaining", from: response),
            resetAt: intHeader("Ratelimit-Reset", from: response).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            retryAfter: intHeader("Retry-After", from: response)
        )
    }

    private func responseMetadata(from response: HTTPURLResponse) -> HelixResponseMetadata {
        HelixResponseMetadata(statusCode: response.statusCode, rateLimit: rateLimit(from: response))
    }

    private func intHeader(_ field: String, from response: HTTPURLResponse) -> Int? {
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
    /// Retries one HTTP 503 response, matching Twitch's API health guidance.
    public static let `default` = Self(retryServiceUnavailableOnce: true)

    /// Disables automatic retry behavior.
    public static let never = Self(retryServiceUnavailableOnce: false)

    /// Whether TwitchKit retries one HTTP 503 response before returning an error.
    public let retryServiceUnavailableOnce: Bool

    /// Creates a retry policy for Helix requests.
    ///
    /// - Parameter retryServiceUnavailableOnce: Whether to retry one HTTP 503 response.
    public init(retryServiceUnavailableOnce: Bool = true) {
        self.retryServiceUnavailableOnce = retryServiceUnavailableOnce
    }

    var shouldRetryServiceUnavailable: Bool {
        retryServiceUnavailableOnce
    }
}

private struct HelixHTTPResponse: Sendable {
    let data: Data
    let httpResponse: HTTPURLResponse
}
