# HLS ICY task 002: The match of the ID3 title alone

- Decision: [ADR 0027](../adr/0027-title-alone-match-on-hls.md). It changes
  [ADR 0025](../adr/0025-the-icy-text-of-an-hls-stream.md).
- Operator choice (2026-11-24, relayed by the orchestrator session): when the joined ICY text gives no match,
  `IcySync` tries the `TIT2` text alone.

## Goal

On HLS, a tag with the show name in `TPE1` and the song line in `TIT2` selects the display state of that song line.

## Files to change

- `CitizenRadio/Core/IcyTitle.swift`: add `IcyText` and `IcyTitle.icyText(streamTitle:artist:title:)`.
- `CitizenRadio/Core/IcySync.swift`: keep the title alone and match it when the text gives no match.
- `CitizenRadio/IcyMetadataReader.swift`, `CitizenRadio/RadioPlayer.swift`, `CitizenRadio/TrackInfoModel.swift`: carry
  the `IcyText` from the reader to the sync.
- `Tests/CitizenRadioCoreTests/IcyTitleAloneTests.swift` (new).
- `docs/adr/0027-title-alone-match-on-hls.md` (new), `docs/adr/0025-the-icy-text-of-an-hls-stream.md`,
  `docs/adr/README.md`, `AGENTS.md`.

## Do not touch

- `IcyTitle.text(streamTitle:artist:title:)` and its rules (ADR 0025).
- `BoostTrigger`. It gets the joined text as before.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| ICY title rules | extend | CitizenRadio/Core/IcyTitle.swift | The text rule stays. The new function adds the title alone. |
| ICY sync | extend | CitizenRadio/Core/IcySync.swift | The second match uses the match rules of the sync. |
| ICY reader | extend | CitizenRadio/IcyMetadataReader.swift | The reader gives an `IcyText` in place of a string. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- `IcyTitleAloneTests`: `TPE1` "Behind The Sch3m3s" and `TIT2` "Malachi - Working Man" select the state with the key
  "Malachi - Working Man".
- `IcyTitleAloneTests`: the joined match wins when both match.
- `IcyTitleAloneTests`: no match when neither matches.
- `IcyTitleAloneTests`: a `StreamTitle` and a title with no artist give no title alone. A new ICY text and `resetIcy`
  drop the old title alone.
- `TrackInfoModel.icyTextChanged` gives `titleAlone` to `IcySync`. Method: read the diff. A test cannot examine
  `TrackInfoModel` on Linux.

Visual (open until the operator does the check):

- On HLS, during "Behind The Sch3m3s" with the song "Malachi - Working Man", the screen shows the relay lines, and the
  **Boost** button is active when that track is payable.
