# Diagnosis task 001: Playback log and artwork retry

- Decision: [ADR 0022](../adr/0022-playback-log-and-artwork-retry.md). [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for threading. Model: Opus.
- Depends on: none.

## Goal

Keep the last 500 playback events in a file. Show them in Settings with Share and Clear. Retry a failed artwork load.

## Files to inspect

- `docs/adr/0022-playback-log-and-artwork-retry.md`
- `CitizenRadio/RadioPlayer.swift` (`Self.log` and `logPosition`)
- `CitizenRadio/TrackInfoModel.swift` (`icyTextChanged`, `updateLines`, `loadArtwork`, `handle`, `handleValue`, the network path task)
- `CitizenRadio/ArtworkLoader.swift`, `CitizenRadio/Core/BoostHistory.swift` (the file store pattern: an actor, an atomic write, the Application Support folder)
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift` (the **Boost history** link is the pattern)

## Files likely to change

- `CitizenRadio/Core/PlaybackLog.swift` (new), `Tests/CitizenRadioCoreTests/PlaybackLogTests.swift` (new)
- `CitizenRadio/Core/ArtworkRetry.swift` (new), `Tests/CitizenRadioCoreTests/ArtworkRetryTests.swift` (new)
- `CitizenRadio/PlaybackLogStore.swift` (new), `CitizenRadio/PlaybackLogView.swift` (new)
- `CitizenRadio/RadioPlayer.swift`, `CitizenRadio/TrackInfoModel.swift`, `CitizenRadio/SettingsView.swift`
- `CitizenRadio.xcodeproj/project.pbxproj`: one file reference and one build file for each new Swift file

## Do not touch

- The playback rules of ADR 0020 and ADR 0021. The relay clients, the boost code and the station code.

## Constraints

Core API (only `Foundation`):

```swift
public struct PlaybackLog: Equatable, Sendable {
    public static let capacity = 500
    public struct Entry: Codable, Equatable, Sendable { public let date: Date; public let text: String }
    public private(set) var entries: [Entry]   // oldest first
    public init(entries: [Entry] = [])          // keeps the last `capacity`
    public mutating func add(_ entry: Entry)    // drops the oldest above `capacity`
    public mutating func clear()
    /// One line for each entry: ISO 8601 time with milliseconds, a space, the text.
    public func text() -> String
    public func encoded() throws -> Data
    public static func decode(_ data: Data) throws -> PlaybackLog
}

/// ADR 0022 §The artwork retry. No clock.
public enum ArtworkRetry {
    public static let delays: [Int] = [2, 5, 10, 30]
    /// The delay before attempt `attempt` (1 is the first retry), or nil after the last.
    public static func delay(beforeRetry attempt: Int) -> Int?
}
```

App:

- `PlaybackLogStore`: an actor with one shared instance. `add(_ text:)` adds an entry with the current date. It writes the file `CitizenRadio/playback-log.json` in Application Support, atomically, a maximum of one time each 5 seconds, and in `flush()`. `load()` reads it at the start. `entries()` and `clear()`.
- A main-actor helper `PlaybackDiagnostics.record(_ text: String)` sends the text to the store in a task, with no wait. It also writes the text to the `playback` `Logger` category with `.public` privacy.
- `RadioPlayer`: each `Self.log.notice` call of today also goes through `PlaybackDiagnostics.record`. Keep the same texts.
- `TrackInfoModel` records these events:
  - each ICY text: "ICY: <text>".
  - each change of the selected relay track: "Relay track: <artist - title>" or "Relay track: none".
  - each change of the artwork of the lines: "Artwork: relay", "Artwork: URL" or "Artwork: none".
  - each artwork load result: "Artwork load: ok" or "Artwork load: failed, attempt N".
  - each status change of the two relay clients: "Display client: <status>" and "Value client: <status>".
- On the scene phase `background`, call `flush()`.
- Artwork retry in `TrackInfoModel.loadArtwork`: a nil result starts a retry with `ArtworkRetry.delay(beforeRetry:)`, while `lines.artwork` is the same. A change of the artwork cancels the retry. A satisfied network path with an artwork and no image starts a load at once. The image stays nil while a retry waits.
- Settings: a **Playback log** link in the section of the chime toggle. `PlaybackLogView` shows the text in a monospaced small font, scrolled to the end. The toolbar has a `ShareLink` with the text, and **Clear**.

Other:

- The log contains no wallet data, no boost message and no key.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. No blocking work on the main thread. Comments in ASD-STE100. Comments name ADR 0022.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `PlaybackLog`: 501 adds keep 500, and the first entry is the second add. `clear` empties it. `text()` for two entries with fixed dates. Encode and decode give the same log. `init(entries:)` with 600 entries keeps the last 500.
- `ArtworkRetry`: attempts 1 to 4 give 2, 5, 10 and 30. Attempt 5 gives nil.
- `scripts/check.sh` passes. The project ID check prints `missing: []`, and the Swift file reference count equals the Swift file count.

Manual (by the reviewer):

- The file write is off the main actor, a maximum of one time each 5 seconds.
- The flush at `background`.
- The retry stops at an artwork change.
- The log has no wallet data.

Visual (on an iPhone): the ADR 0022 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "PlaybackLogTests|ArtworkRetryTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- A change is necessary in a file in "Do not touch".
- The scene phase is not available where the flush must occur.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/diagnosis-task-001-playback-log-and-artwork-retry.md
- docs/adr/0022-playback-log-and-artwork-retry.md
- the files listed in "Files to inspect"

Goal:
- Keep the last 500 playback events in a file.
- Show them in Settings with Share and Clear.
- Retry a failed artwork load.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). No blocking work on the main thread. Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
