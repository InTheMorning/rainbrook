# ICY sync: phase plan

- Status: implemented, 2026-10-05. The visual checks are open. This plan does not make rules. [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md) owns them.
- Source: the broadcast chain repositories `musicindex-live-publisher` and `musicindex-live-relay`. The facts about them are from their source on 2026-10-04.
- Review: [ICY sync review checklist](../reviews/icy-sync-review-checklist.md).

## Goal

The relay track shows when the listener hears that track, with each delay in the chain.
The ICY title in the audio stream gives the time. The relay display state gives the data: artist, title and artwork.

## Non-goals

- No change to the relay or to the publisher.
- No payments. The payment record owns them.
- No new setting. ICY sync is always on when the stream has ICY.

## Assumptions

- `butt` sends `artist + " - " + title` as the ICY `StreamTitle`, and an empty `StreamTitle` when nothing plays. The operator confirmed this on 2026-10-04 with `butt` 1.46.0.
- AVPlayer gives each `StreamTitle` at its play position. A regular ICY player showed the title in time on 2026-10-04. The visual criteria of ADR 0011 examine this app.

## Affected modules

| Module | Change |
|---|---|
| `CitizenRadioCore` | New `IcySync` with tests. |
| `IcyMetadataReader` | Gives the raw ICY text. Ignores a group with no `StreamTitle`. The ICY timing log goes. |
| `RadioPlayer` | Publishes the raw ICY text. |
| `TrackInfoModel` | Uses `IcySync` when the session has ICY. Keeps the timed rule without ICY. |
| Documents | ADR 0008, the architecture overview and the runbook. |

## Sequence

| Task | Wave | Model | Depends on |
|---|---|---|---|
| [001: `IcySync`](../tasks/icy-sync-task-001-icy-sync-core.md) | 1 | Sonnet | none |
| [002: ICY text from the reader](../tasks/icy-sync-task-002-icy-text.md) | 1 | Sonnet | none |
| [003: Integration and documents](../tasks/icy-sync-task-003-integration.md) | 2 | Opus | 001, 002 |

Tasks 001 and 002 change different files, so they can run at the same time.

## API implications

- `IcySync` is a new public type in `CitizenRadioCore`.
- `RadioPlayer` publishes `icyText: String?`. Nil means no ICY in this session. Task 003 removes `RadioPlayer.icyTrack`, and `TrackInfoModel` parses the text.
- `IcyMetadataReader` calls `onText(String)` only for a group with a `StreamTitle` item.
- No change to the relay client, the artwork loader or the settings.

## Risks

| Case | Behavior |
|---|---|
| The same track two times in sequence | The key does not change, so the display does not change. |
| ICY text with a different encoding | NFC and the case rule correct most differences. Else the ICY title shows with no artwork. |
| A title cut by a server or a player | The prefix rule. |
| The relay is down | The matched state stays. Without a match, the ICY title shows. |
| No ICY in the stream | The ADR 0008 timed rule. |
| A track with no relay state | The ICY title shows with no artwork. |
| A connection near a track change | The ICY title shows with no artwork until that track ends. |
| A metadata group with no title | Nothing changes. |
| `butt` sends no empty title on a pause | The last track stays until the next ICY text. |

## Test strategy

- Task 001: Linux tests of `IcySync` for each rule in ADR 0011. No time and no I/O in the type.
- Task 002: `scripts/check.sh` builds the reader in Swift 6. The reader logic is too small for a separate core type.
- Task 003: `scripts/check.sh`, then the ADR 0011 visual criteria on an iPhone.

## Rollback

Revert the commit of task 003. Then `TrackInfoModel` uses the ADR 0008 timed rule again. Tasks 001 and 002 can stay, because nothing else uses them.

## Relay facts for the client

- Since 2026-10-04, `/display/events` with no `Last-Event-ID` sends the present state as its first event (relay ADR 0003, amended). The state goes into the list, so this is harmless.
- Keep the snapshot read before each stream. A relay restart sets the display `seq` back to 1, so a reconnect with an older, higher `Last-Event-ID` gets no replay. The snapshot gives the present state.
- A relay restart clears the display state. The publisher sends it again after its next keepalive.

## Payments

Payments are not in this plan. The same idea can apply:

- Each live value payload has a `title`. For a V4V track it is the track title. Without a payable track it is "No V4V track playing".
- The app can keep the payloads in a list and pay the payload whose track the ICY text names.
- Podcast apps apply each payload when it arrives, so they pay early by the delay of each listener. CitizenRadio cannot correct that.

## Open questions

- Does the station stream on the device give an empty ICY text on a pause?
- Should the publisher add the exact song line to the display state, as `stream_title`? Do this only if the key fails in practice.
