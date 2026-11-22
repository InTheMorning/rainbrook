# ADR 0024: The song line is the ICY key of a display state

- Status: accepted
- Date: 2026-11-22
- Bar: crosses repositories. The relay key `songLine` comes from relay ADR 0005, and the publisher sets it. Without
  this record, an agent can keep the match by artist and title for a chapter state.
- Changes: [ADR 0011](0011-icy-sync-of-the-relay-display.md) §The list and the selection item 2 and §Matching. The key
  of a state with a song line is that song line.
- Operator choice, 2026-11-22: a field in the relay event corrects the chapter display. The orchestrator session
  relayed the choice.
- Class: situational. Supersede this record when the app gets the time of a track change from a different signal.
- Related:
  - [ADR 0013](0013-boosts.md): the trigger and the pairing of a boost.
  - Relay ADR 0005 (`~/build/musicindex-live-relay/docs/adr/0005-display-song-line-and-value.md`): the key
    `songLine` is the line that the station sends as the ICY `StreamTitle`.
  - Publisher ADR 0025: the station producer gives a new display state at each chapter change of an episode file.

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

## Open Points

1. **The auto-boost of an episode file.** `BoostTrigger` makes one candidate for each ICY text (ADR 0013). For an
   episode file, the candidate is the full episode, and its track is the newest chapter state that the sync
   selected. At the end of the episode, the app pays only the block of that state. The operator
   decides if a chapter change completes a candidate. Until then, the trigger does not change.

2. **The switch back.** `BoostTrigger` keeps the block of the newest selected state for the present ICY text (ADR
   0016). Inference: after a reconnect in an episode, the block can be the block of a different chapter. Then the
   trigger can count a reconnect repeat as a real switch back. No test examines this condition.

## Consequences

- With ICY, the player screen, Now Playing and the manual boost show the chapter song that plays.
- A state from a station that sends no `songLine` matches as before.
- When the publisher sets a song line that is not equal to the ICY text, no state matches. The ICY text then shows
  with no artwork.

## Acceptance criteria

### Mechanical

- `TrackDisplayTests` reads a song line, and gives no song line for a missing, empty, `null` and number value.
- `IcySyncTests` selects the newest of three chapter states with one song line, before and after the ICY text.
- `IcySyncTests` shows that a state with a song line does not match by its artist and title.
- `IcySyncTests` shows that a state with no song line matches by its artist and title as before.
- `BoostPairingTests` pairs each of three chapter states with its own block.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- On a station that plays an episode file with chapters, the title, the artist and the artwork change at each
  chapter change.
- The Boost button is on during each chapter song that has routes.
