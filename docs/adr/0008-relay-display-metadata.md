# ADR 0008: Track metadata and artwork from the relay

- Status: accepted
- Date: 2026-10-04
- Class: situational. Supersede this record when the relay display path changes, or when the app gets track data from a different source.
- Research: [musicindex relay metadata](../research/musicindex-relay-metadata.md)
- Related:
  - [ADR 0004](../archive/adr/0004-player-screen-and-settings.md): this record changes its player screen items. See §Changes at implementation.
  - [ADR 0006](0006-audio-session-off-main-thread.md): blocking calls stay off the main thread.
  - [ADR 0007](0007-nwc-wallet-configuration.md): the payments that use the live value come after this record.

## Context

The player screen shows an artwork placeholder, the title "CitizenRadio" and a status line.
Now Playing shows "CitizenRadio" and "Live radio".
The car shows the same text through Bluetooth.

`musicindex-live-relay` has a display path for a private app that plays a private stream (relay ADR 0003).
For each track, it gives the artist, the title and the artwork.
The publisher holds each update for the stream delay, so that the display changes when the listener hears the track.

The relay sends the display state on SSE only. Its live value, which holds the payment recipients, is on SSE and on Socket.IO.
The research note compares the two transports for a phone in a moving car.

## Decision

### Configuration

- Settings gets a **Track info** field for the relay event URI. `RelayEvent` in `CitizenRadioCore` accepts two forms:
  - the relay event URL: `https://<host>/v1/liveitems/<id>`. The stream producer gives this form.
  - the `podcast:liveValue` URI: `https://<host>/event?event_id=<id>`. The relay README recommends it for RSS.
- `RelayEvent` parses the URI into the origin and the event identifier. It accepts `https` only, and an event identifier that is not empty.
- The stream producer reserves the event. The first station event is `https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w`.
- The URI is stored in UserDefaults. It holds no credential. The read routes need only the event identifier.
- When the field is empty, the app works as before and opens no relay connection.

### Transport

- The app uses SSE for the display path. It does not use Socket.IO.
- `EventStreamParser` in `CitizenRadioCore` parses the SSE text: `event`, `id`, `data` and comment lines.
- `EventStreamClient` in `CitizenRadioCore` keeps one stream open. It uses a `ByteStreamConnecting` protocol, so Linux tests can use a fake connection.
  The app target supplies the `URLSession` byte stream implementation.
- Before the client opens a stream, it reads `GET /v1/liveitems/{event_id}/display` and applies the result at once.
- Reconnect rules:
  - Watchdog: when no byte arrives for 35 seconds, the client closes the stream and reconnects. The relay sends a keepalive comment each 15 seconds, so this is two missed keepalives.
  - Backoff after a failure: 1, 2, 4, 8, 16 and then 30 seconds. A successful snapshot read resets it.
  - A change of the network path (`NWPathMonitor`) starts a reconnect at once.
  - A reconnect sends `Last-Event-ID` with the last display sequence number.
- The client runs only while the playback state is `connecting` or `playing`. Stop closes it.
- `404 event_not_found` and `409 event_not_reserved` stop the client and show a message in Settings. Other errors start the backoff.

### Display data

- `TrackDisplay` in `CitizenRadioCore` decodes the display state: no track, or artist, title and artwork.
  Artwork is a relay image (`sha256` and `mime`), an external `http` or `https` URL, or none.
- Display delay: the app applies each streamed display state when the audio has played the buffered time.
  That time is the audio that AVPlayer holds ahead of the play position when the state arrives (`LoadedAudio.bufferedAhead`).
  A snapshot read after a connect applies at once.
  With ICY in the session, [ADR 0011](0011-icy-sync-of-the-relay-display.md) replaces this rule.
- `{"track": null}` gives the default display: the placeholder, the title "CitizenRadio" and the status line.

### Artwork

- A relay image loads from `GET /v1/liveitems/{event_id}/artwork/{sha256}`. An external URL loads from that URL.
- The app keeps images in a memory cache keyed by the SHA-256 or the URL, with a limit of 8 images.
  A relay image never changes for its hash, so the app does not load it again.
- The app rejects a response larger than 524,288 bytes, or a type that is not JPEG or PNG.
- Download and decode run off the main thread. Only the finished image goes to the main actor.
- A failed image load keeps the placeholder and does not stop the text.

### Player screen and Now Playing

- The artwork area shows the track image, or the placeholder.
- The title line shows the track title, and a second line shows the artist. Without a track, the title line shows "CitizenRadio".
- The status line stays as it is.
- Now Playing gets the track title, the artist and the artwork (`MPMediaItemArtwork`). Without a track, it keeps "CitizenRadio" and "Live radio".
  A car that shows Bluetooth track data then shows the track.

### Fallback: the ICY title

- The app reads the Icecast title from the audio stream with `AVPlayerItemMetadataOutput`.
  Its delegate runs on a private serial queue. Only the parsed result goes to the main actor.
- `IcyTitle` in `CitizenRadioCore` parses `StreamTitle`. The text before the first " - " is the artist, and the rest is the title.
  Without " - ", the full text is the title. An empty text gives no track.
- AVPlayer delivers the ICY title at its play position, so it needs no display delay.
- The app shows the ICY title when it has no relay track. These conditions give no relay track:
  - The **Track info** field is empty.
  - The relay display is `{"track": null}`.
  - The relay client is in backoff or stopped.
    With ICY in the session, backoff keeps the relay track (ADR 0011).
- A relay track always has priority, because it has artwork.

### Module boundaries

- `CitizenRadioCore` holds `RelayEvent`, `EventStreamParser`, `EventStreamClient`, `TrackDisplay`, `IcyTitle`, the delay rule and the source priority rule. Linux tests examine them.
- The app target holds the `URLSession` byte stream, `NWPathMonitor`, the image loader, the `AVPlayerItemMetadataOutput` reader and the views.
- The client is general. The payment record can use it for the live value stream `/events`.

## Non-goals

- The live value and payments. A payment record will use the same client.
- An album field. The display state has none.
- A read token for the relay. Relay ADR 0003 defers it.
- CarPlay screens.

## Alternatives considered

- **Socket.IO.** It does not carry the display state, so the app needs SSE in all cases. Its default heartbeat needs a maximum of 45 seconds to detect a dead connection. An SSE watchdog does it in 35 seconds. iOS has no Socket.IO client, so it adds a third-party package.
- **Polling `GET /display`.** It is simple and it recovers from a dead zone at the next poll. But a 5-second poll adds a maximum of 5 seconds of delay, and it sends a request each 5 seconds for the full drive. Polling stays possible as a fallback if SSE fails on a device.
- **The ICY title as the only source.** It gives no artwork and no separate artist field. It is the fallback.
- **A disk cache for images.** Relay images are small and change with each track. A memory cache is sufficient for one drive.
- **No display delay.** The artwork would then change before the listener hears the track, by the time of the audio that AVPlayer holds.

## Consequences

- The app needs a relay deployment with a reserved event and a publisher with the display path. Neither exists now. Until then, the app works as before.
- The app opens one more network connection while it plays. The relay host uses HTTP/1.1, so each SSE stream is one connection. It uses mobile data for SSE keepalives and images.
- Two relay errors stop the client: `404 event_not_found` and `409 event_not_reserved`. The operator must reserve the event.
- After a relay restart, the display is empty until the next publish. The app shows the default display then.

## Invariants

These rules apply while this decision is current.

- No network call, image download or image decode runs on the main thread.
- The app opens no relay connection when the **Track info** field is empty, or while playback is stopped.
- A relay track has priority over the ICY title.
- The `AVPlayerItemMetadataOutput` delegate does not run on the main thread.
- The client reconnects after 35 seconds without a byte.
- A streamed display state applies after the buffered audio time. A snapshot applies at once.
- An image larger than 524,288 bytes, or not JPEG or PNG, is not shown.

## Acceptance criteria

### Mechanical

Each criterion has a test in `Tests/CitizenRadioCoreTests/`.

- `RelayEvent` accepts the relay event URL and the `podcast:liveValue` URI, and rejects `http`, a missing event identifier and a different path.
- `IcyTitle` parses "Artist - Title", a text without " - ", a text with two " - ", and an empty text.
- The source priority rule gives the relay track when there is one, and else the ICY title.
- `EventStreamParser` gives events with `event`, `id` and `data`, joins two `data` lines with a line feed, and ignores comments.
- `TrackDisplay` decodes the three artwork forms and `{"track": null}`, and rejects a `data:` URL.
- `EventStreamClient` with a fake connection:
  - reads the snapshot before it opens the stream
  - sends `Last-Event-ID` after a reconnect
  - reconnects after 35 seconds without a byte (with a test clock)
  - follows the backoff sequence, and resets it after a successful snapshot
  - stops on `404 event_not_found` and on `409 event_not_reserved`
  - closes the stream on stop
- The delay rule applies a streamed state after the given buffered time and a snapshot at once.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until that examination is complete.

- With a configured relay, the artwork, title and artist change when the listener hears the new track.
- The lock screen and the car show the track title and artist.
- After a drive through a dead zone, the display is correct within 40 seconds after the audio returns.
- With an empty **Track info** field, the title and artist come from the ICY title, and the artwork area shows the placeholder.

## Changes at implementation

ADR 0004 describes the present player screen until the code changes. So these changes go in the commit of the first task that changes the player screen:

- Done: ADR 0004 is in the archive. [ADR 0009](../archive/adr/0009-player-screen-with-track-info.md) restated ADR 0004 with the new artwork, title and artist items, and the **Track info** setting.
- Done: the architecture overview, the README and the runbook have the relay setup and the device checks.
