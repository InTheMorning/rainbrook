# Relay display task 008: Integration, player screen and Now Playing

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 4. Model: Opus.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md), all sections, and §Changes at implementation. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for blocking calls.
- Depends on: tasks 001 to 007.

## Goal

Connect the parts with a `TrackInfoModel`. It does these steps:

- It runs the relay client during playback.
- It applies the display states with the delay rule, and combines them with the ICY title.
- It loads the artwork.
- It updates the player screen and Now Playing.
Replace ADR 0004 with a player screen record that has the new items.

## Files to inspect

- `docs/adr/0008-relay-display-metadata.md`, `docs/adr/0004-player-screen-and-settings.md`
- `CitizenRadio/Core/`: `EventStreamClient.swift`, `TrackDisplay.swift`, `DisplayTiming.swift`, `TrackLines.swift`, `RelayEventStore.swift`, `NetworkPathSummary.swift`, `BufferSetting.swift`, `PlaybackState.swift`
- `CitizenRadio/`: `RadioPlayer.swift`, `PlayerView.swift`, `SettingsView.swift`, `URLSessionEventStream.swift`, `NetworkPathMonitor.swift`, `ArtworkLoader.swift`, `CitizenRadioApp.swift`

## Files likely to change

- `CitizenRadio/Core/RelayStatusText.swift` (new)
- `Tests/CitizenRadioCoreTests/RelayStatusTextTests.swift` (new)
- `CitizenRadio/TrackInfoModel.swift` (new, iOS only)
- `CitizenRadio/RadioPlayer.swift`
- `CitizenRadio/PlayerView.swift`
- `CitizenRadio/SettingsView.swift`
- `docs/adr/0004-player-screen-and-settings.md` (moves to `docs/archive/adr/`)
- `docs/adr/0009-player-screen-with-track-info.md` (new)
- `docs/adr/0008-relay-display-metadata.md` (only §Changes at implementation, marked done)
- `README.md` (only the ADR list)

## Do not touch

- The core types of tasks 001 to 007, except to call them.
- Playback, buffer, chime, audio session and App Intents code.
- The Wallet section.

## Constraints

Core API (`import Foundation` only):

```swift
public enum RelayStatusText {
    /// The text for Settings, or nil when no message is necessary.
    public static func message(for status: EventStreamStatus?) -> String?
}
```

| Status | Text |
| --- | --- |
| `.stopped(.notFound)` | "The relay does not know this event. Examine the track info address." |
| `.stopped(.notReserved)` | "The relay event is not reserved. Ask the stream producer to reserve it." |
| `.waiting` | "The relay is not available. CitizenRadio tries again." |
| other, or nil | nil |

`RadioPlayer` changes:

- Add `func bufferedAheadSeconds() -> Double`. It reads the present item's loaded ranges and current time, and gives `BufferSetting.bufferedAhead(currentTime:loadedRanges:)`. Without an item, it gives 0.
- Add `func setNowPlayingTrack(title: String, artist: String, image: UIImage?)`. Store the three values, then call `updateNowPlaying()`.
- `updateNowPlaying()` uses the stored title and artist (default "CitizenRadio" and "Live radio"), and adds `MPMediaItemPropertyArtwork` when an image is stored.
- **Make the `MPMediaItemArtwork` in a `nonisolated static` function.** Its request handler runs on a thread that is not the main thread. A closure that is made in a `@MainActor` context is main-actor isolated in Swift 6, and the call then stops the app with a runtime check. The handler gives the stored image.

`TrackInfoModel` (app, `@MainActor final class TrackInfoModel: ObservableObject`):

- `init(player: RadioPlayer, loader: ArtworkLoader = ArtworkLoader(), monitor: NetworkPathMonitor = NetworkPathMonitor(), opener: any LineStreamOpening = URLSessionLineStreamOpener(), fetcher: any SnapshotFetching = URLSessionSnapshotFetcher())`.
- Published: `lines: TrackLines` (default `TrackLines.select(relay: nil, icy: nil)`), `image: UIImage?`, `relayStatus: EventStreamStatus?`.
- `func reloadSettings()`: read `RelayEventStore().event`. If it changed, stop the client and start again when playback is active.
- Observe `player.$state`. While the state is `.connecting` or `.playing` and an event is configured, run one `EventStreamClient` with `snapshotURL: event.displayURL`, `streamURL: event.displayEventsURL` and `eventName: "display"`. In all other states, stop it and set the relay track to nil.
- Read the client updates in one `Task`:
  - `.snapshot(data)`: decode with `TrackDisplay.decode`. Cancel all pending applies, and apply at once.
  - `.event(event)`: decode `event.data`. Apply after `DisplayTiming.delay(bufferedAhead: player.bufferedAheadSeconds())`, measured when the event arrives. Keep pending applies in arrival sequence. A decode error ignores the event.
  - `.status(status)`: set `relayStatus`. On `.stopped(.notFound)` or `.stopped(.notReserved)`, set the relay track to nil.
- Observe `player.$icyTrack`.
- After each change of the relay track or the ICY track, set `lines = TrackLines.select(relay:icy:)`.
- When `lines.artwork` changes, load it with `loader.image(for:event:)` in a `Task`. Set `image` only if `lines.artwork` is still the same artwork. With no artwork, set `image` to nil at once.
- After each change of `lines` or `image`, call `player.setNowPlayingTrack(title: lines.title, artist: lines.nowPlayingArtist, image: image)`.
- While the client runs, read `monitor.summaries()`. When `NetworkPathSummary.shouldReconnect(from:to:)` is true, call `client.networkChanged()`.
- Stop all tasks and the client in `deinit` or when playback stops.

App wiring:

- `PlayerView` owns `@StateObject private var trackInfo: TrackInfoModel`, made from its `player`. Use `_trackInfo = StateObject(wrappedValue: TrackInfoModel(player: player))` in an initializer.
- `PlayerView` calls `trackInfo.reloadSettings()` when the settings sheet closes (`.sheet(onDismiss:)`).
- `PlayerView` passes `trackInfo.relayStatus` to `SettingsView`. `SettingsView` shows `RelayStatusText.message(for:)` in the Track info section, if present.

Player screen:

- The artwork area shows `Image(uiImage:)`, resizable, filled, clipped to the same rounded rectangle, when `trackInfo.image` is not nil. Else the present placeholder. The artwork stays hidden from accessibility.
- The title line shows `trackInfo.lines.title`. A new line below it shows `trackInfo.lines.artist` in the secondary style, if present.
- The status line, the Play or Stop button, the AirPlay button and the Settings button do not change.

Threading:

- `TrackInfoModel` is `@MainActor`. Network, image and stream work stay in `EventStreamClient`, `ArtworkLoader` and the URLSession types.
- Each scheduled apply is a `Task` that sleeps on its own. No timer on the main run loop.

Documentation:

- Move `docs/adr/0004-player-screen-and-settings.md` to `docs/archive/adr/` with `git mv`. Add the archive note at the top, and set its status to superseded by ADR 0009. Correct its relative links for the new folder.
- Write `docs/adr/0009-player-screen-with-track-info.md`. Restate ADR 0004 with these changes:
  - The player screen shows the artwork or the placeholder, the track title or "CitizenRadio", the artist if present, the status line, Play or Stop, the AirPlay route button, and the Settings button.
  - The settings sheet contains the stream URL, **Track info**, the extra buffer, the chime and the Wallet section.
  - Keep the ADR 0004 invariants and their tests, and add: the artwork comes only from `TrackInfoModel`.
  - It names ADR 0008 for the data rules.
- In ADR 0008, mark §Changes at implementation as done for the player screen record.
- In `README.md`, replace the ADR 0004 line with ADR 0009.
- Write all prose in ASD-STE100, and run the STE checker on each changed document.

## Acceptance criteria

Mechanical:

- `RelayStatusTextTests` covers each row of the text table.
- `scripts/check.sh` passes, so all iOS files compile in Swift 6 mode.
- `RadioPlayer.swift` makes `MPMediaItemArtwork` only in a `nonisolated static` function.
- All relative links in the changed documents resolve.

Visual (on an iPhone):

- With the station event in **Track info**, the artwork, the title and the artist show, and they change when the listener hears the new track.
- The lock screen and the car show the track title, the artist and the artwork.
- With an empty **Track info** field, the title and the artist come from the stream title, and the artwork area shows the placeholder.
- Stop, then Play: the display is correct again.

## Test commands

```sh
swift test --build-system native --filter RelayStatusTextTests
grep -n "MPMediaItemArtwork(" CitizenRadio/RadioPlayer.swift
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A type of tasks 001 to 007 needs a change.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.
- The change needs edits to playback, buffer, chime or audio session code.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-008-integration.md
- docs/adr/0008-relay-display-metadata.md
- docs/adr/0004-player-screen-and-settings.md
- the core and app files listed in "Files to inspect"

Goal:
- Add RelayStatusText (core, tested) and TrackInfoModel, connect them to RadioPlayer, PlayerView and SettingsView, and replace ADR 0004 with ADR 0009.

Constraints:
- Use the exact API, texts, rules and wiring in the task file.
- Make MPMediaItemArtwork only in a nonisolated static function.
- TrackInfoModel is @MainActor. Network, image and stream work stay off the main thread.
- No @unchecked Sendable or nonisolated(unsafe). Do not change playback, buffer, chime, audio session, App Intents or Wallet code.
- Prose, user texts and comments in ASD-STE100.
- Do not run git commit. You may use git mv for the ADR move. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- The mechanical criteria in the task file pass. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
