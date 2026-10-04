# NWC wallet task 008: WebSocket relay connection

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 3.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Connection test, §Module boundaries.
- Depends on: task 006.

## Goal

Add `URLSessionRelayConnector` and `URLSessionRelayConnection` in the app target.
They implement the core relay protocols with `URLSessionWebSocketTask`.

## Files to inspect

- `CitizenRadio/Core/RelayConnection.swift`
- `CitizenRadio/KeychainSecretStore.swift` (the header pattern for an iOS-only app file)

## Files likely to change

- `CitizenRadio/URLSessionRelayConnection.swift` (new, iOS only)

## Do not touch

- All other files.

## Constraints

Use exactly this API:

```swift
#if os(iOS)
struct URLSessionRelayConnector: RelayConnecting {
    init(session: URLSession = .shared)
    func connect(to url: URL) async throws -> any RelayConnection
}

final class URLSessionRelayConnection: RelayConnection {
    // send, receive and close from the protocol
}
#endif
```

Rules:

- `connect` makes a `URLSessionWebSocketTask` with `session.webSocketTask(with: url)` and calls `resume()`.
- `send` uses `task.send(.string(text))` with `async`/`await`.
- `receive` uses `try await task.receive()`. A `.string` message gives the text. A `.data` message gives the UTF-8 text, or throws if it is not UTF-8.
- `receive` and `send` must stop when their Swift task is cancelled. `NWCClient` uses task cancellation for its timeout.
  The async form of an Objective-C completion-handler method does not react to cancellation without help.
  So wrap each call in `withTaskCancellationHandler`, and call `task.cancel(with: .goingAway, reason: nil)` in `onCancel`.
- `close` calls `task.cancel(with: .normalClosure, reason: nil)`.
- Use only the `async` methods. Do not use completion handlers or semaphores, so no call blocks a thread.
- The class has only `let` properties. If Swift 6 rejects `Sendable` for `URLSessionWebSocketTask`, stop and escalate.
- No log contains message text, because messages can contain encrypted wallet data.
- The file starts with `#if os(iOS)` and imports `CitizenRadioCore` inside `#if SWIFT_PACKAGE`.
- Prose and comments in ASD-STE100.

## Implementation steps

1. Write `URLSessionRelayConnection.swift`.
2. Run the test commands.

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes, so the file compiles with the iOS SDK in Swift 6 mode.
- The file contains no completion handler, `DispatchSemaphore` or `@unchecked Sendable`.
- `receive` and `send` are wrapped in `withTaskCancellationHandler`.

Visual (on an iPhone, after task 009):

- **Test Connection** with Alby Hub shows the wallet methods within 10 seconds.

## Test commands

```sh
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
- The relay protocols need a change.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-008-relay-connection.md
- CitizenRadio/Core/RelayConnection.swift
- CitizenRadio/KeychainSecretStore.swift (header pattern only)

Goal:
- Add URLSessionRelayConnector and URLSessionRelayConnection with URLSessionWebSocketTask and async calls.

Constraints:
- Use the exact API and rules in the task file. Only async methods: no completion handlers, no semaphores.
- Wrap receive and send in withTaskCancellationHandler, so the NWCClient timeout can stop them.
- No @unchecked Sendable. No message text in logs.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- scripts/check.sh passes.
- No completion handler, DispatchSemaphore or @unchecked Sendable in the file.

Test commands:
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
