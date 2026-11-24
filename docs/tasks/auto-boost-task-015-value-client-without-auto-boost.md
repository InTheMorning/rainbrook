# Auto-boost task 015: Value client without Auto-boost

- Decision: [ADR 0013](../adr/0013-boosts.md) (the manual boost is in addition to auto-boost) and [ADR 0018](../adr/0018-instant-snapshots-and-replay-on-connect.md) (the value client gives the payload of the manual **Boost** button).
- Operator choice (2026-11-23, relayed by the orchestrator session): the live value client runs when the display client runs. The Auto-boost setting does not control it. This is a defect correction. It needs no new ADR.

## Goal

With Auto-boost off, the value client runs. Its payloads go to `BoostPairing`, so the manual **Boost** button can have a target.

## Defect

`TrackInfoModel.updateValueClient` started the value client only when `BoostSettings().isEnabled` was true. The default is false. So with Auto-boost off, no payload went to `BoostPairing`, and `manualTarget` stayed nil. No ADR has this condition.

## Files to inspect

- `CitizenRadio/TrackInfoModel.swift` (`updateValueClient`, `reloadSettings`, the `valueClient` property)
- `CitizenRadio/BoostModel.swift` (`payload`, `updateManualTarget`)

## Files to change

- `CitizenRadio/TrackInfoModel.swift`: remove `BoostSettings().isEnabled` from the run condition. Correct the comments of `valueClient`, `reloadSettings` and `updateValueClient`.

## Do not touch

- The HLS text of the ICY sync. The operator selects that fix separately.
- `BoostTrigger`, `BoostPairing` and the Auto-boost payment rules.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| Live value client | reuse | CitizenRadio/Core/EventStreamClient.swift | The change removes one condition. The client does not change. |
| Value client control | extend | CitizenRadio/TrackInfoModel.swift | `updateValueClient` gets a smaller run condition. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- The run condition in `TrackInfoModel.updateValueClient` is `client != nil && !relayStopped`. Method: read the diff. `TrackInfoModel` is in the app target, so no Linux test can examine it.

Visual (open until the operator does the check):

- With Auto-boost off, on a V4V track with a matched relay track, the **Boost** button becomes active.
- The Playback log shows "Value client: live" with Auto-boost off.
