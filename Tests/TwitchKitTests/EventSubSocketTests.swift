import XCTest
import Foundation
@testable import TwitchKit

/// Socket-driven tests for `EventSubClient`, built on the `socketFactory`
/// seam: a scripted `FakeWebSocket` plays the Twitch side of the WebSocket
/// (welcome/notification/reconnect frames), and the shared `MockHTTPClient`
/// plays Helix for subscription creation. Together they exercise the real
/// message-handling, dedup, reconnect-handoff, and resubscribe paths without
/// any network.
///
/// Every wait is bounded (flag polls / capped retry loops in the existing
/// repo style) so a regression fails the test instead of wedging the run.
final class EventSubSocketTests: XCTestCase {

    // MARK: - 1. connect() resolves on session_welcome

    func test_connectResolvesOnSessionWelcomeAndSubscribeUsesSessionId() async throws {
        let socket = FakeWebSocket()
        let (client, factory, transport) = try await makeClient(
            sockets: [socket],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1"))
            ]
        )

        try await connectDeliveringWelcome(
            client,
            via: socket,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )

        XCTAssertEqual(factory.requestedURLs.map(\.absoluteString), ["wss://eventsub.wss.twitch.tv/ws"])
        XCTAssertTrue(socket.didResume)

        // The session id learned from the welcome is what subscribe() must
        // hand to Helix — this is the sessionId-dependent behavior connect()
        // exists to unlock.
        let record = try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        XCTAssertEqual(record.id, "sub-1")

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let transportBody = try XCTUnwrap(object["transport"] as? [String: Any])
        XCTAssertEqual(transportBody["method"] as? String, "websocket")
        XCTAssertEqual(transportBody["session_id"] as? String, "session-1")

        await client.disconnect()
    }

    // MARK: - 2. Duplicate message ids are dropped

    func test_duplicateMessageIdsAreDropped() async throws {
        let socket = FakeWebSocket()
        let (client, _, _) = try await makeClient(sockets: [socket])

        // Single-consumer stream: start collecting before pushing. Messages
        // are handled strictly in push order by the one receive loop, so once
        // the sentinel arrives every earlier envelope has been processed.
        let flag = Flag()
        let collector = Task { () -> [String] in
            var observed: [String] = []
            for await event in client.events {
                guard case .unknown(let type, _) = event else { continue }
                observed.append(type)
                if type == "test.event.sentinel" { break }
            }
            await flag.mark()
            return observed
        }

        try await connectDeliveringWelcome(
            client,
            via: socket,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        socket.push(text: notificationJSON(messageId: "dup-1", type: "test.event.duplicate"))
        socket.push(text: notificationJSON(messageId: "dup-1", type: "test.event.duplicate"))
        socket.push(text: notificationJSON(messageId: "sentinel-1", type: "test.event.sentinel"))

        let finished = await flag.poll()
        XCTAssertTrue(finished, "sentinel notification should flow through promptly")
        guard finished else {
            collector.cancel()
            await client.disconnect()
            return
        }

        let observed = await collector.value
        XCTAssertEqual(
            observed,
            ["test.event.duplicate", "test.event.sentinel"],
            "the second envelope with a seen message id must be swallowed"
        )
        await client.disconnect()
    }

    // MARK: - 3. session_reconnect handoff

    func test_sessionReconnectDialsNewURLAndCancelsOldSocketAfterWelcome() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()
        let (client, factory, _) = try await makeClient(sockets: [socketA, socketB])

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )

        let reconnectURL = "wss://eventsub.wss.twitch.tv/ws?challenge=abc"
        socketA.push(text: reconnectJSON(messageId: "reconnect-1", reconnectURL: reconnectURL))

        // The handoff parks a fresh welcome wait once it has dialed socketB;
        // deliver the new session's welcome only then (see
        // connectDeliveringWelcome for why welcomes must not be pre-queued).
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "session_reconnect should dial the new socket and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        // The old socket is cancelled only AFTER the new one delivers its
        // welcome (so no notification gap) — the handoff is asynchronous, so
        // poll for it with a bounded loop in the repo's usual style.
        var attempts = 0
        while !socketA.wasCancelled, attempts < 500 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(
            factory.requestedURLs.map(\.absoluteString),
            ["wss://eventsub.wss.twitch.tv/ws", reconnectURL],
            "the factory must be handed the reconnect_url for the second dial"
        )
        XCTAssertEqual(socketA.cancelCloseCodes, [.normalClosure], "old socket closes normally once the new session is live")
        XCTAssertFalse(socketB.wasCancelled)

        await client.disconnect()
    }

    // MARK: - 4. Keepalive expiry

    func test_keepaliveExpiryTearsDownSocketAndEntersReconnecting() async throws {
        // Timing rationale: the welcome advertises keepalive_timeout_seconds: 1
        // and the watchdog adds its fixed 5s grace, so the deadline lands ~6s
        // after the welcome. Nothing else is ever pushed, so the ONLY way the
        // client can emit `.reconnecting` (and cancel the socket abnormally)
        // is the watchdog firing — the outcome is deterministic; only the
        // wall-clock is real. The poll caps the wait at ~10s.
        let socketA = FakeWebSocket()
        let (client, _, _) = try await makeClient(sockets: [socketA])

        let flag = Flag()
        let collector = Task { () -> [ConnectionState] in
            var observed: [ConnectionState] = []
            for await state in client.connectionState {
                observed.append(state)
                if state == .reconnecting { break }
            }
            await flag.mark()
            return observed
        }

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1", keepaliveSeconds: 1)
        )

        let reachedReconnecting = await flag.poll(attempts: 1_000, interval: .milliseconds(10))
        XCTAssertTrue(reachedReconnecting, "keepalive expiry (~6s) should drive the client into .reconnecting")
        guard reachedReconnecting else {
            collector.cancel()
            await client.disconnect()
            return
        }

        let observed = await collector.value
        XCTAssertEqual(observed, [.connecting, .connected, .reconnecting])
        // handleDisconnect() closes the dead socket before retrying. The close
        // code must be goingAway: 1006 (abnormalClosure) is reserved by RFC
        // 6455 for *reporting* an abnormal close and must never be sent.
        XCTAssertEqual(socketA.cancelCloseCodes, [.goingAway])

        await client.disconnect()
    }

    // MARK: - 5. Resubscribe after reconnect

    func test_resubscribeAfterReconnectCreatesEachDesiredSubscriptionOnceAndSwallowsConflict() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()

        // HTTP script: two initial creates on session-1, then the reconnect
        // round on session-2 where the FIRST re-create 409s (it already
        // exists server-side) and the second succeeds. desiredSubscriptions
        // is a Set, so which subscription draws the 409 is unspecified — the
        // assertions are order-independent. Any extra request would drain the
        // queue and fail with "No mock response queued", so a wedged retry
        // loop shows up as request-count drift, not a hang.
        let (client, _, transport) = try await makeClient(
            sockets: [socketA, socketB],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1")),
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-2", type: "channel.subscribe", sessionId: "session-1")),
                .json(statusCode: 409, body: #"{"error":"Conflict","status":409,"message":"subscription already exists"}"#),
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-3", type: "channel.follow", sessionId: "session-2")),
            ]
        )

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        try await client.subscribe(
            type: "channel.subscribe",
            version: "1",
            condition: ["broadcaster_user_id": "b"]
        )

        // Kill the socket out from under the client: the ladder reconnects
        // (non-live attempt 1 ≈ 1s backoff) onto socketB and resubscribes.
        socketA.failReceive(with: HelixError.networkError("socket dropped"))

        // The reconnect attempt parks a welcome wait once it has dialed
        // socketB (after the ~1s backoff); deliver the new session's welcome
        // only then.
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "the ladder should dial socketB and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        // Bounded wait for the round to settle: 2 initial creates + exactly
        // one re-create per desired subscription.
        var attempts = 0
        while await transport.recordedRequests().count < 4, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }
        // Settle window: a ladder that treats the 409 as failure keeps
        // retrying (each retry issuing more POSTs); a short grace period
        // proves the round genuinely finished.
        try await Task.sleep(for: .milliseconds(300))

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.count, 4,
            "each desired subscription must be (re-)created exactly once per round — no duplicate retries"
        )
        // Both re-creates targeted the NEW session.
        for request in requests.suffix(2) {
            let body = try XCTUnwrap(request.httpBody)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let transportBody = try XCTUnwrap(object["transport"] as? [String: Any])
            XCTAssertEqual(transportBody["session_id"] as? String, "session-2")
        }

        await client.disconnect()
    }

    // MARK: - 6. unsubscribe() during an in-flight resubscribe must win

    func test_unsubscribeDuringInFlightResubscribeIsNotResurrected() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()
        let gate = ResponseGate()

        // HTTP script: initial create on session-1; the session-2 re-create
        // parks on the gate so the test can interleave an unsubscribe while
        // it is deterministically in flight; the unsubscribe's DELETE; and a
        // final DELETE for the record the parked re-create returns — issued
        // only if the client correctly notices the subscription was dropped
        // mid-flight instead of resurrecting it.
        let (client, _, transport) = try await makeClient(
            sockets: [socketA, socketB],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1")),
                .gatedJSON(gate: gate, statusCode: 202, body: subscriptionRecordJSON(id: "sub-9", type: "channel.follow", sessionId: "session-2")),
                .json(statusCode: 204, body: ""),
                .json(statusCode: 204, body: ""),
            ]
        )

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        let record = try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        XCTAssertEqual(record.id, "sub-1")

        // Kill the socket: the ladder reconnects onto socketB and starts the
        // resubscribe round, whose create parks on the gate.
        socketA.failReceive(with: HelixError.networkError("socket dropped"))
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "the ladder should dial socketB and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        // Bounded wait until the re-create is in flight (request #2 recorded).
        var attempts = 0
        while await transport.recordedRequests().count < 2, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }

        // While the re-create is parked, the caller unsubscribes. The actor is
        // reentrant, so this interleaves with resubscribeAll()'s await.
        try await client.unsubscribe(id: "sub-1")

        // Let the parked re-create complete. The subscription is no longer
        // desired, so the client must delete the record it just created
        // instead of writing it back into its maps.
        await gate.open()

        attempts = 0
        while await transport.recordedRequests().count < 4, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }

        let requests = await transport.recordedRequests()
        let deletes = requests.filter { $0.httpMethod == "DELETE" }
        XCTAssertEqual(
            deletes.compactMap { $0.url?.query() }.sorted(),
            ["id=sub-1", "id=sub-9"],
            "an unsubscribe that raced the resubscribe round must not be resurrected — the freshly created record must be deleted"
        )

        await client.disconnect()
    }

    func test_unsubscribeCleanupRetriesAfterServerFailure() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()
        let gate = ResponseGate()

        // HTTP script: initial create on session-1; the session-2 re-create
        // parks on the gate so the test can interleave an unsubscribe while
        // it is deterministically in flight; the unsubscribe's DELETE; and a
        // final DELETE for the record the parked re-create returns — issued
        // only if the client correctly notices the subscription was dropped
        // mid-flight instead of resurrecting it.
        let (client, _, transport) = try await makeClient(
            sockets: [socketA, socketB],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1")),
                .gatedJSON(gate: gate, statusCode: 202, body: subscriptionRecordJSON(id: "sub-9", type: "channel.follow", sessionId: "session-2")),
                .json(statusCode: 204, body: ""),
                .json(statusCode: 500, body: ""),
                .json(statusCode: 404, body: ""),
            ]
        )

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        let record = try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        XCTAssertEqual(record.id, "sub-1")

        // Kill the socket: the ladder reconnects onto socketB and starts the
        // resubscribe round, whose create parks on the gate.
        socketA.failReceive(with: HelixError.networkError("socket dropped"))
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "the ladder should dial socketB and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        // Bounded wait until the re-create is in flight (request #2 recorded).
        var attempts = 0
        while await transport.recordedRequests().count < 2, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }

        // While the re-create is parked, the caller unsubscribes. The actor is
        // reentrant, so this interleaves with resubscribeAll()'s await.
        try await client.unsubscribe(id: "sub-1")

        // Let the parked re-create complete. The subscription is no longer
        // desired, so the client must delete the record it just created
        // instead of writing it back into its maps.
        await gate.open()

        attempts = 0
        while await transport.recordedRequests().count < 5, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }

        let requests = await transport.recordedRequests()
        let deletes = requests.filter { $0.httpMethod == "DELETE" }
        XCTAssertEqual(
            deletes.compactMap { $0.url?.query() }.sorted(),
            ["id=sub-1", "id=sub-9", "id=sub-9"],
            "an unsubscribe that raced the resubscribe round must not be resurrected — the freshly created record must be deleted"
        )

        await client.disconnect()
    }

    // MARK: - 7. Revocation frames surface as .revocation events

    func test_revocationFrameYieldsRevocationEvent() async throws {
        let socket = FakeWebSocket()
        let (client, _, _) = try await makeClient(sockets: [socket])

        // Single-consumer stream, same sentinel pattern as the dedup test:
        // once the sentinel arrives, the revocation frame pushed before it has
        // definitely been processed.
        let collector = Task { () -> EventSubRevocation? in
            var seen: EventSubRevocation?
            for await event in client.events {
                if case .revocation(let revocation) = event { seen = revocation }
                if case .unknown(let type, _) = event, type == "test.event.sentinel" { break }
            }
            return seen
        }

        try await connectDeliveringWelcome(
            client,
            via: socket,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        socket.push(text: revocationJSON(messageId: "revoke-1", subscriptionId: "sub-1", type: "channel.follow"))
        socket.push(text: notificationJSON(messageId: "sentinel-1", type: "test.event.sentinel"))

        let revocation = await collector.value
        XCTAssertEqual(revocation?.id, "sub-1")
        XCTAssertEqual(revocation?.type, "channel.follow")
        XCTAssertEqual(revocation?.status, .authorizationRevoked)
        XCTAssertEqual(revocation?.condition, ["broadcaster_user_id": "b"])

        await client.disconnect()
    }

    // MARK: - 8. A revoked subscription is not re-created after reconnecting

    func test_revokedSubscriptionIsNotRecreatedAfterReconnect() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()

        // HTTP script: only the initial create. A re-create after the
        // reconnect would drain the queue and show up as an extra request.
        let (client, _, transport) = try await makeClient(
            sockets: [socketA, socketB],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1")),
            ]
        )

        let collector = Task { () -> EventSubRevocation? in
            var seen: EventSubRevocation?
            for await event in client.events {
                if case .revocation(let revocation) = event { seen = revocation }
                if case .unknown(let type, _) = event, type == "test.event.sentinel" { break }
            }
            return seen
        }

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        socketA.push(text: revocationJSON(messageId: "revoke-1", subscriptionId: "sub-1", type: "channel.follow"))
        socketA.push(text: notificationJSON(messageId: "sentinel-1", type: "test.event.sentinel"))
        let revocation = await collector.value
        XCTAssertEqual(revocation?.id, "sub-1")

        socketA.failReceive(with: HelixError.networkError("socket dropped"))
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "the ladder should dial socketB and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        // Settle window: a client that still wanted the revoked subscription
        // would POST it again on the new session.
        try await Task.sleep(for: .milliseconds(300))

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1, "a revoked subscription must not be re-created on reconnect")

        await client.disconnect()
    }

    // MARK: - 9. A rejected re-create is dropped instead of wedging the ladder

    func test_permanentResubscribeFailureIsReportedAndDoesNotBlockOthers() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()

        // HTTP script: two initial creates on session-1, then the reconnect
        // round on session-2 where the first re-create is rejected with a 403
        // and the second succeeds. Set order decides which subscription draws
        // the 403, so assertions read it back from the recorded request. A
        // ladder that retries the rejected create drains the queue and shows
        // up as request-count drift.
        let (client, _, transport) = try await makeClient(
            sockets: [socketA, socketB],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1")),
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-2", type: "channel.subscribe", sessionId: "session-1")),
                .json(statusCode: 403, body: #"{"error":"Forbidden","status":403,"message":"subscription missing proper authorization"}"#),
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-3", type: "channel.follow", sessionId: "session-2")),
            ]
        )

        let collector = Task { () -> [(EventSubSubscription, HelixError)] in
            var failures: [(EventSubSubscription, HelixError)] = []
            for await event in client.events {
                if case .subscriptionFailed(let subscription, let error) = event {
                    failures.append((subscription, error))
                }
                if case .unknown(let type, _) = event, type == "test.event.sentinel" { break }
            }
            return failures
        }

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        try await client.subscribe(
            type: "channel.subscribe",
            version: "1",
            condition: ["broadcaster_user_id": "b"]
        )

        socketA.failReceive(with: HelixError.networkError("socket dropped"))
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "the ladder should dial socketB and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        var attempts = 0
        while await transport.recordedRequests().count < 4, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }
        // Settle window: a ladder that treats the 403 as retryable keeps
        // POSTing the rejected subscription.
        try await Task.sleep(for: .milliseconds(300))

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 4, "the rejected subscription must not be retried, and the other must still be re-created")

        socketB.push(text: notificationJSON(messageId: "sentinel-1", type: "test.event.sentinel"))
        let failures = await collector.value
        XCTAssertEqual(failures.count, 1)
        let rejectedBody = try XCTUnwrap(requests[2].httpBody)
        let rejectedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: rejectedBody) as? [String: Any])
        XCTAssertEqual(failures.first?.0.type, rejectedObject["type"] as? String)
        guard case .forbidden(let apiError)? = failures.first?.1 else {
            return XCTFail("Expected forbidden, got \(String(describing: failures.first?.1))")
        }
        XCTAssertEqual(apiError.message, "subscription missing proper authorization")

        await client.disconnect()
    }

    func test_permanentSubscriptionFailureClassification() {
        func apiError(_ status: Int, _ message: String) -> TwitchAPIError {
            TwitchAPIError(error: "Error", status: status, message: message)
        }

        XCTAssertTrue(EventSubClient.isPermanentSubscriptionFailure(.forbidden(apiError(403, "subscription missing proper authorization"))))
        XCTAssertTrue(EventSubClient.isPermanentSubscriptionFailure(.badRequest(apiError(400, "invalid version"))))
        XCTAssertTrue(EventSubClient.isPermanentSubscriptionFailure(.unauthorized(apiError(401, "Missing scope: moderator:read:followers"))))
        XCTAssertFalse(EventSubClient.isPermanentSubscriptionFailure(.badRequest(apiError(400, "websocket transport session does not exist or has already disconnected"))))
        XCTAssertFalse(EventSubClient.isPermanentSubscriptionFailure(.unauthorized(apiError(401, "Invalid OAuth token"))))
        XCTAssertFalse(EventSubClient.isPermanentSubscriptionFailure(.unauthorized(nil)))
        XCTAssertFalse(EventSubClient.isPermanentSubscriptionFailure(.serverError(status: 500)))
        XCTAssertFalse(EventSubClient.isPermanentSubscriptionFailure(.rateLimited(HelixRateLimit())))
        XCTAssertFalse(EventSubClient.isPermanentSubscriptionFailure(.networkError("offline")))
    }

    // MARK: - 10. unsubscribe(id:) with the id subscribe() returned, after a reconnect

    func test_unsubscribeWithOriginalIDAfterReconnectDeletesLiveRecord() async throws {
        let socketA = FakeWebSocket()
        let socketB = FakeWebSocket()

        // HTTP script: initial create (sub-1) on session-1, the re-create
        // (sub-3) on session-2, then the unsubscribe's DELETEs: the original
        // id is already gone (404) and the live re-created record is deleted.
        let (client, _, transport) = try await makeClient(
            sockets: [socketA, socketB],
            responses: [
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-1", type: "channel.follow", sessionId: "session-1")),
                .json(statusCode: 202, body: subscriptionRecordJSON(id: "sub-3", type: "channel.follow", sessionId: "session-2")),
                .json(statusCode: 404, body: #"{"error":"Not Found","status":404,"message":"subscription not found"}"#),
                .json(statusCode: 204, body: ""),
            ]
        )

        try await connectDeliveringWelcome(
            client,
            via: socketA,
            welcomeText: welcomeJSON(messageId: "welcome-1", sessionId: "session-1")
        )
        let record = try await client.subscribe(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": "b", "moderator_user_id": "m"]
        )
        XCTAssertEqual(record.id, "sub-1")

        socketA.failReceive(with: HelixError.networkError("socket dropped"))
        let parked = await pollWelcomeWaiter(on: client)
        XCTAssertTrue(parked, "the ladder should dial socketB and wait for its welcome")
        guard parked else {
            await client.disconnect()
            return
        }
        socketB.push(text: welcomeJSON(messageId: "welcome-2", sessionId: "session-2"))

        var attempts = 0
        while await transport.recordedRequests().count < 2, attempts < 1_000 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(100))

        try await client.unsubscribe(id: record.id)

        let requests = await transport.recordedRequests()
        let deletes = requests.filter { $0.httpMethod == "DELETE" }
        XCTAssertEqual(
            deletes.compactMap { $0.url?.query() }.sorted(),
            ["id=sub-1", "id=sub-3"],
            "unsubscribing with the original id must delete the subscription's live re-created record"
        )

        await client.disconnect()
    }
}

// MARK: - Fakes

/// A scripted `EventSubWebSocket`. Tests `push(text:)` frames (queued until
/// the client's receive loop asks) or `failReceive(with:)` to end the loop,
/// and `cancel(with:reason:)` calls are recorded for assertions.
///
/// Lock-protected rather than an actor because the protocol's requirements
/// are synchronous; `@unchecked Sendable` matches MockNetworkPathMonitor's
/// precedent. Single-consumer: at most one receive() may be parked, which
/// matches the client's one-receive-loop-per-socket invariant.
final class FakeWebSocket: EventSubWebSocket, @unchecked Sendable {
    private let lock = NSLock()
    private var queuedResults: [Result<URLSessionWebSocketTask.Message, Error>] = []
    private var pendingReceive: CheckedContinuation<URLSessionWebSocketTask.Message, Error>?
    private var resumeCount = 0
    private var recordedCancels: [URLSessionWebSocketTask.CloseCode] = []

    var didResume: Bool { withLock { resumeCount > 0 } }
    var cancelCloseCodes: [URLSessionWebSocketTask.CloseCode] { withLock { recordedCancels } }
    var wasCancelled: Bool { !cancelCloseCodes.isEmpty }

    func resume() {
        withLock { resumeCount += 1 }
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let parked: CheckedContinuation<URLSessionWebSocketTask.Message, Error>? = withLock {
            recordedCancels.append(closeCode)
            let parked = pendingReceive
            pendingReceive = nil
            return parked
        }
        // A real socket fails its in-flight receive once cancelled; mirroring
        // that keeps the client's receive loop from leaking a parked task.
        parked?.resume(throwing: HelixError.networkError("FakeWebSocket cancelled"))
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URLSessionWebSocketTask.Message, Error>) in
            let queued: Result<URLSessionWebSocketTask.Message, Error>? = withLock {
                guard queuedResults.isEmpty else {
                    return queuedResults.removeFirst()
                }
                precondition(pendingReceive == nil, "FakeWebSocket supports a single parked receive()")
                pendingReceive = continuation
                return nil
            }
            if let queued {
                continuation.resume(with: queued)
            }
        }
    }

    /// Queues a text frame (or resumes a parked receive with it).
    func push(text: String) {
        deliver(.success(.string(text)))
    }

    /// Ends the receive loop the way a dropped connection does.
    func failReceive(with error: Error) {
        deliver(.failure(error))
    }

    private func deliver(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        let parked: CheckedContinuation<URLSessionWebSocketTask.Message, Error>? = withLock {
            if let parked = pendingReceive {
                pendingReceive = nil
                return parked
            }
            queuedResults.append(result)
            return nil
        }
        parked?.resume(with: result)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// Hands out pre-scripted `FakeWebSocket`s in creation order, recording every
/// requested URL. If the script runs out (an unexpected extra connection
/// attempt), it mints a fresh unscripted socket — whose receive() simply
/// parks — instead of crashing the test.
final class FakeSocketFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var scripted: [FakeWebSocket]
    private var urls: [URL] = []

    init(sockets: [FakeWebSocket]) {
        scripted = sockets
    }

    var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func make(_ url: URL) -> any EventSubWebSocket {
        lock.lock()
        defer { lock.unlock() }
        urls.append(url)
        return scripted.isEmpty ? FakeWebSocket() : scripted.removeFirst()
    }
}

// MARK: - Test helpers

/// Same shape as EventSubLifecycleTests' CompletionFlag: a pollable flag with
/// a deadline, so a regression that re-introduces a hang fails after ~5-10s
/// instead of wedging the whole run.
private actor Flag {
    private var isSet = false

    func mark() { isSet = true }

    func poll(attempts: Int = 500, interval: Duration = .milliseconds(10)) async -> Bool {
        for _ in 0..<attempts {
            if isSet { return true }
            try? await Task.sleep(for: interval)
        }
        return isSet
    }
}

/// Runs `connect()` and delivers `welcomeText` only once the client's welcome
/// wait is actually parked (same yield-poll ordering trick as the lifecycle
/// tests). Welcomes must NOT be pre-queued on the fake: a queued frame is
/// handled the instant the receive loop starts, and the actor gives no
/// ordering guarantee between that hop and the parking of the welcome
/// continuation — a welcome processed before the wait parks would stall
/// connect() into its 15s timeout. A real network's round-trip hides this
/// window; the fake's instant delivery does not.
private func connectDeliveringWelcome(
    _ client: EventSubClient,
    via socket: FakeWebSocket,
    welcomeText: String
) async throws {
    let connectTask = Task { try await client.connect() }
    while await !(client.hasWelcomeWaiterForTesting) {
        await Task.yield()
    }
    socket.push(text: welcomeText)
    try await connectTask.value
}

/// Bounded poll (~10s) for a parked welcome wait — sequences welcome delivery
/// on the reconnect paths, where the wait parks asynchronously (possibly
/// after a backoff sleep) rather than inside a call the test can await.
private func pollWelcomeWaiter(on client: EventSubClient) async -> Bool {
    for _ in 0..<1_000 {
        if await client.hasWelcomeWaiterForTesting { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await client.hasWelcomeWaiterForTesting
}

private func makeClient(
    sockets: [FakeWebSocket],
    responses: [MockHTTPClient.Response] = []
) async throws -> (EventSubClient, FakeSocketFactory, MockHTTPClient) {
    let factory = FakeSocketFactory(sockets: sockets)
    let transport = MockHTTPClient(responses: responses)
    let auth = TwitchAuth(
        oauthClient: TwitchOAuthClient(clientId: "client-id", clientSecret: nil, httpClient: transport),
        tokenStore: InMemoryTokenStore()
    )
    try await auth.setToken(OAuthToken(accessToken: "access-token"))
    let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)
    let client = EventSubClient(
        api: api,
        isLive: { false },
        pathMonitor: MockNetworkPathMonitor(),
        socketFactory: { factory.make($0) }
    )
    return (client, factory, transport)
}

// MARK: - Scripted Twitch frames

private func welcomeJSON(messageId: String, sessionId: String, keepaliveSeconds: Int = 10) -> String {
    """
    {
      "metadata": {
        "message_id": "\(messageId)",
        "message_type": "session_welcome",
        "message_timestamp": "2024-01-01T00:00:00Z"
      },
      "payload": {
        "session": {
          "id": "\(sessionId)",
          "status": "connected",
          "keepalive_timeout_seconds": \(keepaliveSeconds),
          "reconnect_url": null,
          "connected_at": "2024-01-01T00:00:00Z"
        }
      }
    }
    """
}

private func reconnectJSON(messageId: String, reconnectURL: String) -> String {
    """
    {
      "metadata": {
        "message_id": "\(messageId)",
        "message_type": "session_reconnect",
        "message_timestamp": "2024-01-01T00:00:05Z"
      },
      "payload": {
        "session": {
          "id": "session-1",
          "status": "reconnecting",
          "keepalive_timeout_seconds": null,
          "reconnect_url": "\(reconnectURL)",
          "connected_at": "2024-01-01T00:00:00Z"
        }
      }
    }
    """
}

/// A notification with an unrecognized subscription type, which the client
/// surfaces as `.unknown` — perfect for dedup tests since no event model
/// decoding is involved.
private func notificationJSON(messageId: String, type: String) -> String {
    """
    {
      "metadata": {
        "message_id": "\(messageId)",
        "message_type": "notification",
        "message_timestamp": "2024-01-01T00:00:01Z",
        "subscription_type": "\(type)"
      },
      "payload": {
        "event": { "value": 1 }
      }
    }
    """
}

private func revocationJSON(messageId: String, subscriptionId: String, type: String) -> String {
    """
    {
      "metadata": {
        "message_id": "\(messageId)",
        "message_type": "revocation",
        "message_timestamp": "2024-01-01T00:00:02Z",
        "subscription_type": "\(type)"
      },
      "payload": {
        "subscription": {
          "id": "\(subscriptionId)",
          "status": "authorization_revoked",
          "type": "\(type)",
          "version": "2",
          "condition": { "broadcaster_user_id": "b" },
          "transport": { "method": "websocket", "session_id": "session-1" },
          "created_at": "2024-01-01T00:00:00Z",
          "cost": 0
        }
      }
    }
    """
}

private func subscriptionRecordJSON(id: String, type: String, sessionId: String) -> String {
    """
    {
      "data": [
        {
          "id": "\(id)",
          "status": "enabled",
          "type": "\(type)",
          "version": "1",
          "condition": { "broadcaster_user_id": "b" },
          "transport": { "method": "websocket", "session_id": "\(sessionId)" },
          "created_at": "2024-01-01T00:00:00Z",
          "cost": 0
        }
      ]
    }
    """
}
