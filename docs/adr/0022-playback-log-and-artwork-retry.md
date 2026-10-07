# ADR 0022: Playback log and artwork retry

- Status: accepted
- Date: 2026-10-07
- Class: situational. Supersede this record when the diagnosis tools or the artwork load rules change.
- Related:
  - [ADR 0015](0015-artwork-from-url-and-animated-gif.md): the artwork load.
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the ICY text and the relay track selection.
  - [ADR 0020](0020-stream-quality-and-hls-live-offset.md) and [ADR 0021](0021-stalls-on-a-bad-network.md): the playback events.
  - [ADR 0006](0006-audio-session-off-main-thread.md): the file write stays off the main thread.
- Task: [diagnosis task 001](../tasks/diagnosis-task-001-playback-log-and-artwork-retry.md)

## Context

On 2026-10-07 the operator tested network gaps on HLS, with the iPhone on a cable to the development computer.

- In two runs with `idevicesyslog`, a gap of 15 seconds gave no jump. The `playback` log showed no stall and no time jump.
- In other runs, the same gap gave a jump back, some seconds at a lower quality, then a second jump back. No log ran during those runs, so the cause is not known.
- After the return of the network, the artwork was missing until the next track.

`TrackInfoModel.loadArtwork` loads the artwork only when the artwork of the lines changes. If that load fails, the image stays empty. A load at the moment that the network returns can fail.

The operator does not always have the development computer. A log that the app keeps itself is necessary to find a problem that occurs only sometimes.

## Decision

### The playback log

- The app keeps the last 500 playback events, oldest first. Each event has the time and one line of text.
- The events:
  - each event of the `playback` log category of `RadioPlayer`.
  - each ICY text, each change of the selected relay track (its key, or none), and each change of the artwork of the lines.
  - each artwork load result: the source kind (relay or URL), success or failure, and the attempt number.
  - each status change of the display client and of the value client.
- The log is in a file in the Application Support folder of the app. The file write occurs off the main actor, a maximum of one time each 5 seconds, and when the app goes to the background.
- **Settings › Playback log** shows the events, newest last, with **Share** and **Clear**.
- The log contains track titles. It contains no secret, no wallet data and no boost message. It stays on the phone. Only the operator can share it, with **Share**.

### The artwork retry

- An artwork load can give no image while the lines keep the same artwork. Then the app loads it again after 2, 5, 10 and 30 seconds. Then it stops until the artwork changes.
- When the network path becomes satisfied, and the lines have an artwork with no image, the app loads it again at once.
- While a retry waits, the screen keeps the placeholder.

## Alternatives considered

- **`idevicesyslog` only.** It needs the cable and the computer, and the problem did not occur in the logged runs.
- **A log with no titles.** The missing artwork depends on the ICY text and the selected track. The log needs them.
- **Retry with no limit.** An image that the policy rejects, for example a format that is not permitted, fails each time.

## Consequences

- The operator can send a log after a problem in the car or on the street.
- The log file holds a maximum of about 100 KB.
- A missing artwork comes back by itself when the network returns.

## Invariants

These rules apply while this decision is current.

- The log keeps the last 500 events in sequence. `PlaybackLogTests` enforces it.
- The retry intervals and their end. `ArtworkRetryTests` enforces them.
- The file write is off the main actor. Manual check: examine the log store.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- **Settings › Playback log** shows the events of a network gap, and **Share** sends them.
- After a network gap of 15 seconds, the artwork shows within 30 seconds after the return of the network.
