# ADR 0017: Stations with an alternate stream

- Status: accepted
- Date: 2026-10-06
- Class: situational. Supersede this record when the station data, the fallback rule or the place of the station list changes.
- Related:
  - [ADR 0011](0011-icy-sync-of-the-relay-display.md): a fallback starts a new ICY session.
  - [ADR 0013](0013-boosts.md) and [ADR 0016](0016-boost-switch-back-play-time-and-retry.md): a fallback ends the trigger session.
  - [ADR 0006](0006-audio-session-off-main-thread.md): blocking work stays off the main thread.
  - [Upstream live metadata plan](../plans/upstream-live-metadata-plan.md): the HLS stream and its checks.
- Tasks: [stations task 001](../tasks/stations-task-001-station-store.md), [stations task 002](../tasks/stations-task-002-fallback-and-list.md).

## Context

The app keeps one stream URL and one **Track info** URL.

On 2026-10-06 the operator asked to keep more than one URL. Each entry has an HLS stream, an Icecast stream as its alternate, and a **Track info** URL. The operator selects an entry from a list in Settings.

The station has these streams:

- HLS: `https://bastone.heycitizen.xyz/hls/live.m3u8`, from liquidsoap. It carries the title in ID3 frames.
- Icecast: `https://bastone.heycitizen.xyz/stream`, with ICY titles.

## Decision

### The station

A station has:

- **Name**: 1 to 40 characters. An empty name gives the host of the primary stream.
- **Stream**: the primary stream URL. It is necessary. The rules of `StreamAddress` apply.
- **Alternate stream**: an optional second stream URL, with the same rules. It must not be equal to the primary stream.
- **Track info**: an optional relay event URL, with the rules of `RelayEvent`.

The app keeps a maximum of 20 stations, and the identifier of the selected station. The list is JSON in `UserDefaults`.

### The first start after the update

If no station list exists, the app examines the old stream URL. If that URL is saved, the app makes one station from it and from the old **Track info** URL, and selects that station. Then the app removes the old keys. With no old stream URL, the list is empty.

### The station list

- Settings has a **Stations** section with the list. A mark shows the selected station.
- A tap on a station selects it and starts its playback.
- **Add** opens an empty station editor. A tap on the info button of a row opens its editor. A swipe deletes a station.
- The editor has **Save**. **Save** is not possible while a field is not correct.
- A delete of the selected station stops the playback, and no station is selected.
- The App Intents and the `citizenradio://play` URL play the selected station.

### The fallback

- Playback starts with the primary stream.
- If the primary stream fails, and the station has an alternate stream, the app plays the alternate stream. A failure is one of these:
  - The player item fails.
  - The stream does not play in the connection time limit of 20 seconds, also after a stall.
  - The stream ends.
- If the alternate stream fails, playback stops with the error, as now.
- The app does not go back to the primary stream in the same playback session. The next **Play** starts with the primary stream again.
- The player screen shows "Alternate stream" while the alternate stream plays.
- For the ICY sync and the boost trigger, a fallback is a new session:
  - The ICY sync has no ICY text until the first text of the alternate stream. Its list of display states stays, because those states arrive before the audio.
  - The trigger drops its candidate. The paid blocks and the payloads stay.
  - The relay connection does not change.

## Alternatives considered

- **A list of stream URLs only.** The **Track info** URL then does not follow the station.
- **Go back to the primary stream after a time.** Each change between HLS and Icecast repeats or misses audio, because the two streams have different delays. One change in a session is enough.
- **Keep the ICY session across a fallback.** The two streams have different delays, so the trigger can see a change back as a repeat or as a new track. A new session can miss one auto-boost, but it never pays twice.
- **A station menu on the player screen.** The operator selected the list in Settings.

## Consequences

- The operator can keep HLS and Icecast in one station, and more stations for tests.
- A failure of the primary stream costs a maximum of 20 seconds before the alternate stream starts.
- After a fallback, the display shows the default text until the first title of the alternate stream arrives.
- The old stream URL and **Track info** settings move into the first station.

## Invariants

These rules apply while this decision is current.

- The station field rules, the limit of 20, the selection rules and the first start rule. `StationStoreTests` enforces them.
- The stream sequence: primary, then alternate, then the error. `StationTests` enforces it.
- One fallback in a session, and the new ICY and trigger session after it. Manual check: examine `RadioPlayer` and `TrackInfoModel`.

## Acceptance criteria

### Mechanical

- Each invariant test above exists and passes.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- After the update, the old stream and **Track info** show as one selected station.
- A tap on a station plays it. The artwork and the title of that station show.
- Give a station a primary stream that does not work. The station plays the alternate stream after a maximum of 20 seconds, and the player screen shows "Alternate stream".
- The HLS stream shows the title and the artwork of the track.
- Siri and the Shortcuts **Play** action play the selected station.
