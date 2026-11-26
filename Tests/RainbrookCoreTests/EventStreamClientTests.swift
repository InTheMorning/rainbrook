import Foundation
import XCTest
@testable import RainbrookCore

/// Tests for `EventStreamClient`. The fakes use no network and no clock.
///
/// A test waits for a known condition of a fake, or for the next update. No test
/// waits for a time interval.
final class EventStreamClientTests: XCTestCase {
    private let snapshotURL = URL(string: "https://relay.example.com/v1/liveitems/abc/display")!
    private let streamURL = URL(string: "https://relay.example.com/v1/liveitems/abc/display/events")!
    private let firstBody = Data("{\"title\":\"one\"}".utf8)
    private let secondBody = Data("{\"title\":\"two\"}".utf8)

    private let metadataURL = URL(string: "https://relay.example.com/v1/liveitems/abc/metadata")!
    private let valueStreamURL = URL(string: "https://relay.example.com/v1/liveitems/abc/events")!

    private func makeClient(fetcher: FakeFetcher, opener: FakeOpener, sleeper: FakeSleeper) -> EventStreamClient {
        EventStreamClient(
            snapshotURL: snapshotURL, streamURL: streamURL, eventName: "display",
            opener: opener, fetcher: fetcher, sleep: sleeper.function
        )
    }

    /// A client with the settings of the live value client (ADR 0018).
    private func makeValueClient(
        fetcher: FakeFetcher, opener: FakeOpener, replayCount: Int = 8,
        continueCodes: Set<String> = ["metadata_not_found"]
    ) -> EventStreamClient {
        EventStreamClient(
            snapshotURL: metadataURL, streamURL: valueStreamURL, eventName: "remoteValue",
            replayCount: replayCount, continueCodes: continueCodes,
            opener: opener, fetcher: fetcher, sleep: FakeSleeper(.suspend).function
        )
    }

    // MARK: - First attempt

    func testFirstUpdatesAreConnectingSnapshotLive() async {
        let fetcher = FakeFetcher([.response(200, firstBody)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))

        var updates = await client.start().makeAsyncIterator()

        let first = await updates.next()
        let second = await updates.next()
        let third = await updates.next()
        XCTAssertEqual(first, .status(.connecting))
        XCTAssertEqual(second, .snapshot(firstBody))
        XCTAssertEqual(third, .status(.live))
        await client.stop()
    }

    func testDisplayEventGivesEventAndOtherEventNameGivesNothing() async {
        let fetcher = FakeFetcher([.response(200, firstBody)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await opener.send(["event: other", "data: ignored", "", "event: display", "id: 7", "data: {\"a\":1}", ""], to: 0)

        let update = await updates.next()
        XCTAssertEqual(update, .event(ServerSentEvent(event: "display", id: "7", data: "{\"a\":1}")))
        await client.stop()
        let next = await updates.next()
        XCTAssertEqual(next, .status(.stopped(.requested)), "The other event must give no update.")
    }

    // MARK: - Reconnection

    func testStreamEndWaitsOneSecondThenFetchesAndOpensWithLastEventID() async {
        let fetcher = FakeFetcher([.response(200, firstBody), .response(200, secondBody)])
        let opener = FakeOpener([.stream(status: 200), .stream(status: 200)])
        let sleeper = FakeSleeper(.suspendOnly(.seconds(35)))
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: sleeper)
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await opener.send(["id: 42", "event: display", "data: x", ""], to: 0)
        _ = await updates.next()
        await opener.finish(0)

        let received = await take(4, from: &updates)
        XCTAssertEqual(received, [
            .status(.waiting(seconds: 1)), .status(.connecting), .snapshot(secondBody), .status(.live)
        ])
        let backoffRequests = await sleeper.requests.filter { $0 != .seconds(35) }
        XCTAssertEqual(backoffRequests, [.seconds(1)])
        let fetchCount = await fetcher.callCount
        XCTAssertEqual(fetchCount, 2)
        let lastEventIDs = await opener.lastEventIDs
        XCTAssertEqual(lastEventIDs, [nil, "42"])
        await client.stop()
    }

    func testFailingSnapshotWaitsGrowToThirtySeconds() async {
        let fetcher = FakeFetcher([], whenEmpty: .failure)
        let sleeper = FakeSleeper(.immediate)
        let client = makeClient(fetcher: fetcher, opener: FakeOpener([]), sleeper: sleeper)
        var updates = await client.start().makeAsyncIterator()

        let waits = await takeWaits(7, from: &updates)
        await client.stop()

        XCTAssertEqual(waits, [1, 2, 4, 8, 16, 30, 30])
        let requests = await sleeper.requests
        XCTAssertEqual(Array(requests.prefix(7)), [1, 2, 4, 8, 16, 30, 30].map { Duration.seconds($0) })
    }

    func testGoodSnapshotAfterFailuresResetsNextWaitToOneSecond() async {
        let fetcher = FakeFetcher(
            [.failure, .response(503, Data()), .failure, .response(200, firstBody)], whenEmpty: .suspend
        )
        let opener = FakeOpener([.failure])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.immediate))
        var updates = await client.start().makeAsyncIterator()

        let waits = await takeWaits(4, from: &updates)
        await client.stop()

        XCTAssertEqual(waits, [1, 2, 4, 1])
    }

    // MARK: - Watchdog

    func testSilentStreamCausesWatchdogRequestThenNewAttempt() async {
        let fetcher = FakeFetcher([.response(200, firstBody), .response(200, secondBody)])
        let opener = FakeOpener([.stream(status: 200), .stream(status: 200)])
        let sleeper = FakeSleeper(.suspend)
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: sleeper)
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await sleeper.waitUntil { $0.requests.count >= 1 }
        let watchdogRequest = await sleeper.requests[0]
        XCTAssertEqual(watchdogRequest, .seconds(35))
        await sleeper.resume(0)

        let waiting = await updates.next()
        XCTAssertEqual(waiting, .status(.waiting(seconds: 1)))
        await opener.waitUntil { $0.closed.contains(0) }
        await sleeper.waitUntil { $0.requests.count >= 2 }
        await sleeper.resume(1)

        let received = await take(3, from: &updates)
        XCTAssertEqual(received, [.status(.connecting), .snapshot(secondBody), .status(.live)])
        let fetchCount = await fetcher.callCount
        XCTAssertEqual(fetchCount, 2)
        await client.stop()
    }

    func testCommentLineBeforeWatchdogEndsGivesNoNewAttempt() async {
        let fetcher = FakeFetcher([.response(200, firstBody)], whenEmpty: .suspend)
        let opener = FakeOpener([.stream(status: 200)])
        let sleeper = FakeSleeper(.suspend)
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: sleeper)
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)
        await sleeper.waitUntil { $0.requests.count >= 1 }

        await opener.send([": keep-alive"], to: 0)

        // The client cancels the first watchdog sleep and starts a second one.
        await sleeper.waitUntil { $0.requests.count >= 2 }
        let requests = await sleeper.requests
        XCTAssertEqual(requests, [.seconds(35), .seconds(35)])
        let firstCanceled = await sleeper.canceled.contains(0)
        XCTAssertTrue(firstCanceled)
        let fetchCount = await fetcher.callCount
        XCTAssertEqual(fetchCount, 1)
        let openCount = await opener.lastEventIDs.count
        XCTAssertEqual(openCount, 1)
        let closed = await opener.closed
        XCTAssertTrue(closed.isEmpty)

        await client.stop()
        let next = await updates.next()
        XCTAssertEqual(next, .status(.stopped(.requested)))
    }

    // MARK: - Stop reasons

    func testSnapshotNotFoundStopsAndFinishes() async {
        await assertSnapshotStatus(404, stops: .notFound)
    }

    func testSnapshotConflictStopsWithNotReserved() async {
        await assertSnapshotStatus(409, stops: .notReserved)
    }

    func testStreamConflictStopsAndClosesTheLineStream() async {
        let fetcher = FakeFetcher([.response(200, firstBody)])
        let opener = FakeOpener([.stream(status: 409)])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))
        var updates = await client.start().makeAsyncIterator()

        let received = await take(4, from: &updates)
        XCTAssertEqual(received, [.status(.connecting), .snapshot(firstBody), .status(.stopped(.notReserved))])
        await opener.waitUntil { $0.closed.contains(0) }
    }

    // MARK: - Metadata snapshot and replay on connect (ADR 0018)

    func testSnapshotIsReadFromTheGivenURLAndSentAsSnapshot() async {
        let body = Data(#"{"event_id":"abc","seq":45,"metadata":{}}"#.utf8)
        let fetcher = FakeFetcher([.response(200, body)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeValueClient(fetcher: fetcher, opener: opener)
        var updates = await client.start().makeAsyncIterator()

        let received = await take(3, from: &updates)

        XCTAssertEqual(received, [.status(.connecting), .snapshot(body), .status(.live)])
        let urls = await fetcher.urls
        XCTAssertEqual(urls, [metadataURL])
        await client.stop()
    }

    func testMetadataNotFoundInContinueCodesOpensStreamWithNoSnapshotAndNoLastEventID() async {
        let fetcher = FakeFetcher([.response(404, Data(#"{"error":"metadata_not_found"}"#.utf8))])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeValueClient(fetcher: fetcher, opener: opener)
        var updates = await client.start().makeAsyncIterator()

        let received = await take(2, from: &updates)
        await opener.send(["event: remoteValue", "id: 5", "data: {}", ""], to: 0)
        let event = await updates.next()

        XCTAssertEqual(received, [.status(.connecting), .status(.live)])
        XCTAssertEqual(event, .event(ServerSentEvent(event: "remoteValue", id: "5", data: "{}")))
        let lastEventIDs = await opener.lastEventIDs
        XCTAssertEqual(lastEventIDs, [nil])
        await client.stop()
    }

    func testEventNotFoundStopsWithNotFoundWhenMetadataNotFoundIsAContinueCode() async {
        let fetcher = FakeFetcher([.response(404, Data(#"{"error":"event_not_found"}"#.utf8))])
        let opener = FakeOpener([])
        let client = makeValueClient(fetcher: fetcher, opener: opener)
        var updates = await client.start().makeAsyncIterator()

        let received = await take(3, from: &updates)

        XCTAssertEqual(received, [.status(.connecting), .status(.stopped(.notFound))])
        let openCount = await opener.lastEventIDs.count
        XCTAssertEqual(openCount, 0)
    }

    func testMetadataNotFoundWithNoContinueCodesStops() async {
        let fetcher = FakeFetcher([.response(404, Data(#"{"error":"metadata_not_found"}"#.utf8))])
        let opener = FakeOpener([])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))
        var updates = await client.start().makeAsyncIterator()

        let received = await take(3, from: &updates)

        XCTAssertEqual(received, [.status(.connecting), .status(.stopped(.notFound))])
        let openCount = await opener.lastEventIDs.count
        XCTAssertEqual(openCount, 0)
    }

    func testSeqTwentyAndReplayCountEightReplaysThroughTwenty() async {
        let body = Data(#"{"event_id":"abc","seq":20,"metadata":{}}"#.utf8)
        let fetcher = FakeFetcher([.response(200, body)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeValueClient(fetcher: fetcher, opener: opener)
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await opener.send([
            "event: remoteValue", "id: 13", "data: a", "",
            "event: remoteValue", "id: 20", "data: b", "",
            "event: remoteValue", "id: 21", "data: c", "",
        ], to: 0)
        let received = await take(3, from: &updates)

        XCTAssertEqual(received, [
            .replay(ServerSentEvent(event: "remoteValue", id: "13", data: "a")),
            .replay(ServerSentEvent(event: "remoteValue", id: "20", data: "b")),
            .event(ServerSentEvent(event: "remoteValue", id: "21", data: "c")),
        ])
        let lastEventIDs = await opener.lastEventIDs
        XCTAssertEqual(lastEventIDs, ["12"])
        await client.stop()
    }

    func testSeqThreeAndReplayCountEightSendsLastEventIDZero() async {
        let body = Data(#"{"event_id":"abc","seq":3,"metadata":{}}"#.utf8)
        let fetcher = FakeFetcher([.response(200, body)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeValueClient(fetcher: fetcher, opener: opener)
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        let lastEventIDs = await opener.lastEventIDs
        XCTAssertEqual(lastEventIDs, ["0"])
        await client.stop()
    }

    func testSnapshotWithNoSeqSendsNoLastEventIDAndEachEventIsEvent() async {
        let body = Data(#"{"track":null}"#.utf8)
        let fetcher = FakeFetcher([.response(200, body)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeValueClient(fetcher: fetcher, opener: opener)
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await opener.send(["event: remoteValue", "id: 1", "data: a", ""], to: 0)
        let event = await updates.next()

        XCTAssertEqual(event, .event(ServerSentEvent(event: "remoteValue", id: "1", data: "a")))
        let lastEventIDs = await opener.lastEventIDs
        XCTAssertEqual(lastEventIDs, [nil])
        await client.stop()
    }

    func testReconnectAfterEventTwentyOneSendsItsIDAndGivesNoReplay() async {
        let body = Data(#"{"event_id":"abc","seq":20,"metadata":{}}"#.utf8)
        let laterBody = Data(#"{"event_id":"abc","seq":22,"metadata":{}}"#.utf8)
        let fetcher = FakeFetcher([.response(200, body), .response(200, laterBody)])
        let opener = FakeOpener([.stream(status: 200), .stream(status: 200)])
        let sleeper = FakeSleeper(.suspendOnly(.seconds(35)))
        let client = EventStreamClient(
            snapshotURL: metadataURL, streamURL: valueStreamURL, eventName: "remoteValue",
            replayCount: 8, continueCodes: ["metadata_not_found"],
            opener: opener, fetcher: fetcher, sleep: sleeper.function
        )
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await opener.send(["event: remoteValue", "id: 21", "data: c", ""], to: 0)
        _ = await updates.next()
        await opener.finish(0)
        let reconnect = await take(4, from: &updates)
        await opener.send(["event: remoteValue", "id: 22", "data: d", ""], to: 1)
        let event = await updates.next()

        XCTAssertEqual(reconnect, [
            .status(.waiting(seconds: 1)), .status(.connecting), .snapshot(laterBody), .status(.live)
        ])
        XCTAssertEqual(event, .event(ServerSentEvent(event: "remoteValue", id: "22", data: "d")))
        let lastEventIDs = await opener.lastEventIDs
        XCTAssertEqual(lastEventIDs, ["12", "21"])
        await client.stop()
    }

    // MARK: - Network change

    func testNetworkChangedDuringWaitStartsNewAttemptWithNoFurtherWait() async {
        let fetcher = FakeFetcher([.failure, .response(200, firstBody)])
        let opener = FakeOpener([.stream(status: 200)])
        let sleeper = FakeSleeper(.suspend)
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: sleeper)
        var updates = await client.start().makeAsyncIterator()

        let beforeChange = await take(2, from: &updates)
        XCTAssertEqual(beforeChange, [.status(.connecting), .status(.waiting(seconds: 1))])
        await sleeper.waitUntil { $0.requests.count >= 1 }

        await client.networkChanged()

        let afterChange = await take(3, from: &updates)
        XCTAssertEqual(afterChange, [.status(.connecting), .snapshot(firstBody), .status(.live)])
        await sleeper.waitUntil { $0.canceled.contains(0) }
        let backoffRequests = await sleeper.requests.filter { $0 != .seconds(35) }
        XCTAssertEqual(backoffRequests, [.seconds(1)])
        await client.stop()
    }

    // MARK: - Stop and start

    func testStopSendsStoppedFinishesAndClosesTheOpenStream() async {
        let fetcher = FakeFetcher([.response(200, firstBody)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))
        var updates = await client.start().makeAsyncIterator()
        await skip(3, of: &updates)

        await client.stop()

        let received = await take(2, from: &updates)
        XCTAssertEqual(received, [.status(.stopped(.requested))])
        await opener.waitUntil { $0.closed.contains(0) }
    }

    func testCanceledConsumerStopsTheClientAndClosesTheOpenStream() async {
        let fetcher = FakeFetcher([.response(200, firstBody)])
        let opener = FakeOpener([.stream(status: 200)])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))
        let updates = await client.start()
        let consumer = Task {
            var count = 0
            for await _ in updates { count += 1 }
            return count
        }
        await opener.waitUntil { $0.lastEventIDs.count == 1 }

        consumer.cancel()

        await opener.waitUntil { $0.closed.contains(0) }
    }

    func testSecondStartGivesStreamThatFinishesAtOnce() async {
        let fetcher = FakeFetcher([], whenEmpty: .suspend)
        let client = makeClient(fetcher: fetcher, opener: FakeOpener([]), sleeper: FakeSleeper(.suspend))
        _ = await client.start()

        var second = await client.start().makeAsyncIterator()

        let update = await second.next()
        XCTAssertNil(update)
        await client.stop()
    }

    // MARK: - Helpers

    private func assertSnapshotStatus(
        _ status: Int, stops reason: EventStreamStopReason, file: StaticString = #filePath, line: UInt = #line
    ) async {
        let fetcher = FakeFetcher([.response(status, Data())])
        let opener = FakeOpener([])
        let client = makeClient(fetcher: fetcher, opener: opener, sleeper: FakeSleeper(.suspend))
        var updates = await client.start().makeAsyncIterator()

        let received = await take(3, from: &updates)

        XCTAssertEqual(received, [.status(.connecting), .status(.stopped(reason))], file: file, line: line)
        let openCount = await opener.lastEventIDs.count
        XCTAssertEqual(openCount, 0, file: file, line: line)
    }

    /// Gives at most `count` updates. The array is shorter if the update stream finishes.
    private func take(
        _ count: Int, from updates: inout AsyncStream<EventStreamUpdate>.Iterator
    ) async -> [EventStreamUpdate] {
        var result: [EventStreamUpdate] = []
        while result.count < count, let update = await updates.next() {
            result.append(update)
        }
        return result
    }

    private func skip(_ count: Int, of updates: inout AsyncStream<EventStreamUpdate>.Iterator) async {
        _ = await take(count, from: &updates)
    }

    /// Gives the seconds of the first `count` waiting statuses.
    private func takeWaits(_ count: Int, from updates: inout AsyncStream<EventStreamUpdate>.Iterator) async -> [Int] {
        var waits: [Int] = []
        while waits.count < count, let update = await updates.next() {
            if case .status(.waiting(let seconds)) = update {
                waits.append(seconds)
            }
        }
        return waits
    }
}

private struct FakeError: Error {}

/// Suspends until the task is canceled. It uses no clock.
private func suspendUntilCanceled() async {
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    for await _ in stream {}
    withExtendedLifetime(continuation) {}
}

/// A fake snapshot source. It gives its results in sequence and counts the calls.
private actor FakeFetcher: SnapshotFetching {
    enum Result {
        case response(Int, Data)
        case failure
        case suspend
    }

    private var results: [Result]
    private let whenEmpty: Result
    private(set) var callCount = 0
    private(set) var urls: [URL] = []

    init(_ results: [Result], whenEmpty: Result = .suspend) {
        self.results = results
        self.whenEmpty = whenEmpty
    }

    func fetch(_ url: URL) async throws -> (status: Int, body: Data) {
        callCount += 1
        urls.append(url)
        let result = results.isEmpty ? whenEmpty : results.removeFirst()
        switch result {
        case .response(let status, let body):
            return (status, body)
        case .failure:
            throw FakeError()
        case .suspend:
            await suspendUntilCanceled()
            throw CancellationError()
        }
    }
}

/// A fake stream source. It gives its responses in sequence and records each
/// last event ID. The test writes the lines, and the fake records each close.
private actor FakeOpener: LineStreamOpening {
    enum Plan {
        case stream(status: Int)
        case failure
    }

    private var plans: [Plan]
    private var feeds: [AsyncThrowingStream<String, Error>.Continuation] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var lastEventIDs: [String?] = []
    private(set) var closed: Set<Int> = []

    init(_ plans: [Plan]) {
        self.plans = plans
    }

    func open(_ url: URL, lastEventID: String?) async throws -> LineStreamResponse {
        lastEventIDs.append(lastEventID)
        let plan = plans.isEmpty ? .failure : plans.removeFirst()
        guard case .stream(let status) = plan else { throw FakeError() }
        let index = feeds.count
        let (lines, feed) = AsyncThrowingStream.makeStream(of: String.self)
        feed.onTermination = { _ in
            Task { await self.markClosed(index) }
        }
        feeds.append(feed)
        changed()
        return LineStreamResponse(status: status, lines: lines)
    }

    func send(_ lines: [String], to index: Int) {
        for line in lines {
            feeds[index].yield(line)
        }
    }

    func finish(_ index: Int) {
        feeds[index].finish()
    }

    func waitUntil(_ condition: @Sendable (isolated FakeOpener) -> Bool) async {
        while !condition(self) {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    private func markClosed(_ index: Int) {
        closed.insert(index)
        changed()
    }

    private func changed() {
        let ready = waiters
        waiters.removeAll()
        ready.forEach { $0.resume() }
    }
}

/// A fake sleep function. It records each requested time.
///
/// A suspended sleep ends when the test resumes it, or when its task is canceled.
private actor FakeSleeper {
    enum Mode {
        case immediate
        case suspend
        case suspendOnly(Duration)
    }

    private let mode: Mode
    private var pending: [Int: CheckedContinuation<Void, Error>] = [:]
    private var resumedEarly: Set<Int> = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var requests: [Duration] = []
    private(set) var canceled: Set<Int> = []

    init(_ mode: Mode) {
        self.mode = mode
    }

    nonisolated var function: @Sendable (Duration) async throws -> Void {
        { duration in try await self.sleep(duration) }
    }

    func resume(_ index: Int) {
        if let continuation = pending.removeValue(forKey: index) {
            continuation.resume()
        } else {
            resumedEarly.insert(index)
        }
    }

    func waitUntil(_ condition: @Sendable (isolated FakeSleeper) -> Bool) async {
        while !condition(self) {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    private func sleep(_ duration: Duration) async throws {
        let index = requests.count
        requests.append(duration)
        changed()
        guard shouldSuspend(duration) else {
            try Task.checkCancellation()
            return
        }
        try await withTaskCancellationHandler {
            try await self.suspend(index)
        } onCancel: {
            Task { await self.cancel(index) }
        }
    }

    private func suspend(_ index: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if canceled.contains(index) {
                continuation.resume(throwing: CancellationError())
            } else if resumedEarly.contains(index) {
                continuation.resume()
            } else {
                pending[index] = continuation
            }
        }
    }

    private func shouldSuspend(_ duration: Duration) -> Bool {
        switch mode {
        case .immediate:
            return false
        case .suspend:
            return true
        case .suspendOnly(let suspended):
            return duration == suspended
        }
    }

    private func cancel(_ index: Int) {
        canceled.insert(index)
        pending.removeValue(forKey: index)?.resume(throwing: CancellationError())
        changed()
    }

    private func changed() {
        let ready = waiters
        waiters.removeAll()
        ready.forEach { $0.resume() }
    }
}
