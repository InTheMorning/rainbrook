# Research: track metadata and artwork from musicindex-live-relay

- Date: 2026-10-04.
- Status: research note. It makes no rule. [ADR 0008](../adr/0008-relay-display-metadata.md) uses it.
- Sources, read on 2026-10-04:
  - `musicindex-live-relay` at commit `1a866c6`: `docs/interoperability.md`, `docs/adr/0003-display-state-and-artwork.md`, `README.md`, `src/lib.rs`, `hgh-example-1.json`.
  - `musicindex-live-publisher` at commit `56b0f3f`: `docs/adr/0008-display-path.md`.

## Question

How can CitizenRadio get the artwork and the track text of the track that plays, and the payment data for each V4V track?

## The broadcast chain

```text
v4vmm (writes MusicIndex tags)
  -> a player (Mixxx, mpv or liquidsoap)
  -> the producer (now-playing drop file)
  -> musicindex-live-publisher (holds each update for the stream delay)
  -> musicindex-live-relay
       -> listener apps
```

The relay holds two separate data paths for one live event.

| Path | Content | Tracks | Read routes |
| --- | --- | --- | --- |
| Display state (relay ADR 0003) | artist, title, artwork | every track | `GET /v1/liveitems/{event_id}/display`, SSE `GET …/display/events` |
| Live value (`remoteValue`) | title, `image` URL, text lines, link, `value.destinations` | V4V tracks only | `GET …/remoteValue`, SSE `GET …/events`, Socket.IO namespace `/event` |

Relay ADR 0003 names its user: "a private app that plays a private stream". That app shows the Icecast title, the artwork and track text of each track, and the live value only while a V4V track plays.

## The display state

One SSE event:

```text
event: display
id: <display seq>
data: {"track":{"artist":"Artist","title":"Title","artwork":{"sha256":"<64 hex>","mime":"image/jpeg"}}}
```

- `track` is `null` when nothing plays. A lease expiry also sets `{"track": null}`.
- `artwork` has three forms:
  - `{"sha256", "mime"}`: the image is at `GET /v1/liveitems/{event_id}/artwork/{sha256}`. The response has `Cache-Control: public, max-age=31536000, immutable`, so a client can keep it in a cache by its hash.
  - `{"url"}`: an `http` or `https` URL on a different host. The client loads it.
  - `null`: the track has no image.
- The display state has no album field.
- The stream keeps its own sequence number and replays the last 100 states after a `Last-Event-ID`.
- The publisher takes the MusicIndex image URL of a V4V track. For other tracks, it takes the embedded front cover, as JPEG or PNG and at most 524,288 bytes.

## The live value

The live value has the Split Kit and podcast 2.0 `liveValue` shape. `value.destinations` holds the keysend recipients: `address`, `split`, and optional `customKey` and `customValue`. This is the data for streaming payments. Between V4V tracks, no live value plays.

## Conditions

1. Only a reserved event has a display state. An ephemeral event answers `409 event_not_reserved`. Only the operator makes a reserved event, with the admin token.
2. The relay AGENTS.md states that no one runs the relay in production, and that the reserved class is not deployed on a host.
3. The display state and the images are in memory only. After a restart, the display gives `{"track": null}` until the next publish, and the sequence number starts at zero again.
4. The publisher holds each update for the stream delay of its target, so that the display changes when the listener hears the new track. The CitizenRadio extra buffer adds more audio delay. Without a correction, the artwork changes early by the buffered time.
5. The read routes need only the event identifier, which has 128 random bits. A read token is deferred in relay ADR 0003.
6. The README recommends the event URI form `https://<host>/event?event_id=<id>` in `podcast:liveValue`.

## Transport: SSE and Socket.IO in a moving car

In a car, the phone changes cell towers, loses coverage, and changes its IP address. A TCP connection often stops with no error and no data.

| Property | SSE | Socket.IO |
| --- | --- | --- |
| Carries the display state | Yes | No |
| Dead connection detection | The app watches the keepalive comments. The relay sends one each 15 seconds (axum `KeepAlive::default()`). | Built in. `socketioxide` 0.18 defaults: ping each 25 seconds, timeout 20 seconds, so a maximum of 45 seconds. |
| Reconnect and backoff | The app writes them. | Built in. |
| State after a reconnect | Replay from `Last-Event-ID`, and a snapshot read | The current `remoteValue` at connect |
| iOS client | `URLSession` byte stream. No package. | A third-party package (`socket.io-client-swift` with Starscream), or the Engine.IO protocol written by hand |
| Connections for both paths | Two streams. They share one connection only with HTTP/2 at the proxy. | One for the live value, plus SSE for the display |

The keepalive interval and the ping values come from the library defaults, because the relay source does not set them.

The deciding facts:

- Socket.IO does not carry the display state, so the app needs SSE in all cases.
- An SSE watchdog on the 15-second keepalive detects a dead connection faster than the Socket.IO default heartbeat.
- The reconnect logic is necessary for SSE in all cases. Linux tests can examine it with a fake connection.

In a dead zone, the audio also stops when its buffer is empty. After a reconnect, a snapshot read gives the correct track at once, with each transport.

## Open points outside CitizenRadio

- A relay deployment with a reserved event for the station.
- A publisher with the display path enabled for that event.
