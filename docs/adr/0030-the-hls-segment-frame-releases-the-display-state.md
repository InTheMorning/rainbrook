# ADR 0030: The HLS segment frame releases the display state

- Status: accepted
- Date: 2026-11-26
- Bar: crosses repositories. Publisher ADR 0038 writes the frame and asks this app for the rule. Without this record,
  an agent can keep the replacement by key of ADR 0024, and the frame then names no held state.
- Changes: [ADR 0011](0011-icy-sync-of-the-relay-display.md) §The list and the selection items 1 and 3. The list
  holds 8 states, and a group with a segment frame selects by the play ID.
- Changes: [ADR 0024](0024-song-line-is-the-icy-key.md) §Decision rule 5. Chapter states with different play IDs do
  not replace each other.
- Changes: [ADR 0018](0018-instant-snapshots-and-replay-on-connect.md) §The replay on connect. The replay count of
  the display client is 8, the new size of the list.
- Changes: [ADR 0028](0028-station-title-and-image-from-the-dead-block.md) §Decision rule 6. The value end compares
  a state with the newest state of its key only. The list can now hold more than one state of a key.
- Operator choice, 2026-11-26: the operator accepted publisher ADR 0038, which asks this app for the rule of
  §The selection. The publisher session relayed the acceptance.
- Class: situational. Supersede this record when the station gives the time of a segment change by a different
  signal.
- Related:
  - Publisher ADR 0038 (`~/build/musicindex-live-publisher/docs/adr/0038-the-hls-stream-marks-each-segment.md`):
    the frame `musicindex.hls/2` and `playId` on the display state.
  - Publisher station log (`~/build/musicindex-live-publisher/docs/runbooks/test-station-log.md`), step 51: the
    station test of the frame.
  - [ADR 0025](0025-the-icy-text-of-an-hls-stream.md) and [ADR 0027](0027-title-alone-match-on-hls.md): the ICY text
    of an HLS group. They stay for a group with no frame and for a frame with no play ID.

## Context

- On HLS, the app showed a chapter change too early (publisher station log, step 50). A chapter change does not
  change the ICY text, and each chapter state of one episode has the song line of the file. Thus each chapter state
  matched at once when it arrived from the relay. The relay sends a state when the server plays it, and the HLS audio
  comes later.
- Publisher ADR 0038 adds a `TXXX` frame with the description `musicindex` to the HLS stream. Its value is
  `{"schema":"musicindex.hls/2","playId":"ls-<ms>-<seq>-<segment start ms>"}`. The station writes it at each track
  start and at each chapter boundary. The publisher adds the same `playId` to each display state.
- The station test of 2026-11-26 (step 51) gave these results:
  - `playId` was equal to the `play_id` of `display.json` at each of the 5 boundaries.
  - Each HLS segment after a boundary repeats the frame until the next boundary. A new segment starts at each frame.
  - The short segment at a track start (20 ms in the test) has the track tags and no frame. The next segment has the
    frame.
  - The ICY text does not change at a frame.
- ADR 0024 rule 5 lets a newer state replace an older state with an equal key. All chapter states of one episode
  have one key. Thus the next chapter state replaced the held state before its frame came.
- The relay sends a state at the server time. The HLS audio is more than 3 seconds behind the server, and the
  **HLS buffer** setting adds a maximum of 90 seconds (ADR 0020). More than 4 states can arrive in that time.

## Decision

`IcySync` in `RainbrookCore` holds the rules. `SegmentFrame.parse` holds the frame rule.

### The frame

1. `IcyMetadataReader` reads each ID3 `TXXX` item of a metadata group. The first item whose value parses as a
   segment frame gives the segment frame of the group. The reader gives it to `IcySync` with the ICY text of the
   same group. The reader reads each group alone, and gives the texts in the sequence of the groups.
2. A value is a segment frame when it is a JSON object with `schema` equal to `musicindex.hls/2`. The `schema`
   value identifies the frame. The reader does not examine the `TXXX` description.
3. A string `playId` that is not empty gives the play ID. A missing `playId`, `null` and an empty string give a frame
   with no play ID. A `playId` of a different type gives no frame.
4. A group that gives no ICY text (ADR 0025 rule 3) changes nothing, also when it has a frame.

### The display state

5. `TrackDisplay` reads `playId` from the display state. A string that is not empty gives the play ID. A missing
   key, `null`, an empty string and a value that is not a string give no play ID. This decode does not throw.

### The list

6. The list holds a maximum of 8 states, newest first. The display client replays 8 states on connect (ADR 0018).
7. The identity of a state is its play ID, or its key (ADR 0024) when it has no play ID. A newer state replaces an
   older state with an equal identity. Thus chapter states with different play IDs stay in the list. A state that
   the publisher sends again with its `value` replaces the first one.
8. The value end of ADR 0028 compares a state with no value block with the newest state of its key only.

### The selection

9. A group with a segment frame that has a play ID selects by these rules, in this sequence:
   1. The held state with the same play ID is the relay track. This also applies when that state arrives after its
      frame: the state shows when it arrives.
   2. Else, the present relay track stays if it has a play ID and the ICY text matches it (ADR 0011 and ADR 0027).
      The newest state in the list with its play ID replaces it, if the list has one.
   3. Else, the ICY rule of ADR 0011 and ADR 0027 selects from the states with no play ID. A state with a play ID
      waits for its frame.
10. A frame with no play ID keeps the ICY rule of ADR 0011 and ADR 0027.
11. A group with no segment frame keeps the ICY rule until the first frame with a play ID in the ICY session. After
    that frame, a group with no segment frame selects by rules 9.2 and 9.3.
12. `clearStates()` clears the relay track. `resetIcy()` starts a new ICY session with no frame.

## Options

- **The ICY rule for each group with no frame.** This is the request of publisher ADR 0038. But in the short segment
  at a track start, it can select a later chapter state that is already in the list. The frame of the next segment
  then gives a false chapter change. With a minimum play time of 0 (ADR 0016), auto-boost pays that chapter before
  the listener hears it. Rule 11 prevents this.
- **Keep the last frame for a group with no frame.** Then the app releases no state at a new track until its frame
  arrives. Rule 11 gives the same result, because rule 9.3 selects only states with no play ID.
- **Rule 9.3 selects from all states.** Then an early chapter state shows when the frame of its predecessor names no
  held state. That is the fault that this record corrects.
- **Rule 9.2 is not in the rules.** Then a late state of the next chapter clears the relay track until the state
  arrives. For that time, the screen shows the ICY lines with no artwork.

## Consequences

- On HLS, a chapter state shows when the listener hears the chapter. The boost candidate of ADR 0024 §The chapter
  change starts at the same time, because it follows the selection.
- A station that writes no frame, and an Icecast stream, keep the behavior of ADR 0011 and ADR 0024. On Icecast,
  states with play IDs no longer replace each other. But the newest matching state is the same state as before.
- In the short segment at a track start, the screen shows the ICY lines with no artwork for about 20 milliseconds. The frame
  of the next segment then releases the state.
- If the publisher sends states with no `playId` while the station writes frames, rule 9.3 gives the ICY rule.
- If the station stops the frames during an ICY session, the states with a play ID do not show until Stop. The next
  session uses the ICY rule until the first frame.

## Invariants

These rules apply while this decision is current.

- The rules 2, 3, 5 to 12 of the Decision section. `IcySyncSegmentFrameTests`, `SegmentFrameTests`,
  `TrackDisplayTests` and `IcySyncTests` enforce them.
- The reader gives the frame of rule 1 to `IcySync` with the ICY text of the same group, in the sequence of the
  groups. Manual check: examine `IcyMetadataReader` and `TrackInfoModel.icyTextChanged`. A test cannot examine AVFoundation types on Linux.

## Acceptance criteria

### Mechanical

- The tests of §Invariants pass.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone, on HLS, after the station writes the frames again. Report each item
as open until a person completes that check.

- The picture and the lines of a chapter change when the listener hears the chapter song.
- A boost in the first seconds of a chapter song pays the block of that song.
- The playback log shows the segment play ID after each ICY text of the HLS stream.
