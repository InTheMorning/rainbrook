# Shown Words And The Glossary

- Date: 2026-11-22
- Code: citizenradio commit `58bbda6`
- Glossary: `~/build/musicindex/docs/glossary.md`, as on 2026-11-22
- Rule: musicindex ADR 0087 R-WORD-12 item 2 and R-WORD-13
- Request: the orchestrator session, task of 2026-11-22

This review lists each word that citizenradio shows for feed data or value data. For each word, it gives the
glossary row that holds the word, or it says that no row exists. This review changes no shown word and adds no
glossary row. The orchestrator session sends each word with no row to the website session, and each conflict to the
operator.

## Method

The main session read each string literal in `CitizenRadio/*.swift` and `CitizenRadio/Core/*.swift`. It kept the
strings that a view, a status text, Now Playing or an App Intent shows. It removed the log texts of
`PlaybackDiagnostics` and `Logger`, and the words for the wallet connection and for playback only. A word that the
app shows only as a value from the relay, with no label, is in the list with the note "value, no label".

## Words With A Row

| Shown word | Where the app shows it | Glossary row | Note |
| --- | --- | --- | --- |
| Title (of a song) | Value, no label: `PlayerView.swift:77`, `BoostSheet.swift:43`, `BoostHistoryView.swift:41`, Now Playing (`TrackInfoModel.swift:536`) | "Title (of a song)" | The value comes from the relay display state or from the ICY title. |
| Artist (of a song) | Value, no label: `PlayerView.swift:80`, `BoostSheet.swift:46`, `BoostHistoryView.swift:83`, Now Playing | "Artist (of a song)" | Now Playing shows "Live radio" when the artist is missing (`TrackLines.swift:8`). |
| Album title | Value, no label: `PlayerView.swift:87`, Now Playing (ADR 0019) | "Album title" | |
| Track | "Track info" (`StationEditorView.swift:59`), "V4V track" (`WalletSettingsView.swift:63`, `BoostModel.swift:213`), "The track has no payment destination." and "The track played for less than" (`BoostStatusText.swift:36`, `:38`), "Relay track" is a log text only | "Track" | The app uses "track" for the item that plays on the station, also when the item is an episode. See conflict 3. |
| Recipient | Fallback name of a payment part: `BoostSheet.swift:80`, `BoostHistoryView.swift:95` | "Recipients" | |
| Split | Section heading in the manual boost sheet: `BoostSheet.swift:78` | "Split (Studio field label)" | The section shows the sats of each recipient. See conflict 1. |
| Stream | Station field and messages: `StationEditorView.swift:43`, `PlayerView.swift:103`, `RadioPlayer.swift:372` | "Stream, Stream address" | The person enters the address. The app reads no feed for it. |
| Live | "Playing live" (`PlaybackState.swift:12`), "The live stream ended." (`RadioPlayer.swift:422`), "Live radio" (`TrackLines.swift:8`) | "Live, Live item, Live now" | The app uses "live" for the stream state, not for a `podcast:liveItem` of a feed. |

## Words With No Row

| Shown word | Where the app shows it | Data | Note |
| --- | --- | --- | --- |
| Track info, track info address | `StationEditorView.swift:59`, `:62`, `RelayEvent.swift:12`, `RelayStatusText.swift:10`, `Station.swift:111` | The relay event address | See conflict 2. |
| Relay event, relay event address | `StationEditorView.swift:64`, `RelayEvent.swift:14`, `RelayStatusText.swift:10`, `:12` | The relay event address | See conflict 2. |
| V4V track | `WalletSettingsView.swift:63`, `BoostModel.swift:213` | A track with a payable live value | The relay title "No V4V track playing" (`LiveValue.swift:36`) is a relay value. The app compares it and does not show it. |
| Payment destination | `BoostStatusText.swift:36` | `podcast:valueRecipient` | See conflict 4. |
| Boost, Boosted | `PlayerView.swift:132`, `BoostSheet.swift:113`, `BoostHistoryView.swift:140`, `BoostStatusText.swift:13` | A payment that the listener sends | |
| Auto-boost | `WalletSettingsView.swift:122`, `BoostHistoryView.swift:139` | A boost that the app sends at the end of a track | |
| Boost history | `WalletSettingsView.swift:157`, `BoostHistoryView.swift:30` | The record of the boosts | |
| Boost amount, Amount | `WalletSettingsView.swift:125`, `BoostSheet.swift:54`, `BoostHistoryView.swift:87` | The sats of one boost | |
| Boost message, Message | `WalletSettingsView.swift:146`, `BoostSheet.swift:64` | The boost record field `message` (ADR 0023) | |
| From | `WalletSettingsView.swift:148` | The boost record field `sender_name` (ADR 0023) | |
| App name | `WalletSettingsView.swift:150` | The boost record field `app_name` (ADR 0023) | |
| sats | `BoostSheet.swift:57`, `BoostHistoryView.swift:87`, `BoostStatusText.swift:13` | The unit of an amount | |
| Payments, Payment details | `BoostHistoryView.swift:92`, `BoostSheet.swift:93` | The parts of one boost | |
| Keysend | `BoostHistoryView.swift:73`, `BoostHistory.swift:349` | `type="node"` of `podcast:valueRecipient` | The glossary row "Type" holds the attribute. It does not hold its values. |
| Lightning address | `BoostHistoryView.swift:74`, `BoostHistory.swift:372` | `type="lnaddress"` of `podcast:valueRecipient` | Same note as "Keysend". |
| Invoice | `BoostHistory.swift:351` | The LNURL payment path of a lightning address (ADR 0023) | This is not feed data. |
| Confirmed, Failed, Unknown | `BoostHistory.swift:335` to `:339` | The result of one payment part | This is not feed data. |
| Station, Stations, Add Station, Station name | `SettingsView.swift:123`, `:129`, `StationEditorView.swift:36`, `:75` | A stream that the person saves | The app reads no feed for a station. |
| Alternate stream | `StationEditorView.swift:50`, `PlayerView.swift:103` | A second stream address that the person enters | The glossary row "Alternate files" holds `podcast:alternateEnclosure`. The app does not read that element. |

The app shows no word for fee, show, episode, live item, feed, feed GUID or item GUID. It also shows no word for
value routes, value time splits or remote percentage. The app reads `fee` from the relay as a JSON boolean
(`LiveValue.swift:146`) and does not show it.

## Conflicts

These are differences between the shown words and the glossary. The operator decides each one.

1. **Split.** The glossary row "Split (Studio field label)" holds the `split` attribute of `podcast:valueRecipient`.
   ADR 0086 §Terms uses "split" for a `podcast:valueTimeSplit` element. The section "Split" of the boost sheet shows
   the division of the boost amount by the `split` attribute. The app thus follows the glossary row, but the word has
   two meanings in the suite records.

2. **Track info and relay event address.** The person enters the relay event address in the station field "Track
   info". The research document `docs/research/musicindex-relay-metadata.md` (line 63) says that this address form
   goes in `podcast:liveValue`. Inference: the address is the `uri` of `podcast:liveValue`. The app shows "Track info"
   and "relay event address", but the glossary row for that attribute gives "Live value address" (Studio).

3. **Track for an episode.** R-WORD-11 item 3 gives "Episode" for an item of a feed with a medium other than `music`.
   The app does not know the medium of the item that plays. It shows "track" in all status texts, also when a station
   plays an episode file.

4. **Payment destination.** The glossary gives "Recipients" for `podcast:valueRecipient` (ADR 0085 R-WORD-2). The
   app shows "Recipient" for a part with no name, and "payment destination" in the status text
   `BoostStatusText.swift:36`. The app thus has two words for one term.

## The Relay Event At Each Chapter Change

The orchestrator session gave this expected effect as an inference. The station producer pays each chapter song of
an episode file (publisher ADR 0025). Thus a station gives a new relay event at each chapter change. The form of the
event does not change.

The decode of the event does not break. `TrackDisplay` and `LiveValuePayload` read the same fields. The code shows
a different risk, in the selection of the relay track:

- `IcySync.match` (`IcySync.swift:95`) selects a display state only when its key "artist - title" is equal to the
  ICY text, or starts with it. With an ICY text, the player screen, Now Playing, the auto-boost and the manual boost
  use only that selected state (`TrackInfoModel.swift:427` to `:439`).
- Publisher ADR 0025 §What The Producer Writes For An Episode File gives each chapter state the chapter title and
  the chapter artist. That record names no ICY change at a chapter change. Inference: the ICY text stays the title
  of the episode file for the full episode.
- Inference, from the code: with an ICY text, the app does not show a chapter song and does not pay it. The app
  keeps the episode state while it is one of the last 4 states (`IcySync.capacity`). After 4 chapter states, no
  state matches. The player screen then shows the ICY text with no artwork, and the Boost button is off.
- Inference, from the code: `BoostPairing` keeps 8 payloads (`BoostPairing.capacity`). After 8 chapter blocks, the
  episode payload is gone, and the auto-boost at the end of the episode has no payment destination.
- With no ICY text, the app shows each relay state when it arrives (`TrackInfoModel.swift:439`). Then each chapter
  song shows.

No test examines this condition. A station check with an episode file that has chapters can prove or disprove these
inferences.
