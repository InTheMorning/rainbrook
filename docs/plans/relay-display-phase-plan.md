# Relay display: phase plan

- Status: active, 2026-10-05.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md). This plan does not make rules. ADR 0008 owns them.
- Research: [musicindex relay metadata](../research/musicindex-relay-metadata.md).
- Review: [review checklist](../reviews/relay-display-review-checklist.md).

## Goal

The player screen, the lock screen and the car show the artwork, the title and the artist of the track that plays.
The data comes from the relay display path, and from the ICY title as the fallback.

## Non-goals

- The live value and payments.
- An album field, a relay read token, and CarPlay screens.
- Changes to playback, the buffer, the chime, the App Intents or the wallet.

## Assumptions

- The station event `https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w` is reserved and has a display state. A live check on 2026-10-05 confirmed this.
- The relay sends an SSE keepalive comment each 15 seconds (axum default).
- The Icecast stream sends `StreamTitle` in its ICY metadata, and AVPlayer gives it through `AVPlayerItemMetadataOutput`. This is not tested on the device.

## Affected modules

| Module | Change |
| --- | --- |
| `CitizenRadio/Core/` | New: `RelayEvent`, `EventStreamParser`, `TrackDisplay`, `IcyTitle`, `EventStreamClient`, `DisplayTiming`, `TrackLines`, `ArtworkPolicy`, `LRUCache`, `RelayEventStore`. Changed: `StreamSettingsDraft`. |
| `CitizenRadio/` (iOS) | New: `URLSessionEventStream`, `NetworkPathMonitor`, `ArtworkLoader`, `IcyMetadataReader`, `TrackInfoModel`. Changed: `RadioPlayer`, `PlayerView`, `SettingsView`. |
| `CitizenRadio.xcodeproj/project.pbxproj` | The new files. Task 009 only. |
| Docs | A new player screen record replaces ADR 0004 (task 008). Architecture overview, README, runbook (task 009). |

## Proposed sequence and model routing

Each task is one commit. The orchestrator reviews each diff and runs `scripts/check.sh` before the commit.

| Wave | Task | Content | Depends on | Model |
| --- | --- | --- | --- | --- |
| 1 | [001](../tasks/relay-display-task-001-parsers.md) | `RelayEvent`, `EventStreamParser`, `TrackDisplay`, `IcyTitle` | none | Haiku: pure parsers with an exact specification |
| 2 | [002](../tasks/relay-display-task-002-event-stream-client.md) | `EventStreamClient`: snapshot, stream, watchdog, backoff, stop | 001 | Opus: concurrency and time rules |
| 2 | [003](../tasks/relay-display-task-003-timing-and-lines.md) | `DisplayTiming`, `TrackLines` | 001 | Haiku: pure functions |
| 2 | [005](../tasks/relay-display-task-005-artwork.md) | `ArtworkPolicy`, `LRUCache`, `ArtworkLoader` | 001 | Sonnet |
| 2 | [006](../tasks/relay-display-task-006-icy-reader.md) | `IcyMetadataReader` and `RadioPlayer.icyTrack` | 001 | Sonnet |
| 2 | [007](../tasks/relay-display-task-007-track-info-setting.md) | `RelayEventStore` and the **Track info** setting | 001 | Sonnet |
| 3 | [004](../tasks/relay-display-task-004-url-session-stream.md) | `URLSessionEventStream`, `NetworkPathMonitor` | 002 | Sonnet |
| 4 | [008](../tasks/relay-display-task-008-integration.md) | `TrackInfoModel`, player screen, Now Playing, new player screen record | all before | Opus: integration of many parts |
| 5 | [009](../tasks/relay-display-task-009-xcode-and-docs.md) | Xcode project and docs | 008 | Sonnet |

Wave 2 tasks change separate files, so they run in parallel, each in its own git worktree.

## Schema and API implications

- New UserDefaults key: `citizenRadio.relayEventURI`.
- New public types in `CitizenRadioCore`, as the module table lists. The task packets fix their names and signatures.
- `RadioPlayer` gets `icyTrack` (task 006), `bufferedAheadSeconds()` and a Now Playing track input (task 008).
- No change to the App Intents, so the intents metadata stays valid.

## Risk areas

| Risk | Control |
| --- | --- |
| The SSE client hangs on a dead connection in a car. | Task 002 tests the watchdog, the backoff and the network change with a fake connection and an injected sleep function. |
| A blocking call on the main thread. | ADR 0006 rule. The review checklist examines each network, image and metadata call. |
| `AVPlayerItemMetadataOutput` does not deliver the ICY title for this stream. | Device check after task 006. The relay path works without it. |
| The artwork changes early or late. | Task 003 tests the delay rule. Device check after task 008. |
| The Xcode project breaks. | Task 009 only. The friend's next metadata run is the check. |

## Test strategy

- **Linux:** each core type has a test file. `EventStreamClient` uses fake connections and an injected sleep function, so the tests need no network and no real time.
- **iOS build:** `scripts/check.sh` after each task.
- **Device:** the ADR 0008 visual criteria after task 008.

## Rollback strategy

- Each task is one commit. Use `git revert <commit>` for one task.
- With an empty **Track info** field, the relay code does not run.
- To remove the feature, revert the tasks in reverse sequence.
