import Foundation

/// One HTTP response with a body of text lines.
public struct LineStreamResponse: Sendable {
    public let status: Int
    public let lines: AsyncThrowingStream<String, Error>

    public init(status: Int, lines: AsyncThrowingStream<String, Error>) {
        self.status = status
        self.lines = lines
    }
}

public protocol LineStreamOpening: Sendable {
    /// Sends GET with Accept: text/event-stream and, if not nil, Last-Event-ID.
    func open(_ url: URL, lastEventID: String?) async throws -> LineStreamResponse
}

public protocol SnapshotFetching: Sendable {
    /// Sends GET and gives the status and the body.
    func fetch(_ url: URL) async throws -> (status: Int, body: Data)
}

public enum EventStreamStopReason: Equatable, Sendable {
    case requested, notFound, notReserved
}

public enum EventStreamStatus: Equatable, Sendable {
    case connecting
    case live
    case waiting(seconds: Int)          // backoff before the next attempt
    case stopped(EventStreamStopReason)
}

public enum EventStreamUpdate: Equatable, Sendable {
    case snapshot(Data)                 // apply at once
    case event(ServerSentEvent)         // a streamed event with the configured event name
    /// A streamed event with an id of the snapshot seq or less (ADR 0018 §The replay on connect).
    case replay(ServerSentEvent)
    case status(EventStreamStatus)
}

/// Reads a snapshot, then keeps one server-sent event stream open.
///
/// ADR 0008 §Transport names the attempt sequence, the watchdog and the
/// backoff. ADR 0018 names the snapshot error codes that open the stream, and
/// the replay on connect. This client imports only `Foundation`. The app gives the HTTP
/// transport through `LineStreamOpening` and `SnapshotFetching`.
public actor EventStreamClient {
    public static let backoffSeconds = [1, 2, 4, 8, 16, 30]

    /// The result of one attempt.
    private enum Outcome {
        case retry
        case stop(EventStreamStopReason)
    }

    /// The result of one race between the next line and the watchdog.
    private enum ReadResult: Sendable {
        case line(String)
        case ended
        case timedOut
    }

    private enum State {
        case idle, running, finished
    }

    private let snapshotURL: URL
    private let streamURL: URL
    private let eventName: String
    private let replayCount: Int
    private let continueCodes: Set<String>
    private let opener: any LineStreamOpening
    private let fetcher: any SnapshotFetching
    private let watchdog: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    private var state = State.idle
    private var continuation: AsyncStream<EventStreamUpdate>.Continuation?
    private var runTask: Task<Void, Never>?
    /// The client keeps one parser for its full life, so `lastEventID` stays across attempts.
    private var parser = EventStreamParser()
    private var backoffIndex = 0

    /// replayCount: 0 gives no replay.
    /// continueCodes: the 404 error codes of the snapshot that open the stream with no snapshot.
    public init(
        snapshotURL: URL,
        streamURL: URL,
        eventName: String,
        replayCount: Int = 0,
        continueCodes: Set<String> = [],
        opener: any LineStreamOpening,
        fetcher: any SnapshotFetching,
        watchdog: Duration = .seconds(35),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.snapshotURL = snapshotURL
        self.streamURL = streamURL
        self.eventName = eventName
        self.replayCount = replayCount
        self.continueCodes = continueCodes
        self.opener = opener
        self.fetcher = fetcher
        self.watchdog = watchdog
        self.sleep = sleep
    }

    /// Starts the client one time and gives its updates. A second call gives a stream that finishes at once.
    public func start() -> AsyncStream<EventStreamUpdate> {
        let (stream, continuation) = AsyncStream.makeStream(of: EventStreamUpdate.self)
        guard state == .idle else {
            continuation.finish()
            return stream
        }
        state = .running
        self.continuation = continuation
        // If the consumer stops to read the updates, the client stops and closes its stream.
        continuation.onTermination = { [weak self] termination in
            guard case .cancelled = termination else { return }
            Task { await self?.stop() }
        }
        startRun()
        return stream
    }

    /// Ends a wait or an open stream, and starts a new attempt at once, with no backoff.
    public func networkChanged() {
        guard state == .running else { return }
        startRun()
    }

    /// Stops the client, closes the stream, sends .status(.stopped(.requested)) and finishes the update stream.
    public func stop() {
        guard state == .running else {
            state = .finished
            return
        }
        runTask?.cancel()
        runTask = nil
        finish(.requested)
    }

    // MARK: - Run loop

    /// Cancels the present run task and starts a new run task.
    ///
    /// A canceled run task does not send updates and does not change the
    /// parser or the backoff index. Each of these changes occurs on the actor
    /// after a check of `Task.isCancelled`.
    private func startRun() {
        runTask?.cancel()
        runTask = Task { await self.run() }
    }

    private func run() async {
        while !Task.isCancelled {
            switch await attempt() {
            case .stop(let reason):
                guard !Task.isCancelled else { return }
                runTask = nil
                finish(reason)
                return
            case .retry:
                await waitBeforeNextAttempt()
            }
        }
    }

    private func finish(_ reason: EventStreamStopReason) {
        state = .finished
        continuation?.yield(.status(.stopped(reason)))
        continuation?.finish()
        continuation = nil
    }

    /// Sends an update only from a run task that is not canceled.
    private func send(_ update: EventStreamUpdate) {
        guard !Task.isCancelled else { return }
        continuation?.yield(update)
    }

    private func waitBeforeNextAttempt() async {
        guard !Task.isCancelled else { return }
        let seconds = Self.backoffSeconds[backoffIndex]
        send(.status(.waiting(seconds: seconds)))
        do {
            try await sleep(.seconds(seconds))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        backoffIndex = min(backoffIndex + 1, Self.backoffSeconds.count - 1)
    }

    // MARK: - One attempt

    private func attempt() async -> Outcome {
        send(.status(.connecting))

        let snapshot: (status: Int, body: Data)
        do {
            snapshot = try await fetcher.fetch(snapshotURL)
        } catch {
            return .retry
        }
        guard !Task.isCancelled else { return .retry }
        // ADR 0018: the seq of the snapshot belongs to this attempt only.
        var snapshotSeq: Int?
        switch snapshot.status {
        case 200:
            send(.snapshot(snapshot.body))
            backoffIndex = 0
            snapshotSeq = Self.seq(in: snapshot.body)
        case 404:
            // ADR 0018 §The value snapshot: a code in continueCodes opens the stream with no snapshot.
            guard let code = Self.errorCode(in: snapshot.body), continueCodes.contains(code) else {
                return .stop(.notFound)
            }
            backoffIndex = 0
        case 409:
            return .stop(.notReserved)
        default:
            return .retry
        }

        // ADR 0018 §The replay on connect: with no last event ID, ask for the recent updates.
        let lastEventID: String?
        var replayThrough: Int?
        if let parsedID = parser.lastEventID {
            lastEventID = parsedID
        } else if let snapshotSeq, replayCount > 0 {
            lastEventID = String(max(0, snapshotSeq - replayCount))
            replayThrough = snapshotSeq
        } else {
            lastEventID = nil
        }

        let response: LineStreamResponse
        do {
            response = try await opener.open(streamURL, lastEventID: lastEventID)
        } catch {
            return .retry
        }
        let outcome = await readResponse(response, replayThrough: replayThrough)
        await Self.close(response.lines)
        return outcome
    }

    /// Reads the stream until it ends, it fails, or the watchdog fires.
    ///
    /// The caller closes the line stream after this method.
    /// An event with a whole-number id of `replayThrough` or less is sent as `.replay`.
    private func readResponse(_ response: LineStreamResponse, replayThrough: Int?) async -> Outcome {
        guard !Task.isCancelled else { return .retry }
        switch response.status {
        case 200:
            break
        case 404:
            return .stop(.notFound)
        case 409:
            return .stop(.notReserved)
        default:
            return .retry
        }

        send(.status(.live))
        while !Task.isCancelled {
            guard case .line(let line) = await nextLine(from: response.lines), !Task.isCancelled else {
                return .retry
            }
            if let event = parser.feed(line: line), event.event == eventName {
                if let replayThrough, let id = event.id.flatMap({ Int($0) }), id <= replayThrough {
                    send(.replay(event))
                } else {
                    send(.event(event))
                }
            }
        }
        return .retry
    }

    // MARK: - Snapshot body

    /// Gives the top-level whole-number `seq` of a JSON object body, or nil.
    private static func seq(in body: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let number = object["seq"] as? NSNumber,
              String(cString: number.objCType) != "c" else {
            return nil
        }
        // A JSON boolean has the type code `c`. The check above rejects it.
        guard let seq = Int(exactly: number.doubleValue), seq >= 0 else { return nil }
        return seq
    }

    /// Gives the `error` code of a JSON object body, or nil.
    private static func errorCode(in body: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return nil
        }
        return object["error"] as? String
    }

    /// Races the next line against the watchdog sleep, and cancels the loser.
    private func nextLine(from lines: AsyncThrowingStream<String, Error>) async -> ReadResult {
        let watchdog = self.watchdog
        let sleep = self.sleep
        return await withTaskGroup(of: ReadResult.self) { group in
            group.addTask {
                var iterator = lines.makeAsyncIterator()
                do {
                    guard let line = try await iterator.next() else { return .ended }
                    return .line(line)
                } catch {
                    return .ended
                }
            }
            group.addTask {
                do {
                    try await sleep(watchdog)
                    return .timedOut
                } catch {
                    return .ended
                }
            }
            let first = await group.next() ?? .ended
            group.cancelAll()
            return first
        }
    }

    /// Closes a line stream.
    ///
    /// A call to `next()` from a canceled task terminates an
    /// `AsyncThrowingStream`. This method makes that call in a child task that
    /// it cancels. The child task reads until the stream is terminated.
    private static func close(_ lines: AsyncThrowingStream<String, Error>) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var iterator = lines.makeAsyncIterator()
                while (try? await iterator.next()) != nil {}
            }
            group.cancelAll()
        }
    }
}
