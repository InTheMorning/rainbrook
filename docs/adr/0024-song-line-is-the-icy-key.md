# ADR 0024: The song line is the ICY key of a display state

- Status: accepted
- Date: 2026-11-22
- Bar: crosses repositories. The relay key `songLine` comes from relay ADR 0005, and the publisher sets it. Without
  this record, an agent can keep the match by artist and title for a chapter state.
- Changes: [ADR 0011](0011-icy-sync-of-the-relay-display.md) §The list and the selection item 2 and §Matching. The key
  of a state with a song line is that song line.
- Changes: [ADR 0013](0013-boosts.md) §The trigger. A chapter change completes a candidate.
- Changed by: [ADR 0030](0030-the-hls-segment-frame-releases-the-display-state.md)
- Operator choice, 2026-11-22: a field in the relay event corrects the chapter display. The orchestrator session
  relayed the choice.
- Operator choice, 2026-11-22: a chapter change ends an item for auto-boost. The orchestrator session relayed the
  choice.
- Class: situational. Supersede this record when the app gets the time of a track change from a different signal.
- Related:
  - [ADR 0013](0013-boosts.md): the trigger and the pairing of a boost.
  - Relay ADR 0005 (`~/build/musicindex-live-relay/docs/adr/0005-display-song-line-and-value.md`): the key
    `songLine` is the line that the station sends as the ICY `StreamTitle`.
  - Publisher ADR 0025: the station producer gives a new display state at each chapter change of an episode file.
  - Publisher ADR 0026: each chapter state has `songLine` equal to the ICY line of the episode file.

## Context

- ADR 0011 selects a display state only when its key `artist - title` is equal to the ICY text, or starts with it.
- Publisher ADR 0025 gives each chapter state of an episode file the artist and the title of the chapter song. The ICY
  text stays the line of the episode file.
- Thus no chapter state matches the ICY text. The app keeps the episode state while it is one of the last 4 states.
  After that, the screen shows the ICY text with no artwork, and the Boost button is off.
- Relay ADR 0005 has the optional key `songLine`: the ICY `StreamTitle` line with no change. For a chapter state, the publisher
  sets it to the line of the episode file.

## Decision

1. `TrackDisplay` reads `songLine` from the display state. A string that is not empty gives the song line. A missing
   key, `null`, an empty string or a value that is not a string gives no song line. This decode does not throw.
2. The key of a state with a song line is the song line, after the normalization of ADR 0011 §Matching.
3. The key of a state with no song line stays `artist - title` (ADR 0011).
4. Each other rule of ADR 0011 applies to the key with no change: the match of equal keys, the prefix rule, the newest state
   first, and the replacement of an older state that has an equal key.
5. Thus the chapter states of one episode file have one key. A newer chapter state replaces the older one, and the
   newest chapter state shows while the ICY text names the episode file.
6. A state with a song line does not match by its artist and title.

## The Boost Pairing

`BoostPairing` pairs a relay track with its payload by `blockGuid` (ADR 0013). Each chapter state has its own block, so
each chapter state pairs with its own payload. This record does not change the pairing.

## The Chapter Change

This adds a rule to ADR 0013 §The trigger. The other rules of ADR 0013 and ADR 0016 do not change.

1. A chapter change occurs when the sync selects a track with a known block and a song line, and these two
   conditions are true:
   - The newest earlier selected track of the present ICY text has the same song line, after the normalization
     of ADR 0011 §Matching.
   - The two blocks are different.
2. A chapter change completes the candidate that runs, if one runs. Its track is the earlier chapter state.
3. A chapter change starts a new candidate for the present ICY text. Its track is the new chapter state. Its play
   time starts at the chapter change.
4. A chapter change starts a candidate also when no candidate runs, for example after the first ICY text of the
   session. The listener hears the new chapter from its start.
5. Thus each chapter song that the listener hears to its end gets its own candidate, with its own block.
6. A track with no song line, or with a song line that the earlier track did not have, causes no chapter change.

The play time of a chapter candidate starts and stops at the time when the sync selected the chapter state. ADR
0016 §The minimum play time applies to it.

## Open Points

1. **The switch back.** `BoostTrigger` keeps the block of the newest selected state for the present ICY text (ADR
   0016). Inference: after a reconnect in an episode, the block can be the block of a different chapter. Then the
   trigger can count a reconnect repeat as a real switch back. A test of the trigger shows no defect when the sync
   selects the newest chapter state again. The risk stays if the sync selects a different state, for example when a
   chapter state of the episode file arrives after the next ICY text.

## Consequences

- With ICY, the player screen, Now Playing and the manual boost show the chapter song that plays.
- A state from a station that sends no `songLine` matches as before.
- An episode file with three chapters that the listener hears from start to end gives three auto-boosts, one for
  each block. Each boost must pass the minimum play time and the daily limit.
- The time of a chapter change is the time when the relay state arrives, not the time of the audio. The play time
  of a chapter candidate can thus be different from the time that the listener heard it.
- When the publisher sets a song line that is not equal to the ICY text, no state matches. The ICY text then shows
  with no artwork.

## Acceptance criteria

### Mechanical

- `TrackDisplayTests` reads a song line, and gives no song line for a missing, empty, `null` and number value.
- `IcySyncTests` selects the newest of three chapter states with one song line, before and after the ICY text.
- `IcySyncTests` shows that a state with a song line does not match by its artist and title.
- `IcySyncTests` shows that a state with no song line matches by its artist and title as before.
- `BoostPairingTests` pairs each of three chapter states with its own block.
- `BoostTriggerTests` gives three candidates for three chapter states with one song line, each with its own
  block. It starts a candidate at a chapter change when no candidate runs. A new block with no equal song line
  causes no chapter change.
- `BoostTriggerTests` drops the candidate at a reconnect repeat back to an episode file.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- On a station that plays an episode file with chapters, the title, the artist and the artwork change at each
  chapter change.
- The Boost button is on during each chapter song that has routes.
- With auto-boost on, the boost history has one entry for each chapter song that played to its end.
