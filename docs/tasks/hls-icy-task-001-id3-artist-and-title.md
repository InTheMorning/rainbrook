# HLS ICY task 001: ID3 artist and title

- Decision: [ADR 0025](../adr/0025-the-icy-text-of-an-hls-stream.md). It changes [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md) §The ICY text.
- Operator choice (2026-11-24, relayed by the orchestrator session): fix B1. The app joins the ID3 artist and title to make the ICY text.
- Operator choice (2026-11-24, made by this session as the orchestrator asked): a title with no artist gives the title alone, as before. ADR 0025 §Options tells why.

## Goal

On an HLS stream, the ICY text is "artist - title" from the ID3 tag. It is then equal to the song line of the display state, and the relay lines stay after the first tag.

## Files to inspect

- `CitizenRadio/IcyMetadataReader.swift`, `CitizenRadio/Core/IcyTitle.swift`, `CitizenRadio/Core/IcySync.swift`
- `Tests/CitizenRadioCoreTests/IcyTitleTests.swift`
- `docs/adr/0011-icy-sync-of-the-relay-display.md`, `docs/adr/0024-song-line-is-the-icy-key.md`

## Files to change

- `CitizenRadio/Core/IcyTitle.swift`: add `IcyTitle.text(streamTitle:artist:title:)`.
- `Tests/CitizenRadioCoreTests/IcyTitleTests.swift`: tests of the rule.
- `CitizenRadio/IcyMetadataReader.swift`: give the `StreamTitle`, artist and title items to `IcyTitle.text`.
- `docs/adr/0025-the-icy-text-of-an-hls-stream.md` (new), `docs/adr/0011-icy-sync-of-the-relay-display.md`, `docs/adr/README.md`, `AGENTS.md`.

## Do not touch

- The match rules of `IcySync`, the `BoostTrigger` rules and the value client.
- The `musicindex` TXXX frame. ADR 0025 §Options tells why.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| ICY title rules | extend | CitizenRadio/Core/IcyTitle.swift | `IcyTitle` holds the rules for the ICY text. The join rule goes into the same type. |
| ICY metadata reader | extend | CitizenRadio/IcyMetadataReader.swift | The reader reads two more items and calls the core rule. |
| ICY sync | reuse | CitizenRadio/Core/IcySync.swift | The joined text goes to `receiveIcyText` with no change. |

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- `IcyTitleTests` examines `IcyTitle.text` for these conditions:
  - A `StreamTitle` wins over the ID3 items. An empty `StreamTitle` is an empty ICY text.
  - The artist and the title join with `" - "`. The items are trimmed.
  - A title without an artist gives the title alone. A group without a title gives no text.
- `IcyTitleTests` examines that the joined text of a chapter capture is equal to its song line.
- `IcyTitleTests` examines that `IcySync` selects the state for a joined text.
- `IcyMetadataReader` gives the items of ADR 0025 rule 4 to `IcyTitle.text`. Method: read the diff. A test cannot examine AVFoundation types on Linux.

Visual (open until the operator does the check):

- On the HLS stream, the relay lines with the album stay after the first ID3 tag.
- On the HLS stream, the **Boost** button becomes active on a V4V track.
- The Playback log shows "ICY:" lines with the format "artist - title".
