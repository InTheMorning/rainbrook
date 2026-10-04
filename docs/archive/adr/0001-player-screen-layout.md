> Archived: superseded by [ADR 0002](0002-player-screen-and-settings.md) on 2026-10-04.

# ADR 0001: Player screen layout

- Status: superseded by [ADR 0002](0002-player-screen-and-settings.md)
- Date: 2026-10-04
- Class: situational. Supersede this record when the primary screen changes.
- Plan: [Player screen plan](../plans/player-screen-plan.md)

## Context

The first screen was one form. It mixed playback, the stream URL, the output name and Shortcuts help text.
The user found that this screen was not useful for usual playback.

## Decision

The primary screen is a standard music player screen. It shows only these items:

- An artwork placeholder.
- The app title and one status line.
- One Play or Stop button.
- The AirPlay route button.
- A **Settings** button in the navigation bar.

The settings sheet contains only the stream URL.

The display logic is in `CitizenRadioCore`:

- `PlayerScreenModel` selects the status text and the Play or Stop control.
- `StreamSettingsDraft` enables **Save**.

The SwiftUI views read these values and contain no other display rules.

## Alternatives considered

- Keep the form and move it to a second tab. This keeps the items that the user rejected.
- Show skip, previous and seek controls. A live stream has no track position, so these controls do nothing.
- Add a system volume slider. The app does not change the system volume, and the hardware buttons and car controls set it.
- Open the settings sheet on the first launch. The status line tells the user to open Settings, so the sheet does not open automatically.

## Consequences

- The app does not show the Shortcuts help. The [setup runbook](../../runbooks/iphone-setup.md) contains these steps.
- The app does not show the output device name. The AirPlay button shows the output selection.
- Linux tests can examine the display rules. Only a person on an iPhone can examine the layout.

## Invariants

These rules apply while this decision is current.

- The settings sheet contains only the stream URL.
  Manual check: open **Settings** on an iPhone. A test cannot examine the SwiftUI view tree on Linux.
- The player screen shows only the items in the Decision section.
  Manual check: open the app on an iPhone in portrait and in landscape.
- The Play control is disabled when no stream URL is saved.
  `PlayerScreenModelTests.testPlayIsDisabledWithoutSavedStream` enforces this rule.
