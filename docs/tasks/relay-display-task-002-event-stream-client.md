# Relay display task 002: Event stream client

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 2. Model: Opus.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Transport, §Module boundaries, §Invariants.
- Depends on: task 001.

## Goal

Add `EventStreamClient` to `CitizenRadioCore`. It reads a snapshot, keeps one SSE stream open, and reconnects with a watchdog, a backoff and a network change signal.
Test it with fake connections and an injected sleep function.

## Files to inspect

- `CitizenRadio/Core/EventStreamParser.swift`, `CitizenRadio/Core/RelayEvent.swift`
- `CitizenRadio/Core/NWCClient.swift` (the pattern for a timeout with a task group, and for a closed connection on all paths)
- `CitizenRadio/Core/RelayConnection.swift` (the pattern for a transport protocol)
- `Tests/CitizenRadioCoreTests/NWCClientTests.swift` (the pattern for a fake transport)

## Files likely to change

- `CitizenRadio/Core/EventStreamClient.swift` (new)
- `Tests/CitizenRadioCoreTests/EventStreamClientTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Use exactly this API:

```swift
/// One HTTP response with a body of text lines.
public struct LineStreamResponse: Sendable {
    public let status: Int
    public let lines: AsyncThrowingStream<String, Error>
    public init(status: Int, lines: AsyncThrowingStream<String, Error>)
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

public actor EventStreamClient {
    public static let backoffSeconds = [1, 2, 4, 8, 16, 30]
    public init(
        snapshotURL: URL,
        streamURL: URL,
        eventName: String,
        opener: any LineStreamOpening,
        fetcher: any SnapshotFetching,
        watchdog: Duration = .seconds(35),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    )
    /// Starts the client one time and gives its updates. A second call gives a stream that finishes at once.
    public func start() -> AsyncStream<EventStreamUpdate>
    /// Ends a wait or an open stream, and starts a new attempt at once, with no backoff.
    public func networkChanged()
    /// Stops the client, closes the stream, sends .status(.stopped(.requested)) and finishes the update stream.
    public func stop()
}
```

The sequence of one attempt:

1. Send `.status(.connecting)`.
2. Fetch the snapshot.
   - `200`: send `.snapshot(body)`, and set the backoff index to 0.
   - `404`: send `.status(.stopped(.notFound))`, finish. `409`: send `.status(.stopped(.notReserved))`, finish.
   - Another status or a thrown error: go to the backoff.
3. Open the stream with the last event ID from the parser (nil at the first attempt).
   - `404` and `409`: stop as in step 2. Another status that is not `200`, or a thrown error: go to the backoff.
4. Send `.status(.live)`. Read lines into one `EventStreamParser` that the client keeps for its whole life, so `lastEventID` stays across attempts.
   - Each event with the name `eventName` gives `.event(event)`. Ignore other names.
   - Each line, also a comment or an empty line, resets the watchdog.
   - If no line arrives for `watchdog`, end the stream and go to the backoff.
   - The end of the line stream, or an error, goes to the backoff.

The backoff:

- Wait `backoffSeconds[index]` seconds with the injected `sleep`, and send `.status(.waiting(seconds:))` before the wait. Then increase the index, with `backoffSeconds.count - 1` as its maximum.
- Step 2 sets the index to 0 after a `200` snapshot. So a stream that ends after a good attempt waits 1 second.
- `networkChanged()` ends the present wait or the present stream at once and starts a new attempt with no wait.

Concurrency rules:

- Implement the watchdog as a race in a task group: the next line, and `sleep(watchdog)`. Cancel the loser.
- `stop()` and `networkChanged()` cancel the present run task. The run loop must stop at each `await` when canceled.
- Close all line streams on all paths. Each fake must record a close.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- The client imports only `Foundation`. No `URLSession`, no `Network`, no logging.
- Prose and comments in ASD-STE100.

Test approach:

- A fake `SnapshotFetching` that gives a list of results in sequence, and counts calls.
- A fake `LineStreamOpening` that gives a list of responses in sequence, records each `lastEventID`, and gives line streams that the test controls with `AsyncThrowingStream.makeStream()`.
- An injected `sleep` that records each requested duration and returns at once, or that suspends until the test resumes it. So the tests need no real time.

## Acceptance criteria

Mechanical (each one is a test in `EventStreamClientTests.swift`):

- The first updates are `.status(.connecting)`, `.snapshot(body)`, `.status(.live)`, in this sequence.
- A streamed `display` event gives `.event` with its data. An event with a different name gives nothing.
- After the stream ends, the client waits 1 second, fetches the snapshot again, and opens the stream with the last event ID.
- With a snapshot that fails each time, the recorded waits are 1, 2, 4, 8, 16, 30 and 30 seconds.
- A `200` snapshot after failures resets the next wait to 1 second.
- A stream that sends no line causes a watchdog request of 35 seconds, then a new attempt.
- Comment lines keep the stream alive: with a sleep that suspends, a comment line before the watchdog ends gives no new attempt.
- `404` on the snapshot gives `.status(.stopped(.notFound))`, and the update stream finishes. `409` gives `.notReserved`.
- `networkChanged()` during a wait starts a new attempt with no further wait.
- `stop()` gives `.status(.stopped(.requested))`, finishes the update stream, and closes the open line stream.
- A second `start()` gives a stream that finishes at once.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter EventStreamClientTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.
- A test needs real time or a real network.
- The API needs a change to meet a criterion.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-002-event-stream-client.md
- CitizenRadio/Core/EventStreamParser.swift
- CitizenRadio/Core/RelayEvent.swift
- CitizenRadio/Core/NWCClient.swift
- CitizenRadio/Core/RelayConnection.swift
- Tests/CitizenRadioCoreTests/NWCClientTests.swift

Goal:
- Add EventStreamClient with the snapshot read, the SSE stream, the watchdog, the backoff, networkChanged() and stop(), tested with fakes and an injected sleep function.

Constraints:
- Use the exact API, attempt sequence, backoff and concurrency rules in the task file.
- Only Foundation. No URLSession, Network or logging in this file.
- No @unchecked Sendable or nonisolated(unsafe). Tests use no real time and no network.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter EventStreamClientTests
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
