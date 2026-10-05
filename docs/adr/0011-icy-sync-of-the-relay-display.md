# ADR 0011: ICY sync of the relay display

- Status: accepted
- Date: 2026-10-05
- Class: situational. Supersede this record when the app gets the time of a track change from a different signal. Also supersede it when the display state carries the song line.
- Plan: [ICY sync phase plan](../plans/icy-sync-plan.md)
- Related:
  - [ADR 0008](0008-relay-display-metadata.md): this record replaces its display delay rule and its backoff fallback for a session with ICY. See §Changes at implementation.
  - [ADR 0010](0010-player-screen-without-extra-buffer.md): the player screen and the settings.

## Context

ADR 0008 applies each streamed display state after the audio that AVPlayer holds ahead of the play position.
A device test on 2026-10-04 showed that this rule is not correct:

- The operator changed the track in Mixxx. `curl` on the relay `/display` showed the new track immediately.
- The app showed the new track after about 49 seconds. That was the audio that AVPlayer held.
- The listener heard the new track after about 79 seconds.

So the display was about 30 seconds early. The rest of the delay is in `butt`, in the Icecast queue and on the network. The app cannot measure it.

A regular ICY player showed the stream title when the listener heard the track.
The ICY `StreamTitle` travels in the audio stream, so it includes each delay in the chain.

`mixxx-now-playing` writes the song line for `butt` as `artist + " - " + title` (`render_metadata_text`), and the display state with the same `artist` and `title`.
So the ICY text of a track is equal to the key of its display state.

## Decision

Display states are early. The ICY title releases them.

### The list and the selection

`IcySync` in `CitizenRadioCore` holds the rules. It has no time and no I/O.

1. `IcySync` keeps a list of a maximum of 4 display states, newest first. Each state from the snapshot or the stream goes into it. A `{"track": null}` state does not go into the list.
2. The key of a state is `"\(artist) - \(title)"`.
3. After each input, `IcySync` selects again from the list and the present ICY text:
   - An empty ICY text selects no relay track and no ICY track. The screen shows the default display.
   - Else the newest state whose key matches the ICY text is the relay track. With no match, there is no relay track, and the parsed ICY title shows with no artwork.
4. So a state that arrives before its audio waits in the list until the ICY text names it. A state that arrives after its ICY text shows immediately.
5. A relay `{"track": null}` does not clear a track while the ICY text names it. The empty ICY text clears it.

### Matching

- Before the compare, trim both texts, change each run of white space to one space, apply Unicode NFC, and ignore case.
- Compare the full ICY text with the key. Do not compare the parsed `IcyTrack`, because `IcyTitle.parse` splits at the first `" - "`.
- If no key is equal, accept the newest key that starts with the ICY text. Do this only when the normalized ICY text agrees with these conditions:
  - It has a minimum of 8 characters.
  - It has a minimum of one character after its first `" - "`.
- An equal key in a newer state replaces the older state.

### The ICY text

- A metadata group with a `StreamTitle` item gives an ICY text. An empty value is an empty ICY text.
- A metadata group with no `StreamTitle` item is not an ICY text. It changes nothing.
- "ICY in this session" means that the player item gave a minimum of one ICY text, also an empty one.

### The session

- With ICY in this session, `TrackInfoModel` shows the selection of `IcySync`. It schedules no timed apply.
- Without ICY in this session, the ADR 0008 rule applies: a streamed state applies after the audio that AVPlayer holds, and a snapshot applies immediately.
- The first ICY text of the session cancels the pending timed applies and selects from the list.
- Backoff keeps the list and the selection. During a relay outage the ICY text continues to name the track.
- These events clear the list: a `404` or `409` stop, a change of the **Track info** event, and Stop.
- Stop starts a new session. The next session has no ICY until its first ICY text.

## Alternatives considered

- **Keep the ADR 0008 delay rule.** The test of 2026-10-04 shows that the display is early by the delay before the phone, about 30 seconds.
- **A fixed delay in the publisher (`stream_delay_secs`).** One value cannot agree with each listener, because each connection has a different delay.
- **Add the song line to the display state as `stream_title`.** This removes the key rule. It needs a change to publisher ADR 0008 and relay ADR 0003. Do this only if the key fails in practice.
- **The ICY title as the only source.** It gives no artwork and no separate artist field.

## Consequences

- The relay track shows when the listener hears it, with each delay in the chain.
- After a connection near a track change, the snapshot can hold the next track. The relay does not send the older state again, so the ICY title shows with no artwork until that track ends.
- A track with no relay state shows the ICY title with no artwork.
- An ICY text that differs from the key, for example in its characters, shows the ICY title with no artwork.
- The prefix rule can select the wrong track if two tracks have the same title start. This is improbable in one list of 4 states.
- Payments are not in this record. The payment record can use the same idea.

## Invariants

These rules apply while this decision is current.

- The selection rules in the Decision section. `IcySyncTests` enforces them.
- A metadata group with no `StreamTitle` changes nothing. Manual check: examine `IcyMetadataReader`. A test cannot examine AVFoundation types on Linux.
- With ICY in this session, no display state applies from a timer. Manual check: examine `TrackInfoModel`.

## Changes at implementation

These changes go in the commit of the task that connects `IcySync` to `TrackInfoModel`:

- ADR 0008 §Display data and §Fallback name this record for a session with ICY.
- The architecture overview and the runbook describe the ICY sync.

## Acceptance criteria

### Mechanical

- `IcySyncTests` covers each rule in §The list and the selection, §Matching and the list size.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- The artwork, the title and the artist change when the listener hears the new track.
- A pause in Mixxx clears the display when the listener hears the end of the track, not before.
- "Pharaoh's Dance" shows its artwork.
- With an empty **Track info** field, the stream title changes when the listener hears the new track.
