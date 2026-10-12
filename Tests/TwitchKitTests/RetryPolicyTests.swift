import Foundation
import XCTest
@testable import TwitchKit

/// Rate-limited (429) requests are retried once Twitch's bucket refills;
/// 503 retries are limited to idempotent methods.
final class RetryPolicyTests: XCTestCase {
    private static let usersJSON = #"{"data":[{"id":"1","login":"twitchdev","display_name":"TwitchDev","profile_image_url":"https://example.com/p.png","broadcaster_type":""}]}"#
    private static let rateLimitedBody = #"{"error":"Too Many Requests","status":429,"message":"Rate limit exceeded"}"#
    private static let unavailableBody = #"{"error":"Service Unavailable","status":503,"message":"Try again"}"#
    private static let chatSentJSON = #"{"data":[{"message_id":"m1","is_sent":true}]}"#

    private func api(_ transport: MockHTTPClient, retryPolicy: HelixRetryPolicy = .default) -> HelixClient {
        HelixClient(
            tokenProvider: TwitchTokenProvider(
                oauthClient: TwitchOAuthClient(clientId: "client"),
                tokenStore: InMemoryTokenStore(token: OAuthToken(accessToken: "test-token"))
            ),
            clientId: "client",
            httpClient: transport,
            retryPolicy: retryPolicy
        )
    }

    // MARK: - 429

    func testRateLimitedRequestIsRetriedAfterRetryAfter() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "0", "Retry-After": "0"]),
            .json(statusCode: 200, body: Self.usersJSON),
        ])

        let user = try await api(transport).fetchUser()

        XCTAssertEqual(user.id, "1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func testRateLimitedPOSTIsRetriedWithItsBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "0", "Retry-After": "0"]),
            .json(statusCode: 200, body: Self.chatSentJSON),
        ])

        let result = try await api(transport).sendChatMessage(broadcasterId: "b", senderId: "s", message: "hello")

        XCTAssertTrue(result.isSent)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2, "Twitch doesn't process a rate-limited request, so even a POST is safe to retry")
        XCTAssertEqual(requests[1].httpMethod, "POST")
        XCTAssertEqual(requests[1].httpBody, requests[0].httpBody)
    }

    func testRateLimitRetriesStopAtThePolicyLimit() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "0", "Retry-After": "0"]),
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "0", "Retry-After": "0"]),
        ])

        do {
            _ = try await api(transport).fetchUser()
            XCTFail("Expected rate limit error")
        } catch HelixError.rateLimited(let rateLimit) {
            XCTAssertEqual(rateLimit.remaining, 0)
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2, "the default policy retries a 429 once")
    }

    func testRateLimitWithPointsRemainingIsNotRetried() async throws {
        // A 429 that leaves points in the bucket isn't the per-minute rate
        // limit (EventSub's subscription limits also answer 429); waiting for
        // a reset can't help.
        let reset = Int(Date.now.timeIntervalSince1970) + 1
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "500", "Ratelimit-Reset": "\(reset)"]),
        ])

        do {
            _ = try await api(transport).fetchUser()
            XCTFail("Expected rate limit error")
        } catch HelixError.rateLimited {
            // Expected.
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testRateLimitLongerThanMaxDelayIsNotRetried() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "0", "Retry-After": "120"]),
        ])

        do {
            _ = try await api(transport).fetchUser()
            XCTFail("Expected rate limit error")
        } catch HelixError.rateLimited(let rateLimit) {
            XCTAssertEqual(rateLimit.retryAfter, 120)
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testRateLimitRetryCanBeDisabled() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 429, body: Self.rateLimitedBody, headers: ["Ratelimit-Remaining": "0", "Retry-After": "0"]),
        ])

        do {
            _ = try await api(transport, retryPolicy: .never).fetchUser()
            XCTFail("Expected rate limit error")
        } catch HelixError.rateLimited {
            // Expected.
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testRateLimitDelayUsesResetMeasuredAgainstServerDate() {
        let serverNow = Date(timeIntervalSince1970: 1_800_000_000)
        let policy = HelixRetryPolicy.default
        func delay(remaining: Int? = 0, resetIn seconds: TimeInterval?, retryAfter: Int? = nil) -> Duration? {
            HelixClient.rateLimitRetryDelay(
                for: HelixRateLimit(
                    limit: 800,
                    remaining: remaining,
                    resetAt: seconds.map { serverNow.addingTimeInterval($0) },
                    retryAfter: retryAfter
                ),
                serverDate: serverNow,
                policy: policy
            )
        }

        XCTAssertEqual(delay(resetIn: 5), .seconds(5))
        XCTAssertEqual(delay(resetIn: -3), .seconds(1), "a reset already past still waits a second")
        XCTAssertEqual(delay(resetIn: 30, retryAfter: 2), .seconds(2), "Retry-After wins over the reset")
        XCTAssertNil(delay(resetIn: nil), "no reset and no Retry-After: nothing to wait for")
        XCTAssertNil(delay(remaining: 10, resetIn: 5), "points remain, so this isn't the bucket limit")
        XCTAssertNil(delay(resetIn: 61), "longer than maxRateLimitDelay")
    }

    func testRateLimitDelayReadsResponseDateHeader() throws {
        // Device clock is irrelevant: the wait is reset minus the server's Date.
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://api.twitch.tv/helix/users")!,
            statusCode: 429,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Date": "Fri, 15 Jan 2027 08:00:00 GMT",
                "Ratelimit-Remaining": "0",
                // 2027-01-15T08:00:07Z
                "Ratelimit-Reset": "1800000007",
            ]
        ))

        XCTAssertEqual(HelixClient.rateLimitRetryDelay(for: response, policy: .default), .seconds(7))
    }

    // MARK: - 503

    func testServiceUnavailablePOSTIsNotRetriedByDefault() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: Self.unavailableBody),
        ])

        do {
            _ = try await api(transport).sendChatMessage(broadcasterId: "b", senderId: "s", message: "hello")
            XCTFail("Expected server error")
        } catch HelixError.serverError(let status) {
            XCTAssertEqual(status, 503)
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1, "a 503 doesn't prove the message wasn't sent; retrying could send it twice")
    }

    func testServiceUnavailablePOSTIsRetriedWhenOptedIn() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: Self.unavailableBody),
            .json(statusCode: 200, body: Self.chatSentJSON),
        ])
        let policy = HelixRetryPolicy(retriesNonIdempotentRequests: true)

        let result = try await api(transport, retryPolicy: policy).sendChatMessage(broadcasterId: "b", senderId: "s", message: "hello")

        XCTAssertTrue(result.isSent)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func testServiceUnavailableRetryAppliesToIdempotentMethods() {
        let policy = HelixRetryPolicy.default

        for method in ["GET", "HEAD", "PUT", "DELETE", "get"] {
            XCTAssertTrue(policy.shouldRetryServiceUnavailable(method: method), method)
        }
        for method in ["POST", "PATCH"] {
            XCTAssertFalse(policy.shouldRetryServiceUnavailable(method: method), method)
        }
        XCTAssertFalse(HelixRetryPolicy.never.shouldRetryServiceUnavailable(method: "GET"))
    }
}
