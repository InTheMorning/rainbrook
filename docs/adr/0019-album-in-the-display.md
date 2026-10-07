# ADR 0019: The album in the display

- Status: accepted
- Date: 2026-10-06
- Class: situational. Supersede this record when the display state gets its album from a different source, or when the player screen changes its track lines.
- Related:
  - [ADR 0008](0008-relay-display-metadata.md) §Display data: this record adds one optional key to the display track.
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): the album is not part of the ICY key.
  - [ADR 0014](0014-player-screen-with-boost-button.md): the player screen.
  - [Upstream live metadata plan](../plans/upstream-live-metadata-plan.md)
- Task: [album task 001](../tasks/album-task-001-display-album.md)

## Context

On 2026-10-06 the operator asked to show the album of each track.

Upstream facts on 2026-10-06:

- `musicindex-live-relay` ADR 0006 is Implemented and deployed. A display track can have the optional key `album`: a string of 1 to 1,024 characters. A track with no album has no `album` key.
- `musicindex-live-publisher` ADR 0013 is Accepted. The producer reads the album from the Mixxx history row. The publisher is the only sender of the key.
- The album is also in the live value payload (`line[0]`), but only for a V4V track.

## Decision

- `TrackDisplay` decodes the optional `album`. A non-empty string gives the album. A missing key, an empty string or a value that is not a string gives no album. It never makes the state invalid.
- `TrackLines` has an optional `album`. It comes from the relay track only. A track from the ICY title has no album.
- The player screen shows the album below the artist, in a smaller secondary style, on one line.
- Now Playing gets the album as its album title, when there is one.
- The ICY key stays `artist - title` (ADR 0011). The album is not part of it.
- The app does not read the album from the live value payload.

## Alternatives considered

- **The album from the live value payload.** It exists only for a V4V track, and it needs the second stream.
- **The album in the ICY key.** The ICY title has no album.

## Consequences

- A track shows its album when the publisher sends it, also a track that pays nobody.
- A track with no album shows as before.
- The player screen gets one more line of text.

## Invariants

These rules apply while this decision is current.

- The album decode rules. `TrackDisplayTests` enforces them.
- The album comes only from the relay track. `TrackLinesTests` enforces it.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- A track with an album shows the album below the artist.
- The lock screen shows the album.
- A track with no album shows no empty line.
