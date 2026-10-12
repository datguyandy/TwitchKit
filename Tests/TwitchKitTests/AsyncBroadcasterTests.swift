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
