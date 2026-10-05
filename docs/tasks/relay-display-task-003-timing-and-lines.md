# Relay display task 003: Display timing and track lines

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 2. Model: Haiku.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Display data, §Player screen and Now Playing, §Fallback: the ICY title.
- Depends on: task 001.

## Goal

Add the display delay rule and the source priority rule to `CitizenRadioCore`, with tests.

## Files to inspect

- `CitizenRadio/Core/TrackDisplay.swift`, `CitizenRadio/Core/IcyTitle.swift`
- `CitizenRadio/Core/PlayerScreenModel.swift` (the pattern for a small display rule)

## Files likely to change

- `CitizenRadio/Core/DisplayTiming.swift` (new)
- `CitizenRadio/Core/TrackLines.swift` (new)
- `Tests/CitizenRadioCoreTests/DisplayTimingTests.swift`, `TrackLinesTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Use exactly this API. Each file imports only `Foundation`.

```swift
public enum DisplayTiming {
    /// The longest delay. A larger buffered value is not correct, so the app does not wait longer.
    public static let maximumSeconds: Double = 60
    /// The wait before the app applies a streamed display state.
    public static func delay(bufferedAhead: Double) -> Duration
}

public struct TrackLines: Equatable, Sendable {
    public static let defaultTitle = "CitizenRadio"
    public static let defaultNowPlayingArtist = "Live radio"
    public let title: String
    public let artist: String?
    public let artwork: TrackDisplay.Artwork?
    public init(title: String, artist: String?, artwork: TrackDisplay.Artwork?)
    /// A relay track has priority. Else the ICY track. Else the default lines.
    public static func select(relay: TrackDisplay?, icy: IcyTrack?) -> TrackLines
    /// The artist text for Now Playing: the artist, or "Live radio".
    public var nowPlayingArtist: String { get }
}
```

Rules:

- `delay(bufferedAhead:)` gives `.zero` for a value that is not finite or that is 0 or less. Else it gives the value in seconds, with `maximumSeconds` as the maximum. Keep fractions of a second: use milliseconds.
- `select`:
  - With a relay track: its title, its artist, and its artwork. An empty relay title gives `defaultTitle`. An empty relay artist gives nil.
  - Else with an ICY track: its title and artist, and no artwork.
  - Else: `defaultTitle`, no artist, no artwork.
- Prose and comments in ASD-STE100.

## Acceptance criteria

Mechanical (each one is a test):

- `delay` gives 0 for -1, 0, `.nan` and `.infinity`, 3.5 seconds for 3.5, and 60 seconds for 90.
- `select` gives the relay track when relay and ICY are both present.
- `select` gives the ICY title and artist, with no artwork, when only ICY is present.
- `select` gives "CitizenRadio", no artist and no artwork when neither is present.
- An empty relay title gives "CitizenRadio". An empty relay artist gives nil.
- `nowPlayingArtist` gives the artist, or "Live radio" when the artist is nil.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "DisplayTimingTests|TrackLinesTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- The API of `TrackDisplay` or `IcyTrack` differs from task 001.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-003-timing-and-lines.md
- CitizenRadio/Core/TrackDisplay.swift
- CitizenRadio/Core/IcyTitle.swift
- CitizenRadio/Core/PlayerScreenModel.swift

Goal:
- Add DisplayTiming and TrackLines to CitizenRadioCore, with tests.

Constraints:
- Use the exact API and rules in the task file. Only Foundation.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "DisplayTimingTests|TrackLinesTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
