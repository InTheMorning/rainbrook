# Display task 001: The station identity and the artwork load

- Decision: [ADR 0028](../adr/0028-station-title-and-image-from-the-dead-block.md).
- Operator choice (2026-11-24, relayed by the orchestrator session): during a jingle the app shows the dead block
  title and image.

## Defects

- The app did not decode `image` of a live value payload. So it did not show the station title or the station image
  during a jingle.
- A missing artwork stayed missing until the artwork changed. The log did not show the cause.
- Phone check 1 of `1941a90` failed. During a jingle with no title, the ICY text stays at the song that ended, and the
  relay sends that song with no value block. The app showed that song, and **Boost** stayed active.
- Operator choice (2026-11-24, relayed by the orchestrator session): the dead block has `value.destinations: []`.

## Files to change

- `CitizenRadio/Core/LiveValue.swift`: decode `image`, and add `isDeadBlock`. An empty destination array is a dead
  block.
- `CitizenRadio/Core/IcySync.swift`: add `valueEnded(_:)`.
- `CitizenRadio/BoostModel.swift`: no manual target while the value block ended.
- `CitizenRadio/Core/StationIdentity.swift` (new): `StationIdentity` and `TrackLines.withStation(_:)`.
- `CitizenRadio/TrackInfoModel.swift`: keep the station identity, load the station image, and show the track image or
  else the station image.
- `CitizenRadio/ArtworkLoader.swift`: decode off the actor, the still frame fallback, and the log lines.
- `Tests/CitizenRadioCoreTests/StationIdentityTests.swift` (new).

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| Live value payload | extend | CitizenRadio/Core/LiveValue.swift | The payload decode reads each field of the relay value event. |
| ICY sync | extend | CitizenRadio/Core/IcySync.swift | The sync keeps the display states, so it knows when the value block of a key ended. |
| Boost model | extend | CitizenRadio/BoostModel.swift | The model owns the manual target. |
| Track lines | extend | CitizenRadio/Core/TrackLines.swift | The default lines get the station title through an extension. |
| Station identity | new | CitizenRadio/Core/StationIdentity.swift | Searched CitizenRadio/Core, CitizenRadio and ~/build/musicindex-lib. No type keeps the station title and image of the dead block. |
| Artwork loader | extend | CitizenRadio/ArtworkLoader.swift | The loader is the only image load path. The station image uses it. |
| Artwork retry | reuse | CitizenRadio/Core/ArtworkRetry.swift | No change to the intervals. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes. It includes the iOS build.
- `StationIdentityTests`: a dead block gives the station title and image, and the default title gives no title.
- `StationIdentityTests`: a payable block and a block with no reserved host give no identity.
- `StationIdentityTests`: only an `http` or `https` image is kept.
- `StationIdentityTests`: the default lines take the station title, and relay and ICY lines do not change.
- `StationIdentityTests`: the jingle sequence of 2026-11-24 05:22 gives the station title.
- `StationIdentityTests`: a dead block with `value.destinations: []` gives the station and no payload pairs with it.
- `StationIdentityTests`: the jingle sequence of 2026-11-24 12:27 gives the station lines, and the next song gives
  its own lines.
- `StationIdentityTests`: the input order "song payload, dead block payload, no display state" gives no manual payload.
  The next song payload gives the manual payload again. A different ICY text clears the ended value blocks.
- `JingleReplayTests`: the relay input and the ICY text of 2026-11-25 16:29 to 16:34 give the station lines and no
  manual payload during the jingle, in the two orders of the dead block payload and the display state. The next song
  gives its own lines and its manual payload. The test runs with the dead block of an empty destination array and with
  the dead block of 18:36 UTC, which has one destination at `no-v4v-track@example.invalid` (publisher ADR 0033).
- The playback log records "Station:" at each change of the station identity, and each "Relay track:" line ends with
  "value", "no value" or "value ended". Method: read the diff.
- `BoostModel.updateManualTarget` uses `BoostPairing.manualPayload(for:valueEnded:)`. Method: read the diff.
- `TrackInfoModel` shows the track image, or else the station image. Method: read the diff. A test on Linux cannot
  examine `TrackInfoModel`.
- `ArtworkLoader` decodes off its actor, gives the first frame when the animated decode fails, and records the size
  and the times. Method: read the diff.

Visual (open until the operator does the check):

- During a jingle with an empty ICY text, the screen shows "HeyCitizen Test Stream" and the station image.
- During the "AzuraCast is Live!" jingle, the screen shows that title and the station image.
- During a jingle with no title, the screen shows "HeyCitizen Test Stream" and the station image, and **Boost** is
  gray.
- When a song artwork is missing, the playback log shows an "Artwork download:" line with the size and the times.
