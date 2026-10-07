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

- A **Stream quality** setting in Settings, for each station together:
  - **Auto**: no maximum. The default.
  - **Medium**: a maximum of 120,000 bits each second.
  - **Low**: a maximum of 64,000 bits each second.
- The app sets `preferredPeakBitRate` of each new player item from the setting. A change of the setting applies to the item that plays, with no restart.
- The setting applies to HLS. An Icecast stream has one bitrate, and the setting has no effect on it.
- With the variants of 2026-10-07, **Low** selects the 48k variant and **Medium** selects the 96k variant. AVPlayer selects a lower variant when the network is slow, with each setting.

### The HLS live offset

- A **HLS buffer** setting in Settings: 10, 30, 60 or 90 seconds. The default is 30 seconds. Added 2026-10-07.
- Each new player item gets `configuredTimeOffsetFromLive` from the setting, and `automaticallyPreservesTimeOffsetFromLive` true.
- A change of the setting applies at the next **Play**, because AVPlayer reads the offset when a stream starts.
- The largest value is 90 seconds. The server window of 2 minutes needs some segments of space behind the player.
- If the live window is shorter, AVPlayer uses the largest offset that the window permits.

## Alternatives considered

- **No setting, Auto only.** The operator asked for a choice. Low also limits the mobile data.
- **A quality for each station.** The network, not the station, decides the correct quality. One setting is simpler.
- **A larger `preferredForwardBufferDuration`.** A live player cannot buffer audio that the server does not yet have. The offset from the live edge is the buffer.
- **A fixed offset.** The operator asked for a choice. 30 seconds stays the default, because it is more than most network problems on a phone, and a larger value adds delay.

## Consequences

- On HLS, the listener hears the audio about 25 seconds later than before. The display and the boosts follow the HLS title, so they stay correct.
- A network problem of less than about 30 seconds gives no stall on HLS. The fallback of ADR 0017 then occurs less often.
- **Low** uses about 22 MB of data for each hour, and the 128k variant uses about 63 MB.
- The setting has no effect until the server gives more than one variant.

## Invariants

These rules apply while this decision is current.

- The three choices, their maximum values and the default. The four buffer values and the default of 30 seconds. `StreamQualityTests` enforces them.
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
