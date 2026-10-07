# Upstream live metadata changes: plan

- Status: proposed, 2026-10-06. This plan does not make rules. It lists the app work that follows from six upstream ADRs.
- Upstream status, 2026-10-06: relay ADR 0004 and ADR 0005, and publisher ADR 0010, ADR 0011 and ADR 0012, are implemented and deployed on `api.musicindex.org`. Relay ADR 0005 is Implemented. The others wait for app checks. Publisher ADR 0009 is Proposed, and no tagger exists.
- Phases 2 and 2b can start. §Available Now gives the live display body.
- Source: `musicindex-live-relay` ADR 0004 and ADR 0005, and `musicindex-live-publisher` ADR 0009, ADR 0010, ADR 0011 and ADR 0012, as written on 2026-10-06.
- Evidence: the research report `~/build/musicindex-research/reports/Live RSS metadata delivery paths.md`.

## Goal

The app gets the artwork, the track text and the payment block of the track that the listener hears. This applies to the ICY stream and to the HLS stream.

## Non-goals

- No Socket.IO client. The app reads the relay with SSE only.
- No change to the app before an upstream ADR is accepted, except the checks in §Phase 1.

## The upstream changes

| Upstream ADR | Change | Effect on this app |
|---|---|---|
| Relay ADR 0004 | Socket.IO waits for the broadcaster delay. SSE is instant. | The app reads SSE, so each display state arrives before the listener hears its track. |
| Publisher ADR 0011 | The publisher sends each block and each display state at once. | Together with relay ADR 0004, the display states on `/display/events` are instant. |
| Publisher ADR 0009 | A tagger writes `TXXX:musicindex` into each HLS segment at the ICY title. `TIT2` keeps the song line. | On HLS, the app can select the track by the frame, with no text match. |
| Publisher ADR 0010 | The Socket.IO payload adds `line`, `author` and `podcastName`. | None. The app does not read Socket.IO. |
| Relay ADR 0005 and publisher ADR 0012 | A display track carries `songLine`, the exact ICY line, and `value {eventGuid, blockGuid}` for a V4V track. | The ICY sync can compare the ICY text with `songLine` by equality. A display state names its payment block. |

## Available now

On 2026-10-06 the operator played two V4V tracks on the live relay. The display state of a V4V track on `GET /v1/liveitems/{event_id}/display` and on `/display/events` had this shape. The poll did not record the artwork, so the example shows only its form:

```json
{
  "track": {
    "artist": "HeyCitizen",
    "title": "The Platform",
    "artwork": {"sha256": "…", "mime": "image/jpeg"},
    "songLine": "HeyCitizen - The Platform",
    "value": {
      "eventGuid": "DFnUwDM1mzcljaF4pI9Q6w",
      "blockGuid": "b3790cee-4849-4cf9-915e-33795268b67b"
    }
  }
}
```

`songLine` is the first line of `now-playing.txt`, the line that `butt` sends to Icecast as `StreamTitle` (publisher ADR 0009 §The Song Line). The ICY sync of ADR 0011 can thus compare the two by equality. A device check of that comparison is open.

These facts were seen on the live relay:

- `value` names the block of the same play. The display state and that block arrive in the same poll of 0.5 seconds.
- A display state can arrive before its block. It then has no `value`. The same state then arrives one more time with `value`.
- A track with no V4V block has `songLine` and no `value`.
- `/display/events` and `/events` are instant. Socket.IO and `GET /remoteValue` wait for `stream_delay_secs` of the broadcaster. The live test used 15 seconds.

`musicindex-live-publisher` ADR 0012 owns the two keys. `musicindex-live-relay` ADR 0005 owns their limits on the wire: `songLine` has 1 to 1,024 characters, and each GUID has 1 to 128 characters.

## Phase 1: checks that need no upstream change

1. On the iPhone, play `https://bastone.heycitizen.xyz/hls/live.m3u8`. Make sure that `IcyMetadataReader` gives the `TIT2` title through `commonKeyTitle`. Make sure that the ICY sync of ADR 0011 shows the artwork in time.
2. Do check 1 again after the test stack writes ID3v2.4 tags. See `~/build/musicindex-stream-test/README.md`, §Open Items.
3. Measure the time from a track change in Mixxx to the moment that the listener hears it, on ICY and on HLS. Record both values.

## Phase 2: after relay ADR 0004 and publisher ADR 0011

The upstream changes are deployed. This phase can start.

The display states become instant. Two rules of ADR 0011 then behave differently:

- **A session with ICY.** No change. Each state now arrives before its ICY title, also for a listener with a short buffer.
- **A session with no ICY.** The ADR 0008 rule applies each streamed state after the audio that AVPlayer holds. The states now arrive earlier by the stream delay. The display thus becomes earlier than the 30 seconds that the test of 2026-10-04 measured. A new app ADR must keep this rule, change it, or remove it.

## Phase 2b: after relay ADR 0005 and publisher ADR 0012

The upstream changes are deployed. This phase can start.

- The ICY sync of ADR 0011 can compare the ICY text with `songLine` by equality, before its text rules. The text rules stay as the fallback for a state with no `songLine`. A new app ADR decides this.
- A display state with `value` names the block of its track. A boost on ICY can then pay that block, not the newest block. The payment record of the app decides this.

## Phase 2c: snapshots and replay on connect

[ADR 0018](../adr/0018-instant-snapshots-and-replay-on-connect.md) decides this phase. Task: [relay replay task 001](../tasks/relay-replay-task-001-metadata-snapshot-and-replay.md).

- The value client reads its snapshot from the instant `GET /metadata`, not from `GET /remoteValue`.
- On connect, each client asks for the recent updates with `Last-Event-ID`. So the ICY sync list and the pairing hold the track that the listener hears, also after a connect near a track change. This applies to Icecast and to HLS.
- Request to the relay: add the display `seq` to the body of `GET /display`. The display replay starts when the relay gives it.
- Not in this phase: `album`. Relay ADR 0006 and publisher ADR 0013 are Proposed.

## Phase 3: after publisher ADR 0009

A new app ADR supersedes ADR 0011 for an HLS session. Its expected content:

1. `IcyMetadataReader`, or a new reader, also reads `TXXX` with the description `musicindex`. The JSON schema is `musicindex.hls/1`. An unknown schema is ignored.
2. With the frame, the app selects the track and the artwork from the frame. With no frame, it uses `TIT2` and the rules of ADR 0011.
3. The app reads the live value from the instant SSE route `/v1/liveitems/{event_id}/events`, not from Socket.IO. It keeps the recent payloads by `blockGuid`.
4. A boost pays the payload whose `eventGuid` and `blockGuid` the frame names. If the app does not hold that payload, it does not pay a different one.
5. A reconnect sends `Last-Event-ID`, so the app gets the payloads that it missed.

Open questions for that ADR:

- Does AVPlayer give the `TXXX` description and text? Publisher ADR 0009 §Before Acceptance item 1 is the check.
- The app then opens two SSE streams for each listener. The relay limit `MAX_SSE_CONNECTIONS` counts both. See stophammer `docs/operations.md`, §Capacity.

## Visual checks

A person must examine these items on an iPhone. Report each one as open until a person completes the check.

- Phase 1: the artwork changes on HLS when the listener hears the new track.
- Phase 2: on ICY, the artwork changes in time for a listener with a short buffer.
- Phase 3: a boost in the first seconds of a new track pays the block of that track.
