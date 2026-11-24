# Boost pairing task 002: The boost target before the first ICY text

- Decision: [ADR 0013](../adr/0013-boosts.md) (the manual boost and the trigger) and
  [ADR 0026](../adr/0026-dead-block-title-and-artist-title-payload.md) (the dead block).
- Operator choice (2026-11-24, relayed by the orchestrator session): before the first ICY text, the boost model gets
  the relay track that the screen shows. This is a defect correction. It needs no new ADR.

## Defect

`TrackInfoModel.updateLines` gave `sync.relayTrack` to `BoostModel.selectedTrack`. Before the first ICY text that
value is nil, but the screen shows the relay track of the timed apply. So the **Boost** button stayed gray on a
stream with no ICY text.

## Files to change

- `CitizenRadio/Core/IcySync.swift`: add `track(withoutIcy:)`.
- `CitizenRadio/TrackInfoModel.swift`: give that track to the boost model and to the log.
- `Tests/CitizenRadioCoreTests/BoostBeforeIcyTests.swift` (new).

## Do not touch

- The `BoostTrigger` rules. Before the first ICY text the trigger has no candidate, so a selected track completes
  nothing.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| ICY sync | extend | CitizenRadio/Core/IcySync.swift | The sync knows if an ICY text arrived. It gives the track for each condition. |
| Boost pairing | reuse | CitizenRadio/Core/BoostPairing.swift | The pairing decides if the track has a payable payload. |
| Boost trigger | reuse | CitizenRadio/Core/BoostTrigger.swift | No change. A test examines the condition with no ICY text. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- `BoostBeforeIcyTests`: with no ICY text and a payable relay track, `IcySync.track(withoutIcy:)` gives that track,
  and `BoostPairing` gives its payload.
- `BoostBeforeIcyTests`: with no ICY text and a dead block track, `BoostPairing` gives no payload.
- `BoostBeforeIcyTests`: relay tracks before the first ICY text, and the first ICY text, complete no candidate.
- `TrackInfoModel.updateLines` gives `IcySync.track(withoutIcy:)` to `BoostModel.selectedTrack`. Method: read the
  diff. A test cannot get to `TrackInfoModel` on Linux.

Visual (open until the operator does the check):

- On a stream with no ICY text, the **Boost** button becomes active on a V4V track.
- During a jingle, the **Boost** button stays gray.
