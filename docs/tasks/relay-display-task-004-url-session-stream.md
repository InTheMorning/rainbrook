# Relay display task 004: URLSession stream and network monitor

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 3. Model: Sonnet.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Transport, §Module boundaries. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for blocking calls.
- Depends on: task 002.

## Goal

Add the iOS implementations of `LineStreamOpening` and `SnapshotFetching` with `URLSession`, and a network path monitor.

## Files to inspect

- `CitizenRadio/Core/EventStreamClient.swift` (the protocols)
- `CitizenRadio/URLSessionRelayConnection.swift` (the pattern for an iOS-only transport file, with cancellation)

## Files likely to change

- `CitizenRadio/Core/NetworkPathSummary.swift` (new)
- `Tests/CitizenRadioCoreTests/NetworkPathSummaryTests.swift` (new)
- `CitizenRadio/URLSessionEventStream.swift` (new, iOS only)
- `CitizenRadio/NetworkPathMonitor.swift` (new, iOS only)

## Do not touch

- All other files.

## Constraints

Core API (`import Foundation` only):

```swift
public struct NetworkPathSummary: Equatable, Sendable {
    public let isSatisfied: Bool
    public let interfaces: [String]   // interface names, in the order that the system gives
    public init(isSatisfied: Bool, interfaces: [String])
    /// True when the client must reconnect: the new path is satisfied, and the old path was not satisfied or used different interfaces.
    public static func shouldReconnect(from old: NetworkPathSummary?, to new: NetworkPathSummary) -> Bool
}
```

`shouldReconnect` gives false when `old` is nil, because the first path is not a change.

App API:

```swift
#if os(iOS)
struct URLSessionLineStreamOpener: LineStreamOpening {
    init(session: URLSession = .shared)
}

struct URLSessionSnapshotFetcher: SnapshotFetching {
    init(session: URLSession = .shared)
}

final class NetworkPathMonitor: Sendable {
    init()
    /// Gives a NetworkPathSummary for each path update. Cancel the consumer task to stop the monitor.
    func summaries() -> AsyncStream<NetworkPathSummary>
}
#endif
```

`URLSessionLineStreamOpener` rules:

- `GET` with `Accept: text/event-stream`, `Cache-Control: no-cache`, and `Last-Event-ID` if not nil. Set `timeoutInterval` to 60 seconds.
- Use `session.bytes(for:)`. The status comes from the `HTTPURLResponse`.
- **Do not use `bytes.lines`.** `AsyncLineSequence` does not give empty lines, and an empty line ends each SSE event. So read the bytes yourself:
  1. End a line at each line feed (byte 10).
  2. Remove one carriage return (byte 13) at the end of a line.
  3. Decode each line as UTF-8.
- Give the lines through an `AsyncThrowingStream`. Read the bytes in a `Task` that the stream's `onTermination` cancels. So a canceled consumer stops the network read.
- A body that is not `200` gives the status with an empty line stream that finishes at once.

`URLSessionSnapshotFetcher` rules:

- `GET` with `Accept: application/json` and a `timeoutInterval` of 15 seconds. Use `session.data(for:)`.

`NetworkPathMonitor` rules:

- In `summaries()`, make an `NWPathMonitor`, set its `pathUpdateHandler` to yield a `NetworkPathSummary`, and start it on a private serial `DispatchQueue`.
- The stream's `onTermination` cancels the monitor.
- The handler captures only the continuation. It holds no other mutable state.

Other constraints:

- Only async `URLSession` methods. No completion handlers, no semaphores.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- No log of a URL query, a header or a body.
- New iOS files start with `#if os(iOS)` and import `CitizenRadioCore` inside `#if SWIFT_PACKAGE`.
- Prose and comments in ASD-STE100.

## Acceptance criteria

Mechanical:

- `NetworkPathSummaryTests`: nil to satisfied gives false. Unsatisfied to satisfied gives true. Satisfied to satisfied with the same interfaces gives false, and with different interfaces gives true. Any change to unsatisfied gives false.
- `URLSessionEventStream.swift` does not contain `.lines`.
- `scripts/check.sh` passes, so the iOS files compile in Swift 6 mode.

Visual (on an iPhone, after task 008):

- With Wi-Fi switched off during playback, the display stays correct, or it is correct again within 40 seconds.

## Test commands

```sh
swift test --build-system native --filter NetworkPathSummaryTests
grep -n "\.lines" CitizenRadio/URLSessionEventStream.swift || echo "no .lines"
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
- The protocols of task 002 need a change.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-004-url-session-stream.md
- CitizenRadio/Core/EventStreamClient.swift
- CitizenRadio/URLSessionRelayConnection.swift

Goal:
- Add NetworkPathSummary (core, tested), URLSessionLineStreamOpener, URLSessionSnapshotFetcher and NetworkPathMonitor.

Constraints:
- Use the exact API and rules in the task file. Do not use bytes.lines: it drops the empty lines that end SSE events.
- Only async URLSession methods. No @unchecked Sendable or nonisolated(unsafe). No log of URLs, headers or bodies.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- NetworkPathSummaryTests pass. No ".lines" in URLSessionEventStream.swift. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
