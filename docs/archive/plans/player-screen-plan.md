> Archived: implemented, then superseded by [ADR 0002](../adr/0002-player-screen-and-settings.md) on 2026-10-04.

# Player screen plan

Status: implemented, 2026-10-04. The visual checks are open. Decision: [ADR 0001](../adr/0001-player-screen-layout.md).

## Goal

Replace the current form screen with a standard music player screen.
The player screen shows an artwork area, the playback status and the playback controls.
A Settings button opens a sheet that contains only the stream URL.

## Non-goals

- Album art from the stream or ICY stream metadata. The artwork area shows a placeholder.
- Skip, previous, seek or a progress bar. A live stream has no track position.
- Changes to playback, audio session, URL actions or App Intents behavior.
- Changes to the Now Playing information or the remote commands.
- CarPlay screens.

## Current state

`CitizenRadio/RadioView.swift` shows one `Form` with four sections:

1. A header with an icon, a tagline, the status, an error and the Play or Stop button.
2. The stream URL field, the **Save Stream** button and the save result.
3. The audio output name, an `AVRoutePickerView` and volume help text.
4. Help text for the Shortcuts automation.

`RadioPlayer.State` supplies the status title, the symbol and `canStop`.
`RadioPlayer` is iOS-only, so `swift test` cannot test this state on Linux.

## Target state

### Player screen

The player screen has these items, from top to bottom:

1. A navigation bar with the title **CitizenRadio** and a gear button with the label **Settings**.
2. A square artwork placeholder with rounded corners. It shows the `radio` symbol on a secondary fill.
3. The title **CitizenRadio** and one status line below it.
4. One large circular Play or Stop button in the center.
5. An AirPlay route button below the Play or Stop button.

The status line shows the state title, for example **Playing live** or **Connecting**.
A failed state shows its error message in the status line.
If no stream URL is saved, the status line shows **Add a stream in Settings** and the Play button is disabled.
In landscape, the artwork is at the left and the text and controls are at the right.

### Settings sheet

The gear button opens a sheet with a `NavigationStack` and a `Form`.
The form has one section with the **Stream URL** field and the current footer text.
The toolbar has **Cancel** and **Save**.

- **Save** is disabled when the field is empty or equal to the saved URL.
- A valid URL is saved through `StreamStore.save(_:)` and the sheet closes.
- An invalid URL shows the validation error in the section, and the sheet stays open.
- **Cancel** closes the sheet and keeps the saved URL.
- Saving a different valid URL stops current playback. This rule exists now and does not change.

### Removed items

- The tagline **Your station. Your drive.**
- The audio output name and the volume help text.
- The Shortcuts help section. The [setup runbook](../../runbooks/iphone-setup.md) keeps these steps.
- `RadioPlayer.outputName`, because no view reads it after this change.
  `updateOutput()` keeps its output identifier tracking.

## Design

Move the display logic to `CitizenRadioCore`, so that Linux tests can examine it.

- Move `RadioPlayer.State` to a public `PlaybackState` enum in `CitizenRadio/Core/PlaybackState.swift`.
  Keep `title`, `canStop` and `errorMessage`. Delete `symbol`, because no view uses it.
- Add a `PlayerScreenModel` value in `CitizenRadio/Core/PlayerScreenModel.swift`.
  Its input is a `PlaybackState` and a flag that tells if a stream URL is saved.
  It supplies the status text, the primary control (`.play` or `.stop`) and the control enabled state.
- Add a `StreamSettingsDraft` value in `CitizenRadio/Core/StreamSettingsDraft.swift`.
  It supplies the **Save** enabled state from the draft text and the saved URL.

The SwiftUI files only read these values.
Split the views into `PlayerView.swift` and `SettingsView.swift`.
Delete `RadioView.swift` after the split.
Keep the accessibility identifiers `playbackStatus`, `playbackButton`, `streamURL` and `saveStream`.
Add the identifier `settingsButton`.

Add both new files to `CitizenRadio.xcodeproj/project.pbxproj` and remove `RadioView.swift` from it.
The Swift package finds the files without a change to `Package.swift`.

## Phases

### Phase 0: Decision record

Make `docs/adr/0001-player-screen-layout.md`.
It records the layout above as a situational decision.
It names this plan and states that the settings sheet contains only the stream URL.

### Phase 1: Core models and tests

1. Add `PlaybackState`, `PlayerScreenModel` and `StreamSettingsDraft` to `CitizenRadioCore`.
2. Change `RadioPlayer` to use `PlaybackState`.
3. Add tests in `Tests/CitizenRadioCoreTests/`.
4. Run `swift test`.

### Phase 2: Views

1. Add `PlayerView.swift` and `SettingsView.swift`.
2. Change `CitizenRadioApp` to show `PlayerView`.
3. Delete `RadioView.swift` and `RadioPlayer.outputName`.
4. Update the Xcode project file.
5. Run `swift build` and `swift test` on Linux.
6. Run `xtool dev` on a machine with the iOS SDK.

### Phase 3: Documentation

1. Update the README install steps. Replace **Save Stream** with the Settings sheet steps.
2. Update the **Configure playback** steps in `docs/runbooks/iphone-setup.md`.
3. Update the components table and the file count in `docs/architecture/overview.md`.

## Acceptance criteria

### Mechanical

Each criterion has a test in `Tests/CitizenRadioCoreTests/`.

- `PlayerScreenModel` gives the `.play` control for `.stopped` and `.failed`.
- `PlayerScreenModel` gives the `.stop` control for `.connecting`, `.playing` and `.interrupted`.
- `PlayerScreenModel` disables the `.play` control when no stream URL is saved.
- `PlayerScreenModel` gives **Add a stream in Settings** as status text when no stream URL is saved and playback is stopped.
- `PlayerScreenModel` gives the error message as status text for `.failed`.
- `StreamSettingsDraft` disables **Save** for an empty draft and for a draft equal to the saved URL.
- The existing 13 tests continue to pass.

### Visual

A person must examine these items on an iPhone.
Report each item as open until that examination is complete.

- The player screen shows only the artwork, the title, the status, the Play or Stop button and the AirPlay button.
- The gear button opens the settings sheet, and the sheet contains only the stream URL field.
- The layout is correct in portrait and in landscape.
- The layout is correct at the largest Dynamic Type size.
- VoiceOver reads **Play**, **Stop**, **Settings** and the status. It does not read the artwork.
- The layout is correct in light mode and in dark mode.

## Risks

- The iOS views cannot compile on Linux. Only an `xtool dev` or Xcode build can find SDK errors.
- `AVRoutePickerView` has a fixed appearance. It can look different from the SwiftUI buttons.
- The removal of the in-app Shortcuts help makes the runbook the only source for those steps.

## Rollback

All changes are in one commit. Revert that commit to restore the form screen.

## Open questions

- Keep the AirPlay route button? The recommendation is yes, because standard players show it.
- Add a system volume slider (`MPVolumeView`)? The recommendation is no.
  The hardware buttons and the car controls set the volume, and the app does not change the system volume now.
- Open the settings sheet automatically on the first launch when no stream URL is saved?
  The recommendation is no. The status line tells the user to open Settings.
