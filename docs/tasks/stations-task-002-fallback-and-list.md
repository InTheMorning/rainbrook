# Stations task 002: Fallback, station list and integration

- Decision: [ADR 0017](../adr/0017-stations-with-alternate-stream.md). [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for threading. Model: Opus.
- Depends on: stations task 001.

## Goal

The app plays the selected station, falls back to its alternate stream, and shows the station list in Settings. `StreamStore` and `RelayEventStore` are removed.

## Files to inspect

- `docs/adr/0017-stations-with-alternate-stream.md`
- `CitizenRadio/Core/Station.swift`, `CitizenRadio/Core/StationStore.swift`, `CitizenRadio/Core/IcySync.swift` (task 001)
- `CitizenRadio/RadioPlayer.swift` (`play`, `startPlayer`, `refreshPlayback`, `startConnectionTimeout`, `observeItem`, `fail`, `releasePlayer`)
- `CitizenRadio/TrackInfoModel.swift` (`reloadSettings`, `playbackChanged`, `icyTextChanged`), `CitizenRadio/BoostModel.swift` (`sessionEnded`)
- `CitizenRadio/PlayerView.swift`, `CitizenRadio/SettingsView.swift`, `CitizenRadio/Core/StreamSettingsDraft.swift`, `CitizenRadio/Core/PlayerScreenModel.swift`
- `CitizenRadio/RadioIntents.swift`, and each other user of `StreamStore` or `RelayEventStore`

## Files likely to change

- `CitizenRadio/RadioPlayer.swift`, `CitizenRadio/TrackInfoModel.swift`, `CitizenRadio/BoostModel.swift` (one new method)
- `CitizenRadio/PlayerView.swift`, `CitizenRadio/SettingsView.swift`, `CitizenRadio/StationEditorView.swift` (new)
- `CitizenRadio/Core/StreamSettingsDraft.swift`, `CitizenRadio/Core/PlayerScreenModel.swift` if its input changes, and their tests
- Delete `CitizenRadio/Core/StreamStore.swift`, `CitizenRadio/Core/RelayEventStore.swift` and their tests
- `CitizenRadio.xcodeproj/project.pbxproj` only if the project lists the files by name. Examine it first.

## Do not touch

- The boost core, the artwork code, the wallet code and the relay clients.

## Constraints

Player:

- `play()` uses `StationStore().selected`. With no selected station, the error is "Open CitizenRadio and add a station first."
- A playback session keeps the stream list of the station (`station.streams`) and the index of the stream that plays.
- These failures go to one path: the player item fails, the connection time limit ends, and the stream ends. That path starts the next stream of the list, if there is one. Else it calls `fail` with the message of today.
- The fallback keeps the active audio session and the playback request. It releases the old player and item, and starts the new stream with a new session identifier. The connection time limit starts again for the new stream.
- `@Published private(set) var usingAlternateStream: Bool`. It is true while the alternate stream plays, and false after Stop and at each new **Play**.
- The same-URL check at the start of `play()` compares the selected station id and its primary stream. So a tap on a different station starts it.

Track info and boosts:

- `TrackInfoModel` reads the event from `StationStore().selected?.event`, in `init` and in `reloadSettings`.
- When `usingAlternateStream` changes to true, `TrackInfoModel` calls `sync.resetIcy()`, sets no relay track, and calls `boost.streamChanged()`. The relay client does not stop.
- `BoostModel.streamChanged()` calls `trigger.endSession()` only. The pairing, the paid blocks and the history stay.

Settings:

- A **Stations** section replaces the stream URL field and the **Track info** field.
  - Each row shows the station name, and the stream host in the secondary style. A checkmark shows the selected station.
  - A tap on a row selects the station, closes the settings sheet, and starts playback. The `onDismiss` of the sheet already reloads the track info.
  - The info button of a row opens `StationEditorView` for that station. **Add Station** opens it empty. **Add Station** is not active at 20 stations.
  - A swipe deletes a station. A delete of the selected station stops the playback.
  - The list shows the empty text "Add a station to play." with no station.
- `StationEditorView` has the fields **Name**, **Stream**, **Alternate stream** (prompt "Optional") and **Track info** (prompt "Optional"), with the URL keyboard and no autocorrection. **Save** makes a `Station` with the same id. It shows the `StationError` text below the form on an error. It saves through `StationStore` and closes.
- `StreamSettingsDraft` loses the stream URL and the relay text. The other fields do not change.
- `PlayerView` uses `StationStore().selected != nil` for the saved-stream input, and reads it again when the settings sheet closes.
- The player screen shows "Alternate stream" in the secondary style below the playback status while `usingAlternateStream` is true.

Other:

- Delete `StreamStore`, `RelayEventStore` and their tests. Their keys move through the first-start rule of task 001. Copy any message text that the app still needs.
- The App Intents and `citizenradio://play` use the same `play()`, so they play the selected station.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. No blocking work on the main thread. Comments in ASD-STE100, and comments name ADR 0017.

## Acceptance criteria

Mechanical:

- No file refers to `StreamStore` or `RelayEventStore`.
- The draft tests pass with the new fields.
- `scripts/check.sh` passes.

Manual (by the reviewer): the single fallback path, the new session identifier at the fallback, `usingAlternateStream` reset at Stop and Play, and the `resetIcy` and `streamChanged` calls.

Visual (on an iPhone): the ADR 0017 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- The fallback needs a change to the audio session handling.
- A change is necessary in a file in "Do not touch".

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/stations-task-002-fallback-and-list.md
- docs/adr/0017-stations-with-alternate-stream.md
- the files listed in "Files to inspect"

Goal:
- Play the selected station, fall back to its alternate stream, and show the station list in Settings.
- Remove StreamStore and RelayEventStore.

Constraints:
- Use the exact rules in the task file.
- No @unchecked Sendable or nonisolated(unsafe). No blocking work on the main thread.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch".

Acceptance criteria:
- No file refers to StreamStore or RelayEventStore. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
