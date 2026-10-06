> Archived: superseded by [ADR 0010](0010-player-screen-without-extra-buffer.md) on 2026-10-05.

# ADR 0009: Player screen with track info

- Status: superseded by [ADR 0010](0010-player-screen-without-extra-buffer.md)
- Date: 2026-10-04
- Class: situational. Supersede this record when the primary screen changes, or when a setting moves out of the settings sheet.
- Supersedes: [ADR 0004](0004-player-screen-and-settings.md)
- Related: [ADR 0008](../../adr/0008-relay-display-metadata.md) owns the rules for the track data, the artwork and the relay connection.

## Context

ADR 0004 gave the player screen an artwork placeholder and the fixed title "CitizenRadio".
ADR 0008 adds track data from the relay, with the ICY stream title as the fallback.
So the player screen and Now Playing must show the track, and the settings sheet gets the **Track info** field.
This record restates ADR 0004 with these changes.

## Decision

The primary screen is a standard music player screen. It shows only these items:

- The track artwork, or the artwork placeholder.
- The track title, or "CitizenRadio" when there is no track.
- The artist, if there is one.
- One status line.
- One Play or Stop button.
- The AirPlay route button.
- A **Settings** button in the navigation bar.

All configuration and playback preferences are in the settings sheet. The player screen contains no settings.
The settings sheet contains:

- The stream URL.
- **Track info**: the relay event address. The section also shows the relay status text, if there is one.
- **Extra buffer**: Off, 2, 3, 5, 10, 15 or 30 seconds. The default is 3 seconds.
- **Chime while connecting**. The default is on.
- The Wallet section. [ADR 0007](../../adr/0007-nwc-wallet-configuration.md) owns its content.

When the extra buffer is not Off, the player does not start until that many seconds of audio are loaded after the current position.
After a stall, the player pauses and waits for the same buffer again.
The player waits at most the buffer plus 5 seconds. Then it starts without the full buffer, so a buffer cannot cause a timeout.

The loaded audio counts from the current position or from the start of a range that begins after it.
The connection timeout is 20 seconds plus the extra buffer.
A buffer change applies at the next connection.

When the chime setting is on, `forcdchime.wav` plays in a loop while the playback state is `connecting`.
This includes the wait for the extra buffer.

### Track info

`TrackInfoModel` in the app target connects the track data to the player screen and Now Playing:

- It runs the relay client while the playback state is `connecting` or `playing`.
- It applies each streamed display state after the buffered audio time, and a snapshot immediately.
- It selects the relay track or the ICY title, and loads the artwork.
- It gives the title, the artist and the artwork to `RadioPlayer` for Now Playing.

Without a track, Now Playing shows "CitizenRadio" and "Live radio".
`RadioPlayer` makes the `MPMediaItemArtwork` in a `nonisolated static` function.
MediaPlayer calls the artwork handler on a thread that is not the main thread.
A handler that is made in a `@MainActor` context stops the app with a Swift 6 runtime check.

The settings sheet reads the relay event address again when it closes.
If the address changed, `TrackInfoModel` starts the relay client again.

### Core logic

The display, chime and buffer logic is in `CitizenRadioCore`:

- `PlayerScreenModel` selects the status text and the Play or Stop control.
- `StreamSettingsDraft` enables **Save**.
- `ChimeSetting` stores the chime setting and selects the states that play the chime.
- `BufferSetting` stores the buffer, measures the loaded audio after the current position, and gives the maximum wait and the timeout.
- `TrackLines` selects the title, the artist and the artwork.
- `RelayStatusText` gives the relay status text for Settings.

The SwiftUI views and `RadioPlayer` read these values and contain no other display, chime or buffer rules.

## Alternatives considered

- Set only `preferredForwardBufferDuration`. This value limits how much AVPlayer loads ahead. It does not delay the start, so it does not make a buffer at the start of a live stream.
- Set the default buffer to 0. A small buffer helps in the car. Icecast servers usually send a first burst of a few seconds, so 3 seconds adds a small delay.
- Use a free number field for the buffer. A short list of values is easier to select in a car and easier to test.
- Keep a full list of settings in the decision record. Each new setting would then need a new record.
- Put the track logic in `RadioPlayer`. `RadioPlayer` owns playback, the buffer and the chime. A model of its own keeps the relay client and the artwork out of the playback code.

## Consequences

- An Icecast server sends audio at the stream rate after its first burst. A buffer of N seconds delays the start by about N seconds less the burst.
- A large buffer helps in weak coverage, but playback is that much behind the live stream.
- The first device test with a buffer timed out each time. The cause is not known.
  It is the range measurement, or AVPlayer does not load audio while it is paused.
  The `buffer` log category in subsystem `org.citizenradio.CitizenRadio` records each check to find the cause.
- The app does not show the Shortcuts help or the output device name.
- The image of the previous track stays until the app loads the new artwork. If the app cannot load the artwork, the screen shows the placeholder.

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
- The artwork on the player screen and in Now Playing comes only from `TrackInfoModel`.
  Manual check: examine the code, and make sure that only `PlayerView` and `RadioPlayer.setNowPlayingTrack` read `TrackInfoModel.image`.
  A test cannot examine the iOS app target on Linux.

## Acceptance criteria

### Mechanical

- `RelayStatusTextTests` covers each status text.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- With the station event in **Track info**, the artwork, the title and the artist show. They change when the listener hears the new track.
- The lock screen and the car show the track title, the artist and the artwork.
- With an empty **Track info** field, the title and the artist come from the stream title, and the artwork area shows the placeholder.
- After Stop and then Play, the display is correct again.
