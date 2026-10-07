# Proposal: CurioHoster live value support

- Status: advisory draft, 2026-10-06. This document is not a decision of CitizenRadio, and it makes no rule for this app.
- Purpose: a future music player that reuses the code of this app can accept this document as one of its ADRs. Before that, examine each fact again, because CurioHoster can change.
- Sources:
  - `musicindex-live-relay`: `docs/research/curiohoster-livevalue-socketio-examples.md`, with the capture of 2026-10-06.
  - Podcast namespace discussion #547, for the `podcast:liveValue` tag.
- Related records of this app: [ADR 0008](../adr/0008-relay-display-metadata.md), [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md), [ADR 0013](../adr/0013-boosts.md), [ADR 0015](../adr/0015-artwork-from-url-and-animated-gif.md), [ADR 0017](../adr/0017-stations-with-alternate-stream.md).

## Context

A live RSS item can name a live value source with this tag:

```xml
<podcast:liveValue uri="https://curiohoster.com/event?event_id=…" protocol="socket.io"/>
```

CitizenRadio reads only the musicindex relay. The relay gives a display state on `/display` and the payment payload on `/events`, both with SSE. CurioHoster gives one payload, through Socket.IO only.

Facts about CurioHoster, as seen on 2026-05-15 and 2026-10-06:

- **Connection:** Engine.IO version 4 with the polling transport. The `event_id` query item must be in the first request, before the server gives the `sid`. Else the payload can be an empty `{}`.
- **Namespace and event:** the client connects to the namespace `/event` with the packet `40/event,`, and receives `42/event,["remoteValue", {…}]`.
- **Initial payload:** the server sends the current block immediately after the connection.
- **Packets:** one polling answer can hold more than one Engine.IO packet, separated by the record separator character (0x1E).
- **Payload fields:** `image`, `title`, `line`, `description`, `value`, `type`, `link`, `chaptersUrl`, `enclosureUrl`, `feedGuid`, `itemGuid`, `eventGuid`, `eventAPI`, `duration`, `blockGuid`, `settings`, `startTime` and `eventTimestamp`. Some payloads also have `feedUrl` and `medium`.
- **Music track:** `title` is the song, `line` is `[album, artist]`, and `image` is the album art.
- **Value:** `value` can be flat (`{type, method, destinations}`) or nested (`{model: {type, method}, destinations}`). A `split` can be a number or a string in the same stream.
- **Timing:** `eventTimestamp` is `0`. No field places a block on the audio timeline of a listener.
- **Other blocks:** a `type` of `chapter` can be a value prompt or a chat prompt. It is not a song.

What the code of this app can reuse:

- `LiveValuePayload.decode` reads `title`, `eventGuid`, `blockGuid`, `feedGuid`, `itemGuid` and `value.destinations`, with both forms of `value` and both forms of `split`.
- `BoostPairing`, `BoostSplit`, `BoostPayer`, `BoostHistory` and the retry of ADR 0016 do not depend on the source of the payload.
- `ArtworkLoader` loads a URL image, also an animated GIF (ADR 0015).
- `IcySync` releases a display state when the ICY title names it (ADR 0011).

## Proposed decision

### Source

- A station can name a live value source of the type `socket.io`, from the `uri` of `podcast:liveValue`, in place of a musicindex relay event.
- The player accepts only `https` for the source.

### Client

- A Socket.IO client for the Engine.IO polling transport, with `URLSession` and no added library:
  1. `GET /socket.io/?event_id=…&EIO=4&transport=polling`. Read the `sid`, the `pingInterval` and the `pingTimeout` from the open packet.
  2. `POST` the packet `40/event,` with the same query and the `sid`.
  3. Send `GET` polls in sequence. Split each answer at 0x1E. Answer each ping packet `2` with a pong packet `3`.
  4. Send each `42/event,["remoteValue", …]` payload to `LiveValuePayload.decode`. An empty `{}` changes nothing.
  5. After a connection failure, connect again with a backoff, as `EventStreamClient` does.
- The client runs off the main actor. It replaces the relay value client for this source. It does not run in addition to it.

### Display

- A payload with `type` other than `chapter` gives a display state:
  - title: `title`.
  - artist: `line[1]`, if present.
  - album: `line[0]`, if present.
  - artwork: `image`, as a URL image of ADR 0015.
- The key of the state for the ICY sync is `artist - title`, as in ADR 0011. The player does not show a state until the ICY title names it.
- A `chapter` payload gives no display state. A `chapter` payload with payable destinations is a value prompt. The player can show it as a boost target, but auto-boost never pays it.

### Pairing and payment

- The display state carries `value {eventGuid, blockGuid}` from its payload. So the pairing of ADR 0013 pays the exact block.
- The payment rules of ADR 0013 and ADR 0016 do not change.

## Alternatives considered

- **A Socket.IO library.** It adds a dependency and a WebSocket stack. The polling transport needs only HTTP.
- **The musicindex relay as a proxy for CurioHoster.** The player then depends on one more server. The relay passes its own payloads through and does not read CurioHoster.
- **Show the payload when it arrives.** With `eventTimestamp` 0, the payload can arrive before the listener hears the track. The ICY sync gives the correct time.

## Consequences

- The player can show and pay CurioHoster events, also with no musicindex relay.
- The album name becomes available from `line[0]`. The musicindex relay display state has the optional key `album` (relay ADR 0006), so the two sources agree.
- A stream with no ICY title has no release signal. The player then shows each state when it arrives, early by the stream delay.
- The polling transport makes one request each poll interval. Each listener adds load on CurioHoster.

## Open questions

- Does CurioHoster also give the WebSocket transport, and does its polling answer stay open for a long time? Measure before the task packets.
- Does the ICY text of a CurioHoster station agree with `line[1] - title`? Examine one live event.
- Does a payload ever give the revised shape of 2026-03-19, with `author` and `podcastName`? Then the artist comes from `author`.

## Acceptance criteria for the future ADR

### Mechanical

- Engine.IO packet parsing, with more than one packet in an answer, the ping and the pong. Tests with fixed packets.
- The display state from a song payload and no state from a `chapter` payload. Tests with the payloads of the 2026-10-06 capture.
- `LiveValuePayload.decode` with the nested `value`, the flat `value`, and number and string splits. Tests with fixed payloads.

### Visual

- A CurioHoster station shows the song, the artist and the album art when the listener hears the song.
- A boost on a CurioHoster track pays the recipients of its block.
