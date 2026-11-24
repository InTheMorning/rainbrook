# ADR 0028: The station title and image from the dead block

- Status: accepted
- Date: 2026-11-24
- Revised: 2026-11-24, before the first push. Phone check 1 failed on a jingle with no title. Rule 3 accepts a dead
  block with no destinations (operator decision, relayed by the orchestrator session). Rules 6 and 7 replace the old
  rule 6. A review of `0a90815` added the dead block test to rule 7 and the clear on a new ICY text to rule 6.
- Bar: crosses repositories. Publisher ADR 0029 sends the station title and the station image in the dead block
  payload. This record sets how the app shows them.
- Changes: [ADR 0008](0008-relay-display-metadata.md) §Display data item 4, and §Player screen and Now Playing items
  1, 2 and 4.
- Changes: [ADR 0014](0014-player-screen-with-boost-button.md) §Decision items 1 and 2, and the Now Playing text of
  §Core logic.
- Changes: [ADR 0013](0013-boosts.md) §Manual boost: a track whose value block ended has no manual target.
- Changes: [ADR 0022](0022-playback-log-and-artwork-retry.md) §The playback log item 2, and §The artwork retry items
  1 and 3.
- Operator choice, 2026-11-24, relayed by the orchestrator session: during a jingle the app shows the dead block title
  and image. The other option was the art and the title of the last live item.
- Class: situational. Supersede this record when the publisher changes the dead block, or when the app gets the
  station identity from a different source.
- Related:
  - [ADR 0026](0026-dead-block-title-and-artist-title-payload.md): the dead block and its reserved host.
  - [ADR 0015](0015-artwork-from-url-and-animated-gif.md): the artwork load and the animated GIF decode.
- Task: [display task 001](../tasks/display-task-001-station-identity-and-artwork-load.md)

## Context

- Publisher ADR 0029 makes the dead block title a station setting, and commit `b9e35b1` adds the setting
  `dead_block_image`. The dead block payload has the station title in `title` and the station image in `image`.
  Each block gets a new `blockGuid`, but the title and the image do not change.
- The relay log of the HeyCitizen test station on 2026-11-24 at 05:22 shows a jingle:
  1. The ICY text is empty.
  2. The display state is `{"track": null}`.
  3. Two dead block payloads arrive with the title "HeyCitizen Test Stream" and an image URL.
  4. The ICY text "AzuraCast.com - AzuraCast is Live!" arrives, then a display state with that text, no artwork and no
     value.
- The app did not decode `image`. So it showed "CitizenRadio" with the placeholder, then "AzuraCast is Live!" with the
  placeholder.
- The relay log of 12:17 to 12:42 UTC shows a jingle with no title at 12:27:40. The ICY text stays "Anni Powell -
  Beyond the Hills" for 24 s. The relay sends that song again with no value block, and a dead block payload. Then the
  ICY text and the display state of the next song arrive. The publisher sends the same sequence for 1 to 6 s between
  two songs. The app matched the ICY text to the song, so it showed the song title and image during the jingle.
- The title pairing of ADR 0026 finds the payload of that song for a state with no value block. So the **Boost** button
  stayed active during the jingle, and a manual boost paid the artist of the song that ended.
- The operator decided on 2026-11-24 that the publisher sends the dead block with `value.destinations: []`, and with
  no `feedGuid` and no `itemGuid`.
- The operator also reported artwork that stays missing until the next song. The relay data shows no cause. The song
  images load in less than 0.4 s on the test machine. Some GIF images have 18 to 40 MB and a maximum of 878 frames. The
  playback log did not record the size and the time of a load, so the cause is not known.

## Decision

### The station identity

1. `LiveValuePayload` decodes `image`. Only an `http` or `https` URL with a host is kept.
2. A payload is the dead block when its title is "No V4V track playing". A payload is also the dead block when it has
   no payable destination, and its `value.destinations` is an empty array or has a lightning address destination
   with a reserved host (ADR 0026). An empty array is not an error.
3. The newest dead block payload of the event gives the station identity: its title and its image. The default dead
   block title gives no station title. A change of the event clears the identity. Stop does not clear it.

### The display

4. The default lines take the station title in place of "CitizenRadio". The default lines are the lines with no relay
   track and no ICY track. Now Playing gets the same title, and "Live radio" as the artist.
5. The screen and Now Playing show the track image, or else the station image, or else the placeholder. So the station
   image shows when the lines have no artwork, while a track image loads with no earlier image, and after its
   retries end.
6. The value block of a key ends when `IcySync` gets a state with no value block after a state of the same key with
   a value block. A new state of that key with a value block clears the condition. A different ICY text clears the
   condition for each key. While the selected track has no
   value block and its value block ended, the lines are the station lines: the station title, or "CitizenRadio" when
   the station has no title, with no artist and no artwork. Without a station identity, the lines do not change.
7. The **Boost** button is gray (`BoostModel` has no manual target) while the value block of the selected track ended,
   and while the newest live value payload is the dead block. `BoostPairing.manualPayload(for:valueEnded:)` holds the
   rule. The dead block payload can arrive before the display state with no value block, or with no such state. The
   trigger and the auto-boost use the pairing with no change, so the auto-boost of the song that ended stays as
   ADR 0013 states.
8. Each other relay track or ICY track keeps its own title and artist. The app cannot tell a jingle with its own tags
   from a song with no value block. A song that starts with no value block shows its own lines.

### The artwork load

9. The decode runs off the actor of `ArtworkLoader`. So a large animated image does not hold the next load. A canceled
   load stops between frames.
10. When the animated decode of a GIF fails, the first frame gives a still image.
11. A new track with the same artwork loads that artwork again when its retries ended with no image.
12. The playback log records each download: the size in KB, the download time, and the decode result and time. It also
    records each station image load result.

## Options

- **Show the art and the title of the last live item during a jingle.** Rejected by the operator choice. The
  publisher jingle mode already gives this result when the station turns it on.
- **Show the station title for each relay track with no value block.** Rejected. A song with no V4V block then loses
  its title. Rule 6 uses only a value block that ended.
- **Skip the title pairing while the newest payload is the dead block.** Rejected. The auto-boost of the song that
  ended runs when the next ICY text arrives, often before the payload of the next song. That auto-boost then fails.
- **Read the station title and image from the station settings in the app.** Rejected. The publisher owns the
  setting, and each dead block payload carries it.
- **Apply the station identity with the display delay.** Rejected. The title and the image do not change between
  blocks, so no delay is necessary.

## Consequences

- During a jingle with an empty ICY text, the screen shows the station title and the station image.
- During a jingle with no title, the screen shows the station title and the station image, and **Boost** is gray.
- During a jingle with its own tags, the screen shows those tags and the station image.
- Between two songs on Icecast, the station lines show for 1 to 6 s.
- On HLS the display states and the payloads arrive before the audio. So the station lines can show, and **Boost** can
  become gray, before the end of the song audio, for a maximum of the stream delay. This is an open point. It does not
  pay an incorrect artist.
- The replay on connect (ADR 0018) gives the states after the snapshot. Older states can then select the song again for
  some milliseconds, until the replay gets to the snapshot state. The dead block test of rule 7 keeps **Boost** gray
  while the dead block payload is the newest.
- Between songs on Icecast, the ICY lines can show for about 1 s with no artwork. The station image now shows in
  that time.
- A station with no dead block title and no dead block image shows the default display, as before.
- The playback log can now show if a missing artwork is a download failure, a slow download or a decode failure.

## Invariants

These rules apply while this decision is current.

- Rules 1 to 4, 6 and 8. `StationIdentityTests` enforces them.
- Rules 5, 7, 9, 10, 11 and 12 are in `TrackInfoModel` and `ArtworkLoader`, which use UIKit. A test on Linux cannot examine
  them. Manual check: read the diff, and examine the playback log on the phone.

## Acceptance criteria

### Mechanical

- `StationIdentityTests` passes.
- `scripts/check.sh` passes. It includes the iOS build.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- During a jingle with an empty ICY text, the screen shows "HeyCitizen Test Stream" and the station image.
- During a jingle with no title, the screen shows "HeyCitizen Test Stream" and the station image, and **Boost** is
  gray. The next song shows its own lines and image.
- During the "AzuraCast is Live!" jingle, the screen shows that title and the station image.
- A song with an artwork shows its own image.
- When a song artwork is missing, the playback log shows an "Artwork download:" line with the size and the times.
