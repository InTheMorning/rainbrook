# ADR 0018: Instant snapshots and replay on connect

- Status: accepted
- Date: 2026-10-06
- Class: situational. Supersede this record when the relay routes, their timelines or their replay rules change.
- Related:
  - [ADR 0008](0008-relay-display-metadata.md) §Transport: this record adds the replay rule and the snapshot error rule for the value client.
  - [ADR 0013](0013-boosts.md): this record replaces its fact that the app reads the live value from `GET /remoteValue`.
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the ICY sync list gets the replayed display states.
  - [Upstream live metadata plan](../plans/upstream-live-metadata-plan.md)
- Task: [relay replay task 001](../tasks/relay-replay-task-001-metadata-snapshot-and-replay.md)

## Context

Relay ADR 0004 is deployed. The relay has two timelines (relay README, §The Listener Timeline):

- Instant: `GET /metadata`, the SSE `/events`, `GET /display` and `/display/events`.
- Listener: `GET /remoteValue` and Socket.IO. They wait for the delay of the broadcaster, now 15 seconds.

The live value client of the app reads its snapshot from `GET /remoteValue`, on the listener timeline. The display client reads its snapshot from `GET /display`, on the instant timeline. After a connect, the two snapshots can name different blocks. Then `BoostPairing.payload(for:)` gives nil for the present relay track, and the **Boost** button is not active for the first track. Auto-boost does not pay the first track of a session (ADR 0013 trigger rule 1), so only the manual boost has this problem.

A second problem stays after the two snapshots agree. The snapshots are instant, and the listener hears each track later. If a connect occurs after the publisher changed the track, and before the listener hears the change, each snapshot names the next track. The ICY sync list then has no state for the track that plays, and the pairing has no payload for it. This applies to Icecast and to HLS. On HLS the window is longer, because of the segments.

Relay facts, examined in the relay source on 2026-10-06:

- `GET /metadata` gives `{"event_id", "seq", "updated_at", "renewed_at", "lease_expires_at", "metadata": {<payload>}}`.
- `GET /metadata` gives `404` with `metadata_not_found` when the event has no payload, for example after a lease end or a relay restart. It gives `404` with `event_not_found` when the event does not exist.
- `/events` and `/display/events` each keep the last 100 updates. With `Last-Event-ID: N`, a stream first sends each kept update with a `seq` greater than N, in sequence, then the new updates. The relay accepts each whole number for N.
- `/events` sends no update at connect when there is no `Last-Event-ID`.
- `GET /display` gives `{"track": …}` with no `seq`.

## Decision

### The value snapshot

- The value client reads its snapshot from `GET /v1/liveitems/{id}/metadata`. The app gives only the `metadata` object to `LiveValuePayload.decode`.
- A `404` snapshot with the error code `metadata_not_found` is not an error. The client opens the stream with no snapshot.
- A `404` with `event_not_found` and a `409` stop the client, as ADR 0008 says.
- The display client keeps the ADR 0008 rules for its snapshot.
- The app does not read `GET /remoteValue`.

### The replay on connect

- This rule applies when the client has no last event ID, and its snapshot has a whole-number `seq` S.
  - The client opens the stream with `Last-Event-ID` equal to S minus the replay count, with a minimum of 0.
- The replay count is 8 for the value client, the size of the pairing list. It is 4 for the display client, the size of the ICY sync list.
- A streamed event with an ID of S or less is a replayed event.
  - A replayed display state goes into the ICY sync list only. It never applies to the screen by the delay rule of ADR 0008.
  - A replayed display state is never the relay track of a session with no ICY.
  - A replayed value payload goes into the pairing, as each other payload does.
- A reconnect sends the last event ID, as ADR 0008 says. It makes no replay of this kind.
- A snapshot with no `seq` gives no replay. `GET /display` has no `seq` on 2026-10-06, so the display replay starts only when the relay adds it. The app needs no other change then.

## Alternatives considered

- **`Last-Event-ID: 0` on connect.** It sends a maximum of 100 updates for each connect, and the app cannot tell a replayed state from a new state.
- **Keep `GET /remoteValue` and wait for its delay.** The delay of the broadcaster does not agree with the delay of each listener.
- **A second connection to find the display `seq`.** It uses two SSE connections of the relay limit for each listener.

## Consequences

- After a connect, the value snapshot and the display snapshot name the same block. The **Boost** button works for the first track, outside the window above.
- The pairing holds the blocks of the last 8 updates, so a boost for the track that plays finds its payload in the window.
- The display part of the window stays until the relay gives `seq` in `GET /display`. In that window the ICY sync has no state for the track that plays, so the manual boost of that track is still not possible.
- A connect reads a maximum of 8 more value updates. When the relay gives the display `seq`, it also reads a maximum of 4 more display states.

## Invariants

These rules apply while this decision is current.

- The `/metadata` snapshot, its `metadata` object and the two `404` rules. `EventStreamClientTests` and `LiveValueTests` enforce them.
- The replay start, the replay count and the mark of a replayed event. `EventStreamClientTests` enforces them.
- A replayed display state never applies to the screen. Manual check: examine `TrackInfoModel`.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- A test: after a connect, `BoostPairing.payload(for:)` finds the present block from the `/metadata` snapshot.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- After **Play** on a V4V track, the **Boost** button is active for the first track.
- After **Play** in the first minute of a new V4V track, the **Boost** button is active, and the boost pays that track.
