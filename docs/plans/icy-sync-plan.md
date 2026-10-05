# ICY sync: plan

- Status: proposed, 2026-10-05. This plan does not make rules. It proposes a change to [ADR 0008](../adr/0008-relay-display-metadata.md) §Display data and §Fallback. A new ADR must accept it before work starts.
- Source: the broadcast chain repositories `musicindex-live-publisher` and `musicindex-live-relay`. The facts about them are from their source on 2026-10-04.

## Goal

The relay track shows when the listener hears that track, also with an extra buffer, a slow network or a long Icecast queue.
The ICY title in the audio stream gives the time. The relay display state gives the data: artist, title and artwork.

## The present rule and its problem

ADR 0008 applies a streamed display state after `BufferSetting.bufferedAhead`, the loaded audio ahead of the play position when the state arrives (`DisplayTiming.delay`).
A snapshot applies at once.
The ICY title shows only when there is no relay track.

`bufferedAhead` measures only the audio that AVPlayer holds. These delays are not in it:

- the encoder buffer of `butt`,
- the Icecast queue and its burst on connect,
- the network path to the phone.

The publisher target of the station has `stream_delay_secs = 0`. So each display state reaches the phone before its audio, by a time that the app cannot measure.
The artwork can change some seconds before the listener hears the new track. The error changes with each connection.

## The fact that solves it

AVPlayer gives the ICY `StreamTitle` through `AVPlayerItemMetadataOutput` at its play position.
That time includes every delay in the chain, and the extra buffer of the app.
It is the only signal that agrees with what this listener hears.

The relay is adjacent to Icecast. It cannot know the buffer of each listener. So the sync is done in the app, and the relay does not change for it.

## The join key

One producer, `mixxx-now-playing`, writes both texts for each track:

- The song file for `butt`. Its first line is `artist + " - " + title` (`render_metadata_text` in `mixxx-now-playing/src/render.rs`). `butt` sends that line as the ICY `StreamTitle`.
- The display state. It holds the same `artist` and `title` strings.

So the key of a display state is `"\(artist) - \(title)"`. It is equal to the ICY text of its track.

When nothing plays, the song file is empty. `butt` then sends an empty `StreamTitle`. This agrees with `{"track": null}`.
The operator confirmed both on 2026-10-04 with `butt` 1.46.0.

## The proposed rule

Display states are early, and the ICY title releases them.

1. Keep a short list of display states, newest first, with a maximum of 4. Each state from the snapshot or the stream goes into it.
2. When the ICY text changes to an empty text, show the default display. Do this also when the newest relay state is a track.
3. When the ICY text changes to a text, find the newest state in the list whose key matches it. Show that state.
4. If no state matches, show the ICY title with no artwork, as the fallback does now. Keep waiting.
5. When a new state arrives, add it to the list. Show it at once only if its key matches the ICY text that shows now.
6. A relay `{"track": null}` does not clear a track while the ICY text still has that track. The listener still hears it. The empty ICY text clears it.
7. Without ICY in this session, use the present rule of ADR 0008. "ICY in this session" means that the metadata output gave at least one `StreamTitle`, also an empty one, since the item started.

The extra buffer of the app needs no rule. AVPlayer reports the ICY title after the extra buffer, so the display follows it.

### Matching

- Compare the full ICY text with the key. Do not compare the parsed `IcyTrack`. `IcyTitle.parse` splits at the first " - ", so an artist with " - " in its name does not round-trip.
- Before the compare, trim both texts, collapse runs of white space to one space, use Unicode NFC, and ignore case.
- If no key is equal, accept the newest key that starts with the ICY text, when the ICY text has at least 8 characters. Some players and servers cut a title at an apostrophe or at a length limit. "Pharaoh's Dance" is a station track with an apostrophe.
- Two keys that are equal are one track. The newest state wins.

### What changes in the code

- `IcyMetadataReader` gives the raw text as well as the parsed `IcyTrack`. `IcyTitle.parse` stays for the fallback lines.
- A new pure type in `CitizenRadioCore`, for example `IcySync`, holds the list and the rules. It takes three inputs: a display state, an ICY text, and "no ICY". It gives the lines to show. Linux tests examine it.
- `TrackInfoModel` sends the display states and the ICY text to `IcySync`. It schedules no timer while ICY is available.
- `DisplayTiming` stays, for rule 7.

## Relay facts for the client

- Since 2026-10-04, `/display/events` with no `Last-Event-ID` sends the present state as its first event (relay ADR 0003, amended). With rule 1 this is harmless: the state goes into the list.
- Keep the snapshot read before each stream. A relay restart sets the display `seq` back to 1. A reconnect with an older, higher `Last-Event-ID` then gets no replay. The snapshot gives the present state.
- A relay fix found on 2026-10-04 makes sure that such a reconnect still gets each new state. It is in the relay branch `display-seq` and waits for a deploy.
- A relay restart clears the display state. The publisher sends it again after its next keepalive, within about one keepalive interval.

## Payments

Payments are not in this plan. The payment ADR owns them. The same idea applies:

- Each live value payload has a `title`. For a V4V track it is the track title. Without a payable track it is "No V4V track playing".
- The app can keep the payloads in the same way and pay the payload whose track the ICY text names. During a mismatch, the app pays nobody, or it holds the payment.
- Podcast apps do not do this. They apply each payload when it arrives, and the broadcaster sets one delay for all listeners. The Split Kit has the same model (`broadcastDelay`).

## Risks and edge cases

| Case | Behavior with this plan |
|---|---|
| The same track twice in a row | The key does not change, so the display does not change. |
| ICY text with a different encoding | NFC and the case rule handle most cases. A text that still does not match shows the fallback lines. |
| A title cut by a server or a player | The prefix rule. |
| The relay is down | The ICY title shows, as now. |
| No ICY in the stream | Rule 7, the present timer rule. |
| A track with no relay state, for example after a relay restart | The ICY title shows until the publisher sends the state again. |
| A new state arrives before its audio | It waits in the list until ICY names it. |
| The relay sends `null` before the listener hears the end of the track | Rule 6 keeps the track until the ICY text is empty. |

## Acceptance criteria

### Mechanical

Each criterion is a test of `IcySync` in `Tests/CitizenRadioCoreTests/`.

- An ICY text that matches a waiting state shows that state.
- A state that arrives before its ICY text does not show until the ICY text names it.
- A state that arrives after its ICY text shows at once.
- An empty ICY text shows the default display, also with a waiting track state.
- A relay `null` does not clear a track while the ICY text names that track.
- The prefix rule matches a cut title of 8 characters or more, and does not match a shorter one.
- Case, white space and NFC differences match.
- The list keeps 4 states at most, and the newest wins.
- Without ICY, the present timer rule applies.

### Visual

A person must examine these items on an iPhone. Report each item as open until that examination is complete.

- With the extra buffer at 0, 10 and 30 seconds, the artwork changes when the listener hears the new track.
- A pause in Mixxx clears the display when the listener hears the end of the track, not before.
- "Pharaoh's Dance" shows its artwork.

## Open questions

- Does the station stream on the device give the ICY text with each change, and an empty text on a pause? The relay display plan marks the ICY read as not tested on the device.
- Is a list of 4 states enough when the extra buffer is 30 seconds and tracks are short?
- Should the publisher add the exact song line to the display state, as `stream_title`? It would remove the key rule. It needs a change to publisher ADR 0008 and relay ADR 0003. Do it only if the key fails in practice.
