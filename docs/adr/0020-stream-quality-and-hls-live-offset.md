# ADR 0020: Stream quality and the HLS live offset

- Status: accepted
- Date: 2026-10-07
- Class: situational. Supersede this record when the stream variants, the quality choices or the buffer rule change.
- Related:
  - [ADR 0017](0017-stations-with-alternate-stream.md): the fallback after a stall of 20 seconds does not change.
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the HLS title releases each display state, so a longer delay keeps the display correct.
  - [ADR 0006](0006-audio-session-off-main-thread.md): blocking work stays off the main thread.
- Task: [stream quality task 001](../tasks/stream-quality-task-001-quality-and-live-offset.md)

## Context

On 2026-10-07 the operator asked for a choice of HLS bitrate, and for better buffering on a bad network.

Facts on 2026-10-07:

- The HLS master playlist had one variant, AAC 128 kbps (`BANDWIDTH=140800`). AVPlayer could not change to a lower bitrate.
- The live window was 6 segments of 2 seconds, 12 seconds. A live HLS player buffers only the audio between its position and the live edge. AVPlayer starts about 3 segments behind the live edge, so it held about 6 seconds. A network problem of more than 6 seconds gave a stall.
- The operator changes the liquidsoap output of `musicindex-stream-test` to three variants (AAC 48k, 96k and 128k) and a window of 30 segments of 4 seconds. That change is outside this app.
- `AVPlayerItem.preferredPeakBitRate` sets a maximum bitrate for the variant selection. 0 means no maximum.
- `AVPlayerItem.configuredTimeOffsetFromLive` sets the distance from the live edge. With `automaticallyPreservesTimeOffsetFromLive`, the player goes back to that distance after a stall. An Icecast stream has no live edge, and AVPlayer ignores the two properties for it.

## Decision

### Stream quality

Amended 2026-10-07. The first form of this section had Auto, Medium and Low as maximum values for `preferredPeakBitRate`. A test on HLS showed a problem. After a network gap of 15 seconds, AVPlayer changed from the 96k variant to the 48k variant and back. Each change was a jump back in the audio.

During the gap each reload of the playlist of the variant failed, and AVPlayer then changed to a different variant. A maximum value does not prevent this, because two variants stay below 120,000 bits each second.

- A **Stream quality** setting in Settings, for each station together:
  - **High**: the variant with the highest bandwidth.
  - **Medium**: the variant with the highest bandwidth of 120,000 or less. The default.
  - **Low**: the variant with the highest bandwidth of 64,000 or less.
- For High, Medium and Low, the app reads the master playlist of the stream before playback. It gives AVPlayer the media playlist of the selected variant only. So AVPlayer has no other variant to change to.
  - If no variant has a bandwidth at or below the limit, the app selects the variant with the lowest bandwidth.
  - If the URL is not a master playlist, or the read fails, the app plays the URL as it is. Then the maximum value of the setting applies with `preferredPeakBitRate`: High none, Medium 120,000, Low 64,000.
- The app reads the master playlist of each stream of the station when playback starts, and keeps the result for that playback session. The reads run at the same time, with a time limit of 5 seconds. So they leave a minimum of 15 seconds of the connection time limit of ADR 0021. A fallback and a new item of ADR 0021 use it.
- A change of the setting applies at the next **Play**.
- The setting applies to HLS. An Icecast stream has one bitrate, and the setting has no effect on it.
- A saved Medium or Low keeps its value. A saved Auto gives Medium.
- There is no Auto choice. With the master playlist, AVPlayer changes the variant by itself, and a change can give a jump. A lower bitrate helps only on a very slow or throttled network, and the operator can then select Low. Removed 2026-10-07 by the operator.

### The HLS live offset

- A **HLS buffer** setting in Settings: 10, 30, 60 or 90 seconds. The default is 30 seconds. Added 2026-10-07.
- Each new player item gets `configuredTimeOffsetFromLive` from the setting, and `automaticallyPreservesTimeOffsetFromLive` false. So the offset applies at the start only.
  - Changed 2026-10-07 from true. With true, a network gap of 15 seconds on HLS gave two jumps back: a few seconds of repeated audio at a lower quality, then a second repeat. During the gap the player cannot load the playlist, so the live edge that it knows stops moving. The distance appears to become smaller, and the player moves back to keep the offset.
  - After a stall, playback stays behind live by the length of the stall, until the next **Play**. If playback falls behind the live window, the segment requests fail, and ADR 0021 makes a new item at the configured offset.
- Each new player item also gets `preferredForwardBufferDuration` equal to the setting. The offset only permits the buffer. This property asks AVPlayer to load that much audio ahead. Added 2026-10-07.
- A change of the setting applies at the next **Play**, because AVPlayer reads the offset when a stream starts.
- The largest value is 90 seconds. The server window of 2 minutes needs some segments of space behind the player.
- If the live window is shorter, AVPlayer uses the largest offset that the window permits.

## Alternatives considered

- **Auto, the master playlist.** AVPlayer adapts the bitrate to the network, but a change of variant after a network gap gave jumps back. Removed 2026-10-07.
- **A quality for each station.** The network, not the station, decides the correct quality. One setting is simpler.
- **Only `preferredForwardBufferDuration`, with no offset.** A live player cannot buffer audio that the server does not yet have. The offset from the live edge makes the space for the buffer, and this property fills it.
- **A fixed offset.** The operator asked for a choice. 30 seconds stays the default, because it is more than most network problems on a phone, and a larger value adds delay.

## Consequences

- On HLS, the listener hears the audio about 25 seconds later than before. The display and the boosts follow the HLS title, so they stay correct.
- A network problem of less than about 30 seconds gives no stall on HLS. The fallback of ADR 0017 then occurs less often.
- **Low** uses about 22 MB of data for each hour, and the 128k variant uses about 63 MB.
- The setting has no effect until the server gives more than one variant.

## Invariants

These rules apply while this decision is current.

- The four choices, the variant selection, their maximum values and the default. The four buffer values and the default of 30 seconds. `StreamQualityTests` enforces them.
- The live offset and the quality on each new player item, and the quality change on the item that plays. Manual check: examine `RadioPlayer`.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- On HLS with **Low**, the stream plays at 48k. The server log shows requests for `aac_low` segments.
- On HLS, a network problem of 15 seconds, for example flight mode on and off, gives no stall.
- On Icecast, playback works as before with each setting.
