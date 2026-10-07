# Album task 001: The album in the display

- Decision: [ADR 0019](../adr/0019-album-in-the-display.md). Model: Sonnet.
- Depends on: none.

## Goal

Decode the optional `album` of a display track, and show it on the player screen and in Now Playing.

## Files to inspect

- `docs/adr/0019-album-in-the-display.md`
- `CitizenRadio/Core/TrackDisplay.swift`, `Tests/CitizenRadioCoreTests/TrackDisplayTests.swift`
- `CitizenRadio/Core/TrackLines.swift`, `Tests/CitizenRadioCoreTests/TrackLinesTests.swift`
- `CitizenRadio/PlayerView.swift` (the track text), `CitizenRadio/TrackInfoModel.swift` (`updateNowPlaying`), `CitizenRadio/RadioPlayer.swift` (`setNowPlayingTrack`, `updateNowPlaying`)

## Files likely to change

- `CitizenRadio/Core/TrackDisplay.swift`, `CitizenRadio/Core/TrackLines.swift` and their tests
- `CitizenRadio/PlayerView.swift`, `CitizenRadio/TrackInfoModel.swift`, `CitizenRadio/RadioPlayer.swift`

## Do not touch

- `IcySync` and its key. The relay clients, the boost code and the artwork code.

## Constraints

- `TrackDisplay` gets `public let album: String?`. The existing initializer gets `album: String? = nil` as its last parameter, so the existing calls do not change.
- Decode: a non-empty string gives the album. A missing key, `null`, an empty string or a value that is not a string gives nil. The state stays valid.
- `TrackLines` gets `public let album: String?`, with a default of nil in its initializer. `select(relay:icy:)` copies the album of the relay track. A line from the ICY title has no album.
- `PlayerView`: below the artist, show the album when there is one, in `.subheadline` and `.secondary`, with `lineLimit(1)`. No empty line when there is no album.
- Now Playing: `setNowPlayingTrack` gets an `album: String?` parameter. `RadioPlayer` sets `MPMediaItemPropertyAlbumTitle` when the album is not nil, and removes it when it is nil.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100. Comments name ADR 0019.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `TrackDisplay.decode`: a track with `"album": "Way to Go"` gives that album. A track with no key, with `null`, with `""` and with `12` gives nil, and each state stays valid.
- `TrackLines.select`: a relay track with an album gives that album. An ICY track gives nil.
- The existing tests pass with no change to their values.
- `scripts/check.sh` passes.

Visual (on an iPhone): the ADR 0019 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "TrackDisplayTests|TrackLinesTests"
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

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/album-task-001-display-album.md
- docs/adr/0019-album-in-the-display.md
- the files listed in "Files to inspect"

Goal:
- Decode the optional album of a display track, and show it on the player screen and in Now Playing.

Constraints:
- Use the exact rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
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
