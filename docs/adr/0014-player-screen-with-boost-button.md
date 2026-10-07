# ADR 0014: Player screen with the Boost button

- Status: accepted. The visual acceptance criteria are open.
- Date: 2026-10-06
- Class: situational. Supersede this record when the primary screen changes, or when a setting moves into or out of the settings sheet.
- Supersedes: [ADR 0010](../archive/adr/0010-player-screen-without-extra-buffer.md)
- Related:
  - [ADR 0008](0008-relay-display-metadata.md) owns the rules for the track data, the artwork and the relay connection.
  - [ADR 0013](0013-boosts.md) owns the boost rules and the boost settings.

## Context

ADR 0010 listed the only items of the player screen. ADR 0013 adds a manual boost, and the listener must reach it with one tap while the radio plays. So this record restates ADR 0010 and adds a **Boost** button.

ADR 0010 removed the **Extra buffer** setting. A device test on 2026-10-04 showed that AVPlayer held about 49 seconds of audio with the buffer set to Off. Each wait after a stall also added to the delay behind the live stream. That decision does not change.

## Decision

The primary screen is a standard music player screen. It shows only these items:

- The track artwork, or the artwork placeholder.
- The track title, or "CitizenRadio" when there is no track.
- The artist, if there is one.
- One status line. It does not show while the stream plays, because the **Stop** button shows that state. It shows while the app connects, waits for the network, is interrupted or fails. Amended 2026-10-07.
- One Play or Stop button.
- The AirPlay route button.
- A **Boost** button. It is active only when the track that the listener hears has a payable payload (ADR 0013 §Manual boost). It opens the boost sheet.
- A **Settings** button in the navigation bar.

All configuration and playback preferences are in the settings sheet. The player screen contains no settings.
The settings sheet contains:

- The stream URL.
- **Track info**: the relay event address. The section also shows the relay status text, if there is one.
- **Chime while connecting**. The default is on.
- The Wallet section. [ADR 0007](0007-nwc-wallet-configuration.md) owns the wallet items. [ADR 0013](0013-boosts.md) owns the boost items.

### Playback

- AVPlayer controls the buffer. The app sets `automaticallyWaitsToMinimizeStalling` and does not hold playback for a buffer of its own.
- After a stall, the playback state is `connecting`, and the app calls `play()` again.
- The connection timeout is 20 seconds, for each connection and each stall.

When the chime setting is on, `forcdchime.wav` plays in a loop while the playback state is `connecting`.

### Track info

`TrackInfoModel` in the app target connects the track data to the player screen and Now Playing:

- It runs the relay client while the playback state is `connecting` or `playing`.
- It applies each streamed display state after the audio that AVPlayer holds ahead of the play position, and a snapshot immediately.
- It selects the relay track or the ICY title, and loads the artwork.
- It gives the title, the artist and the artwork to `RadioPlayer` for Now Playing.

Without a track, Now Playing shows "CitizenRadio" and "Live radio".
`RadioPlayer` makes the `MPMediaItemArtwork` in a `nonisolated static` function.
MediaPlayer calls the artwork handler on a thread that is not the main thread.
A handler that is made in a `@MainActor` context stops the app with a Swift 6 runtime check.

The settings sheet reads the relay event address again when it closes.
If the address changed, `TrackInfoModel` starts the relay client again.

### Core logic

The display and chime logic is in `CitizenRadioCore`:

- `PlayerScreenModel` selects the status text and the Play or Stop control.
- `StreamSettingsDraft` enables **Save**.
- `ChimeSetting` stores the chime setting and selects the states that play the chime.
- `LoadedAudio` measures the loaded audio ahead of the play position, for the display delay.
- `TrackLines` selects the title, the artist and the artwork.
- `RelayStatusText` gives the relay status text for Settings.

The SwiftUI views and `RadioPlayer` read these values and contain no other display or chime rules.

## Alternatives considered

- Keep the extra buffer. The test of 2026-10-04 shows that AVPlayer makes a large buffer without it. The wait after each stall also adds to the delay behind the live stream.
- Keep the extra buffer for the start only. The start of a session is the only time when it can help, but the value is not measured. Add it again only if a test shows fewer stalls.
- Start a new player item when the network path changes. Nothing repeats, but the listener loses the audio of the outage. The operator prefers a repeat to lost audio.
- Join the new connection to the old bytes in the app, so nothing repeats and nothing is lost. A spike on 2026-10-05 showed that AVPlayer does not accept a live MP3 stream from `AVAssetResourceLoaderDelegate`: it reads far into the false length. A join needs a local HLS stream or `AVAudioEngine`, which is a large change.
- Put the manual boost in Settings only. More taps while the listener drives.
- Keep a full list of settings in the decision record. Each new setting would then need a new record.
- Put the track logic in `RadioPlayer`. `RadioPlayer` owns playback and the chime. A model of its own keeps the relay client and the artwork out of the playback code.

## Consequences

- Playback starts when AVPlayer is ready, after the first burst from Icecast.
- During a long session the audio can move further behind the live stream, because AVPlayer waits after each stall. **Stop** and then **Play** connects again near the live position.
- After a network change, AVPlayer connects again and adds the Icecast burst after the audio that it already holds. So the listener can hear a maximum of one burst length a second time. With a `burst-size` of 320,000 bytes at 128 kbps, that is about 20 s. On 2026-10-05 the operator accepted this repeat in place of lost audio. ICY sync keeps the display correct during a repeat.
- An old value of the removed setting can stay in `UserDefaults` under `citizenRadio.bufferSeconds`. The app does not read it.
- The app does not show the Shortcuts help or the output device name.
- The image of the previous track stays until the app loads the new artwork. If the app cannot load the artwork, the screen shows the placeholder.

## Invariants

These rules apply while this decision is current.

- The player screen shows only the items in the Decision section.
  Manual check: open the app on an iPhone in portrait and in landscape.
- The player screen contains no settings. The boost sheet is not a setting: it sends one boost.
  Manual check: open the app on an iPhone. A test cannot examine the SwiftUI view tree on Linux.
- The Play control is disabled when no stream URL is saved.
  `PlayerScreenModelTests.testPlayIsDisabledWithoutSavedStream` enforces this rule.
- The chime plays only in the `connecting` state and only when the setting is on.
  `ChimeSettingTests.testChimePlaysOnlyWhileConnecting` enforces this rule.
- The artwork on the player screen and in Now Playing comes only from `TrackInfoModel`.
  Manual check: examine the code, and make sure that only `PlayerView` and `RadioPlayer.setNowPlayingTrack` read `TrackInfoModel.image`.
  A test cannot examine the iOS app target on Linux.

## Acceptance criteria

### Mechanical

- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- The player screen shows the **Boost** button. It is active only while a V4V track plays, and it opens the boost sheet.
- The open visual criteria of ADR 0010 stay open: the settings sheet shows no **Extra buffer** item; playback starts with no added wait; after a stall, playback continues or shows an error after 20 seconds; and the track info checks of ADR 0009.
