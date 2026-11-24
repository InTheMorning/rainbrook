# Stations task 003: The event of the station at the start of playback

- Decision: [ADR 0013](../adr/0013-boosts.md) §The trigger (a change of the live value address ends the session) and
  [ADR 0018](../adr/0018-instant-snapshots-and-replay-on-connect.md) (the display client).
- Operator choice (2026-11-24, relayed by the orchestrator session): the start of playback reads the event of the
  selected station. The close of the settings sheet does not stop and start the clients again for the same event.
  This is a defect correction. It needs no new ADR.

## Defect

A tap on a station starts playback 0.55 s before the settings sheet closes. `playbackChanged` started the display
client with the event of the station before. Then `reloadSettings` found a different event, stopped the client,
cleared the display states and started a new client. When the new station had no valid **Live value address**, the
first client ran for that time with the event of the station before.

## Files to change

- `CitizenRadio/Core/RelayEventChange.swift` (new): the rule for each event change.
- `CitizenRadio/TrackInfoModel.swift`: `playbackChanged` and `reloadSettings` use `applyEvent`.
- `CitizenRadio/SettingsView.swift`: the comment of `play(_:)`.
- `Tests/CitizenRadioCoreTests/RelayEventChangeTests.swift` (new).

## Do not touch

- `startRelay` and `stopRelay`.
- The station store and the settings sheet flow.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| Station store | reuse | CitizenRadio/Core/StationStore.swift | It gives the selected station and its event. |
| Relay event | reuse | CitizenRadio/Core/RelayEvent.swift | The event value. Two equal events are the same address. |
| Event change rule | new | CitizenRadio/Core/RelayEventChange.swift | Searched CitizenRadio/Core, CitizenRadio/TrackInfoModel.swift and ~/build/musicindex-lib. Only TrackInfoModel had the rule for an event change, and a test cannot examine TrackInfoModel on Linux. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- `RelayEventChangeTests`: a change from an event to nil clears the relay track and starts no client.
- `RelayEventChangeTests`: the same event with a client starts no second client and clears nothing.
- `RelayEventChangeTests`: a different event, or an event after nil, clears the relay and starts a client while
  playback is active. No client starts while playback is not active.
- `TrackInfoModel.playbackChanged` and `TrackInfoModel.reloadSettings` apply `RelayEventChange.decide`. Method: read
  the diff. A test cannot examine `TrackInfoModel` on Linux.

Visual (open until the operator does the check):

- A tap on a station with no **Live value address** shows no relay lines of the station before.
- A tap on a station with a **Live value address** gives one display client in the log, not two.
