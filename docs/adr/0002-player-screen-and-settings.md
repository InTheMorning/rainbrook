# ADR 0002: Player screen and settings

- Status: accepted
- Date: 2026-10-04
- Class: situational. Supersede this record when the primary screen or the settings change.
- Supersedes: [ADR 0001](../archive/adr/0001-player-screen-layout.md)

## Context

In ADR 0001, the settings sheet contained only the stream URL.
The user asked for a setting that plays `forcdchime.wav` in a loop until the stream starts.

## Decision

The primary screen is a standard music player screen. It shows only these items:

- An artwork placeholder.
- The app title and one status line.
- One Play or Stop button.
- The AirPlay route button.
- A **Settings** button in the navigation bar.

The settings sheet contains these two settings:

- The stream URL.
- **Chime while connecting**. The default is on.

When the chime setting is on, `forcdchime.wav` plays in a loop while the playback state is `connecting`.
The chime stops at all other states.
This includes the reconnection after a stall during playback.

The display and chime logic is in `CitizenRadioCore`:

- `PlayerScreenModel` selects the status text and the Play or Stop control.
- `StreamSettingsDraft` enables **Save**.
- `ChimeSetting` stores the chime setting and selects the states that play the chime.

The SwiftUI views and `RadioPlayer` read these values and contain no other display or chime rules.

## Alternatives considered

- Keep the form and move it to a second tab. This keeps the items that the user rejected.
- Show skip, previous and seek controls. A live stream has no track position, so these controls do nothing.
- Add a system volume slider. The app does not change the system volume, and the hardware buttons and car controls set it.
- Open the settings sheet on the first launch. The status line tells the user to open Settings, so the sheet does not open automatically.
- Set the chime default to off. The user supplied the chime for this app, so the default is on.

## Consequences

- The app does not show the Shortcuts help. The [setup runbook](../runbooks/iphone-setup.md) contains these steps.
- The app does not show the output device name. The AirPlay button shows the output selection.
- The app bundle contains `forcdchime.wav`. xtool copies it through `resources`, and the Xcode target copies it as a resource.
- Linux tests can examine the display and chime rules. Only a person on an iPhone can examine the layout and the sound.

## Invariants

These rules apply while this decision is current.

- The settings sheet contains only the stream URL and the chime setting.
  Manual check: open **Settings** on an iPhone. A test cannot examine the SwiftUI view tree on Linux.
- The player screen shows only the items in the Decision section.
  Manual check: open the app on an iPhone in portrait and in landscape.
- The Play control is disabled when no stream URL is saved.
  `PlayerScreenModelTests.testPlayIsDisabledWithoutSavedStream` enforces this rule.
- The chime plays only in the `connecting` state and only when the setting is on.
  `ChimeSettingTests.testChimePlaysOnlyWhileConnecting` enforces this rule.
