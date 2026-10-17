import Foundation
import XCTest
@testable import TwitchKit

final class AsyncBroadcasterTests: XCTestCase {
    private func makeBroadcaster(
        backlog: AsyncStream<Int>.Continuation.BufferingPolicy = .unbounded,
        replaysLatest: Bool = false
    ) -> AsyncBroadcaster<Int> {
        AsyncBroadcaster(bufferingPolicy: .unbounded, backlogPolicy: backlog, replaysLatest: replaysLatest)
    }

    /// Collects up to `count` values, giving up after the stream ends.
    private func collect(_ stream: AsyncStream<Int>, count: Int) async -> [Int] {
        var values: [Int] = []
        for await value in stream {
            values.append(value)
            if values.count == count { break }
        }
        return values
    }

    func testEveryConsumerReceivesEveryValue() async {
        let broadcaster = makeBroadcaster()
        let first = broadcaster.makeStream()
        let second = broadcaster.makeStream()

        broadcaster.yield(1)
        broadcaster.yield(2)

        let firstValues = await collect(first, count: 2)
        let secondValues = await collect(second, count: 2)
        XCTAssertEqual(firstValues, [1, 2])
        XCTAssertEqual(secondValues, [1, 2])
    }

    func testCancelledConsumerDoesNotEndDeliveryForOthers() async {
        let broadcaster = makeBroadcaster()
        let survivor = broadcaster.makeStream()

        let cancelled = Task {
            for await _ in broadcaster.makeStream() {}
        }
        // Bounded waits: until the second consumer registers, then until its
        // cancellation has unregistered it.
        for _ in 0..<10_000 where broadcaster.consumerCount < 2 {
            await Task.yield()
        }
        XCTAssertEqual(broadcaster.consumerCount, 2)
        cancelled.cancel()
        await cancelled.value
        for _ in 0..<10_000 where broadcaster.consumerCount > 1 {
            await Task.yield()
        }
        XCTAssertEqual(broadcaster.consumerCount, 1)

        broadcaster.yield(1)
        let later = broadcaster.makeStream()
        broadcaster.yield(2)

        let survivorValues = await collect(survivor, count: 2)
        let laterValues = await collect(later, count: 1)
        XCTAssertEqual(survivorValues, [1, 2])
        XCTAssertEqual(laterValues, [2])
    }

    func testValuesSentWithNoConsumerGoToTheNextConsumer() async {
        let broadcaster = makeBroadcaster(backlog: .bufferingNewest(2))

        broadcaster.yield(1)
        broadcaster.yield(2)
        broadcaster.yield(3)
        let stream = broadcaster.makeStream()
        broadcaster.yield(4)

        let values = await collect(stream, count: 3)
        XCTAssertEqual(values, [2, 3, 4], "the backlog keeps only the newest values its policy allows")
    }

    func testLateConsumerStartsWithLatestValueWhenReplaying() async {
        let broadcaster = makeBroadcaster(backlog: .bufferingNewest(8), replaysLatest: true)
        let early = broadcaster.makeStream()

        broadcaster.yield(1)
        broadcaster.yield(2)
        let late = broadcaster.makeStream()
        broadcaster.yield(3)

        let earlyValues = await collect(early, count: 3)
        let lateValues = await collect(late, count: 2)
        XCTAssertEqual(earlyValues, [1, 2, 3])
        XCTAssertEqual(lateValues, [2, 3])
        XCTAssertEqual(broadcaster.latestValue, 3)
    }

    func testFilteredConsumerReceivesOnlyWhatItWants() async {
        let broadcaster = makeBroadcaster()
        let evens = broadcaster.makeStream { $0 % 2 == 0 ? $0 : nil }
        let all = broadcaster.makeStream()

        for value in 1...4 {
            broadcaster.yield(value)
        }

        let evenValues = await collect(evens, count: 2)
        let allValues = await collect(all, count: 4)
        XCTAssertEqual(evenValues, [2, 4])
        XCTAssertEqual(allValues, [1, 2, 3, 4])
    }

    func testUnwantedValuesAreNotKeptWhileAConsumerExists() async {
        let broadcaster = makeBroadcaster(backlog: .bufferingNewest(10))
        // Only odd values have a taker; even ones nobody wants.
        let odds = broadcaster.makeStream { $0 % 2 == 1 ? $0 : nil }

        for value in 1...4 {
            broadcaster.yield(value)
        }
        // A later consumer starts with what is sent after it exists: 2 and 4
        // were sent while a consumer existed, so they weren't kept for it.
        let evens = broadcaster.makeStream { $0 % 2 == 0 ? $0 : nil }
        broadcaster.yield(6)

        let oddValues = await collect(odds, count: 2)
        let evenValues = await collect(evens, count: 1)
        XCTAssertEqual(oddValues, [1, 3])
        XCTAssertEqual(evenValues, [6])
    }

    func testStreamThatDoesNotReplayTheBacklogStartsWithNewValues() async {
        let broadcaster = makeBroadcaster(backlog: .bufferingNewest(10))
        broadcaster.yield(1)
        broadcaster.yield(2)

        let filtered = broadcaster.makeStream(replayingBacklog: false) { $0 }
        broadcaster.yield(3)

        let values = await collect(filtered, count: 1)
        XCTAssertEqual(values, [3], "a filtered stream must not receive values sent before it existed")
    }

    func testBacklogEndsWhenAnyConsumerRegisters() async {
        let broadcaster = makeBroadcaster(backlog: .bufferingNewest(10))
        broadcaster.yield(1)

        let filtered = broadcaster.makeStream(replayingBacklog: false) { $0 }
        let later = broadcaster.makeStream()
        broadcaster.yield(2)

        let filteredValues = await collect(filtered, count: 1)
        let laterValues = await collect(later, count: 1)
        XCTAssertEqual(filteredValues, [2])
        XCTAssertEqual(laterValues, [2], "the backlog belongs to the first consumer, replayed or not")
    }

    func testBacklogDropsValuesOlderThanTheMaximumAge() async {
        let clock = TestClock()
        let broadcaster = AsyncBroadcaster<Int>(
            bufferingPolicy: .unbounded,
            backlogPolicy: .unbounded,
            replaysLatest: false,
            maximumBacklogAge: .seconds(30),
            now: { clock.now }
        )

        broadcaster.yield(1)
        clock.advance(by: .seconds(20))
        broadcaster.yield(2)
        clock.advance(by: .seconds(15))   // 1 is 35s old, 2 is 15s old
        let stream = broadcaster.makeStream()
        broadcaster.yield(3)

        let values = await collect(stream, count: 2)
        XCTAssertEqual(values, [2, 3])
    }

    func testFinishEndsStreamsAndLaterStreamsFinishImmediately() async {
        let broadcaster = makeBroadcaster()
        let stream = broadcaster.makeStream()

        broadcaster.yield(1)
        broadcaster.finish()
        broadcaster.yield(2)

        var values: [Int] = []
        for await value in stream {
            values.append(value)
        }
        XCTAssertEqual(values, [1])

        var lateValues: [Int] = []
        for await value in broadcaster.makeStream() {
            lateValues.append(value)
        }
        XCTAssertEqual(lateValues, [])
        XCTAssertEqual(broadcaster.consumerCount, 0)
    }
}

/// A manually advanced clock reading for backlog-age tests.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = ContinuousClock.now

    var now: ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by duration: Duration) {
        lock.lock()
        defer { lock.unlock() }
        current = current.advanced(by: duration)
    }
}
