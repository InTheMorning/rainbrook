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
    case status(EventStreamStatus)
}

/// Reads a snapshot, then keeps one server-sent event stream open.
///
/// ADR 0008 §Transport names the attempt sequence, the watchdog and the
/// backoff. This client imports only `Foundation`. The app gives the HTTP
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

    public init(
        snapshotURL: URL,
        streamURL: URL,
        eventName: String,
        opener: any LineStreamOpening,
        fetcher: any SnapshotFetching,
        watchdog: Duration = .seconds(35),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.snapshotURL = snapshotURL
        self.streamURL = streamURL
        self.eventName = eventName
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
        switch snapshot.status {
        case 200:
            send(.snapshot(snapshot.body))
            backoffIndex = 0
        case 404:
            return .stop(.notFound)
        case 409:
            return .stop(.notReserved)
        default:
            return .retry
        }

        let response: LineStreamResponse
        do {
            response = try await opener.open(streamURL, lastEventID: parser.lastEventID)
        } catch {
            return .retry
        }
        let outcome = await readResponse(response)
        await Self.close(response.lines)
        return outcome
    }

    /// Reads the stream until it ends, it fails, or the watchdog fires.
    ///
    /// The caller closes the line stream after this method.
    private func readResponse(_ response: LineStreamResponse) async -> Outcome {
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
                send(.event(event))
            }
        }
        return .retry
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
