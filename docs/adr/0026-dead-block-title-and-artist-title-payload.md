# ADR 0026: The dead block title and the "artist - title" payload

- Status: accepted
- Date: 2026-11-24
- Bar: crosses repositories. Publisher ADR 0029 changes two inputs of the boost rules of this app: the title of the
  dead block and the title of a payable block.
- Changes: [ADR 0013](0013-boosts.md) §Context item "Between V4V tracks", §Payable destinations items 3 and 4, and
  §The pairing item 3.
- Source: `musicindex-live-publisher` ADR 0029 (commit `f8c5792`). It supersedes publisher ADR 0005.
- Class: situational. Supersede this record when the publisher changes the dead block or the payload title again.
- Related:
  - [ADR 0024](0024-song-line-is-the-icy-key.md): the key of a state with a song line is that song line.

## Context

- Publisher ADR 0029 makes the title of the dead block a setting of each station, for example "HeyCitizen Test
  Stream". When the station sets no title, the title is "No V4V track playing". The dead block is the block that pays
  nobody. Its destination stays `no-v4v-track@example.invalid` with split 100, and no setting changes it.
- Publisher ADR 0029 makes the `title` of a payable block "artist - title", for example "Anni Powell - Beyond the
  Hills". The title alone when the artist is empty. The display state does not change.
- ADR 0013 compared the payload title with the title of the relay track when the relay track has no
  `value.blockGuid`. That test gives no result for "artist - title".

## Decision

### The dead block

1. The reserved host rule of ADR 0013 §Payable destinations is the rule that excludes the dead block. It applies for
   each title, also for a title that the station sets.
2. The app also does not pay a payload with the default title "No V4V track playing". This rule is not sufficient
   alone, because the title can change.

### The title pairing

When the relay track has no `value.blockGuid`, `BoostPairing` selects the payable payload in this sequence:

1. The newest payable payload with a normalized `title` that is equal to the key of the relay track. The key is the song
   line, or else "artist - title" (ADR 0011 §Matching, ADR 0024).
2. Else the newest payable payload with a normalized `title` that is equal to the normalized title of the relay track.
   This keeps a publisher that sends the title alone.

The `blockGuid` pairing of ADR 0013 does not change. Each path that pays (the **Boost** sheet and Auto-boost) gets its
payload from `BoostPairing`, so these rules apply to each path.

## Options

- **Compare only "artist - title".** Rejected. A relay track with a song line that is not "artist - title" then has no
  title pairing, and a publisher before ADR 0029 has no pairing.
- **Read the dead block title from the station settings.** Rejected. The app does not know the publisher setting, and
  the reserved host rule is sufficient.

## Consequences

- The **Boost** button stays grey during a dead block with a station title.
- The "episode" text of a boost record (`BoostRecord`) is the payload title. For a payable block it is now
  "artist - title".
- A chapter state has the song line of the file, and the payload names the chapter song. Such a state pairs by
  `blockGuid`, or by rule 2 when the payload title is the title alone.

## Invariants

These rules apply while this decision is current.

- The dead block with a station title is not payable and never pairs. `LiveValueTests` and `BoostPairingTests`
  enforce it.
- The title pairing sequence. `BoostPairingTests` enforces it.
