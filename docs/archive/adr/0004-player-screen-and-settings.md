> Archived: superseded by [ADR 0009](0009-player-screen-with-track-info.md) on 2026-10-04.

# ADR 0004: Player screen and settings

- Status: superseded by [ADR 0009](0009-player-screen-with-track-info.md)
- Date: 2026-10-04
- Class: situational. Supersede this record when the primary screen changes, or when a setting moves out of the settings sheet.
- Supersedes: [ADR 0002](0002-player-screen-and-settings.md)

## Context

ADR 0002 gave a full list of the items in the settings sheet.
The user asked for an extra buffer setting to make playback smoother.
A full list makes each new setting a new decision record, so this record states a boundary as an alternative.

## Decision

The primary screen is a standard music player screen. It shows only these items:

- An artwork placeholder.
- The app title and one status line.
- One Play or Stop button.
- The AirPlay route button.
- A **Settings** button in the navigation bar.

All configuration and playback preferences are in the settings sheet. The player screen contains no settings.
The settings sheet contains:

- The stream URL.
- **Extra buffer**: Off, 2, 3, 5, 10, 15 or 30 seconds. The default is 3 seconds.
- **Chime while connecting**. The default is on.

When the extra buffer is not Off, the player does not start until that many seconds of audio are loaded after the current position.
After a stall, the player pauses and waits for the same buffer again.
The player waits at most the buffer plus 5 seconds. Then it starts without the full buffer, so a buffer cannot cause a timeout.
The loaded audio counts from the current position or from the start of a range that begins after it.
The connection timeout is 20 seconds plus the extra buffer.
A buffer change applies at the next connection.

When the chime setting is on, `forcdchime.wav` plays in a loop while the playback state is `connecting`.
This includes the wait for the extra buffer.

The display, chime and buffer logic is in `CitizenRadioCore`:

- `PlayerScreenModel` selects the status text and the Play or Stop control.
- `StreamSettingsDraft` enables **Save**.
- `ChimeSetting` stores the chime setting and selects the states that play the chime.
- `BufferSetting` stores the buffer, measures the loaded audio after the current position, and gives the maximum wait and the timeout.

The SwiftUI views and `RadioPlayer` read these values and contain no other display, chime or buffer rules.

## Alternatives considered

- Set only `preferredForwardBufferDuration`. This value limits how much AVPlayer loads ahead. It does not delay the start, so it does not make a buffer at the start of a live stream.
- Set the default buffer to 0. A small buffer helps in the car. Icecast servers usually send a first burst of a few seconds, so 3 seconds adds a small delay.
- Use a free number field for the buffer. A short list of values is easier to select in a car and easier to test.
- Keep a full list of settings in the decision record. Each new setting would then need a new record.

## Consequences

- An Icecast server sends audio at the stream rate after its first burst. A buffer of N seconds delays the start by about N seconds less the burst.
- A large buffer helps in weak coverage, but playback is that much behind the live stream.
- The first device test with a buffer timed out each time. The cause is not known.
  It is the range measurement, or AVPlayer does not load audio while it is paused.
  The `buffer` log category in subsystem `org.citizenradio.CitizenRadio` records each check to find the cause.
- The app does not show the Shortcuts help or the output device name.

## Invariants

These rules apply while this decision is current.

- The player screen shows only the items in the Decision section.
  Manual check: open the app on an iPhone in portrait and in landscape.
- The player screen contains no settings.
  Manual check: open the app on an iPhone. A test cannot examine the SwiftUI view tree on Linux.
- The Play control is disabled when no stream URL is saved.
  `PlayerScreenModelTests.testPlayIsDisabledWithoutSavedStream` enforces this rule.
- The chime plays only in the `connecting` state and only when the setting is on.
  `ChimeSettingTests.testChimePlaysOnlyWhileConnecting` enforces this rule.
- The default buffer is 3 seconds, and the player starts only when the buffer is loaded.
  `BufferSettingTests` enforces the default and the start condition.
