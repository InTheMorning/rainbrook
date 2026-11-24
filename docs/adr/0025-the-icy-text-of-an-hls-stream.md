# ADR 0025: The ICY text of an HLS stream

- Status: accepted
- Date: 2026-11-24
- Bar: opposite choice by mistake. ADR 0011 stated that a group with no `StreamTitle` gives no ICY text. Without this
  record, an agent can remove the ID3 path, or use the title alone again.
- Changes: [ADR 0011](0011-icy-sync-of-the-relay-display.md) §The ICY text items 1 and 2, and §Invariants item 2.
  A group with no `StreamTitle` item can give an ICY text from its ID3 artist and title items.
- Changed by: [ADR 0027](0027-title-alone-match-on-hls.md)
- Operator choice, 2026-11-24: fix B1. The app joins the ID3 artist and title of an HLS stream to make the ICY text.
  The orchestrator session relayed the choice.
- Class: situational. Supersede this record when the app selects a display state from a different signal of an HLS
  stream, such as the `musicindex` TXXX frame.
- Related:
  - [ADR 0017](0017-stations-with-alternate-stream.md): the HLS stream is the primary stream of a station.
  - [ADR 0024](0024-song-line-is-the-icy-key.md): the key of a state with a song line is that song line.
  - Research capture `~/build/musicindex-research/sources/captures/2026-11-21-azuracast-hls-id3/`: the ID3 frames of
    the HLS stream of `heycitizens_test_radio`.

## Context

- The HLS stream of a station has no ICY `StreamTitle`. Each segment has an ID3 tag with `TIT2` (the title), `TPE1`
  (the artist), `TALB` (the album) and a `TXXX` frame.
- `IcyMetadataReader` used the item with the common key title when a group had no `StreamTitle` item. For the HLS
  stream that is `TIT2` alone, for example "Red".
- The key of the display state is the song line, for example "12 Rods - Red" (ADR 0024). The title alone does not
  match it, because the prefix rule of ADR 0011 needs a `" - "` in the ICY text.
- Thus after the first ID3 tag the screen showed the ICY lines with no album, and the Boost button had no target.
- The orchestrator examined the relay and the HLS tag on 2026-11-24 at 02:00 UTC during a chapter. The song line was
  "DuhLaurien and MaryKate-Ultra - Homegrown Hits - Episode 157". `TPE1` was "DuhLaurien and MaryKate-Ultra", and
  `TIT2` was "Homegrown Hits - Episode 157". The join of the two is equal to the song line.
- At that time the `musicindex` TXXX frame had the value `null` during a chapter. So the app cannot use that frame as
  the key at this time.

## Decision

`IcyTitle.text(streamTitle:artist:title:)` in `CitizenRadioCore` holds the rule. `IcyMetadataReader` gives it the
items of one metadata group.

1. A group with a `StreamTitle` item gives its value as the ICY text. An empty value is an empty ICY text. The ID3
   items of the group have no effect.
2. A group with no `StreamTitle` item and a title item that is not empty gives an ICY text:
   - `"\(artist) - \(title)"` when the artist item is not empty.
   - The title alone when there is no artist item, or when the artist item is empty.
3. Each other group gives no ICY text. It changes nothing. Examples are a group with an artist and no title, and a
   group with an empty title.
4. The reader takes the artist from the ID3 `TPE1` item, else from the item with the common key artist. It takes the
   title from the ID3 `TIT2` item, else from the item with the common key title.
5. The join trims the white space at the two ends of each item. An item with only white space is empty.
6. The ICY text of rules 1 and 2 goes to `IcySync` and `BoostTrigger` as each other ICY text does. ADR 0011 and
   ADR 0024 apply with no change.

## Options

- **The title alone gives no ICY text.** Then an HLS session with only `TIT2` has no ICY, and the timed apply of
  ADR 0008 shows the relay lines. But a station that writes the full song line in `TIT2` loses the ICY sync and the
  boost. The title alone keeps that station in the sync, as before this record.
- **Use the `musicindex` TXXX frame as the key.** This is the correct long-term signal. It is not usable at this time, because
  its value is `null` during a chapter.
- **Remove the ID3 path.** This agrees with ADR 0011 as written. But then an HLS session has no ICY text, and
  `BoostTrigger` gets no input. No boost occurs on HLS.

## Consequences

- On HLS, the relay lines stay after the first ID3 tag, when the join is equal to the song line.
- A tag with the full song line in `TIT2` and also an artist in `TPE1` gives a text that does not match. The screen
  then shows the ICY lines. This record accepts that risk until a station shows it.
- Each HLS segment repeats the same tag, so the same ICY text arrives again each 4 seconds. `IcySync` and
  `BoostTrigger` see no change for an equal text.

## Invariants

These rules apply while this decision is current.

- The rules 1, 2, 3 and 5 of the Decision section. `IcyTitleTests` enforces them.
- The reader gives the items of rule 4 to `IcyTitle.text`. Manual check: examine `IcyMetadataReader`. A test cannot
  examine AVFoundation types on Linux.
