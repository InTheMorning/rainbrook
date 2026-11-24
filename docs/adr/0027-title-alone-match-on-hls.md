# ADR 0027: The match of the ID3 title alone on HLS

- Status: accepted
- Date: 2026-11-24
- Bar: opposite choice by mistake. ADR 0025 sends only the joined text to `IcySync`. Without this record, an agent can
  remove the second match as a duplicate path.
- Changes: [ADR 0025](0025-the-icy-text-of-an-hls-stream.md) §Decision rule 6 and §Consequences item 2.
- Operator choice, 2026-11-24: fix C. When the joined ICY text gives no match, `IcySync` tries the ID3 title alone.
  The orchestrator session relayed the choice.
- Class: situational. Supersede this record with ADR 0025 when the app selects a display state from a different
  signal of an HLS stream.
- Related:
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the exact match and the prefix match.
  - [ADR 0024](0024-song-line-is-the-icy-key.md): the key of a state with a song line is that song line.

## Context

- ADR 0025 makes the ICY text of an HLS tag "`TPE1` - `TIT2`".
- A station can write the full song line in `TIT2` and the show name in `TPE1`. An example is `TPE1` "Behind The
  Sch3m3s" and `TIT2` "Malachi - Working Man". The relay key is "Malachi - Working Man".
- The joined text "Behind The Sch3m3s - Malachi - Working Man" does not match that key. ADR 0025 §Consequences item 2
  accepted this risk until a station shows it. A station now shows it.

## Decision

1. `IcyTitle.icyText(streamTitle:artist:title:)` gives an `IcyText`. Its `text` is the ICY text of ADR 0025. Its
   `titleAlone` is the trimmed title item when `text` joins an artist and a title. Else `titleAlone` is nil.
2. `IcySync.receiveIcyText(_:titleAlone:)` keeps the two values. A new ICY text replaces the two. `resetIcy` clears
   the two.
3. `IcySync` matches the text first, with the rules of ADR 0011 and ADR 0024. When the text gives no match and
   `titleAlone` is not empty, it matches `titleAlone` with the same rules.
4. The joined text wins when both match.
5. `BoostTrigger` and the log get the ICY text of rule 1 with no change.

## Options

- **Match the title alone first.** Rejected. The title "Red" of "12 Rods - Red" can match a different state with the
  title "Red".
- **Use the title alone and no join.** Rejected. ADR 0025 records that the title alone does not match a song line such
  as "12 Rods - Red".

## Consequences

- On HLS, the relay lines stay when the joined text or the title alone is equal to the key.
- When the title alone matches and the joined text does not, the ICY lines of the screen are not used. The relay
  lines show.

## Invariants

These rules apply while this decision is current.

- Rules 1 to 4. `IcyTitleAloneTests` enforces them.
- The reader gives the `IcyText` to the player, and `TrackInfoModel` gives `titleAlone` to `IcySync`. Manual check:
  examine `IcyMetadataReader` and `TrackInfoModel.icyTextChanged`. A test cannot examine AVFoundation types on Linux.
