# Relay replay task 001: Metadata snapshot and replay on connect

- Decision: [ADR 0018](../adr/0018-instant-snapshots-and-replay-on-connect.md). Model: Opus.
- Plan: [upstream live metadata plan](../plans/upstream-live-metadata-plan.md), Phase 2c.
- Depends on: none.

## Goal

The value client reads its snapshot from `GET /metadata`. Each client asks for its recent updates on connect when its snapshot has a `seq`. A replayed display state fills only the ICY sync list.

## Files to inspect

- `docs/adr/0018-instant-snapshots-and-replay-on-connect.md`, `docs/adr/0008-relay-display-metadata.md` §Transport
- `CitizenRadio/Core/EventStreamClient.swift`, `CitizenRadio/Core/EventStreamParser.swift`, `Tests/CitizenRadioCoreTests/EventStreamClientTests.swift`
- `CitizenRadio/Core/RelayEvent.swift`, `Tests/CitizenRadioCoreTests/RelayEventTests.swift`
- `CitizenRadio/Core/LiveValue.swift`, `Tests/CitizenRadioCoreTests/LiveValueTests.swift`, `CitizenRadio/Core/BoostPairing.swift`
- `CitizenRadio/TrackInfoModel.swift` (`startRelay`, the display update handler, `startValueClient`, `handleValue`)
- `~/build/musicindex-live-relay/README.md` §The Listener Timeline, §Read Latest Metadata, §Subscribe With SSE and §Display State

## Files likely to change

- `CitizenRadio/Core/EventStreamClient.swift` and its tests
- `CitizenRadio/Core/RelayEvent.swift` and its tests
- `CitizenRadio/Core/LiveValue.swift` and its tests
- `Tests/CitizenRadioCoreTests/BoostPairingTests.swift` (one new test)
- `CitizenRadio/TrackInfoModel.swift`

## Do not touch

- `BoostPairing`, its pairing by `value.blockGuid`, and the display decoder `TrackDisplay`. Do not decode `album`.
- The boost, artwork, station and player code.

## Constraints

Core API:

```swift
public struct RelayEvent {
    /// GET /v1/liveitems/{event_id}/metadata
    public var metadataURL: URL { get }
    // remoteValueURL is removed, with its test.
}

public struct LiveValuePayload {
    /// Decodes the body of GET /metadata: reads the "metadata" object and gives it to decode(_:).
    /// Throws DecodeError.invalid when the body is not an object or has no "metadata" object.
    public static func decodeMetadataSnapshot(_ data: Data) throws -> LiveValuePayload?
}

public enum EventStreamUpdate {
    // existing cases stay
    /// A streamed event with an id of the snapshot seq or less (ADR 0018 §The replay on connect).
    case replay(StreamedEvent)
}

public actor EventStreamClient {
    /// replayCount: 0 gives no replay.
    /// continueCodes: the 404 error codes of the snapshot that open the stream with no snapshot.
    public init(snapshotURL: URL, streamURL: URL, eventName: String,
                replayCount: Int = 0, continueCodes: Set<String> = [],
                opener: …, fetcher: …, sleep: … = …)
}
```

Client rules:

- Snapshot `200`: send `.snapshot(body)` as now. Read a top-level whole-number `seq` from the JSON body, if present.
- Snapshot `404`: read the JSON `error` code. A code in `continueCodes` opens the stream with no snapshot and no replay. Each other `404` stops the client, as now. `409` stops the client, as now.
- Open the stream:
  - With a last event ID from the parser, send it, as now. No replay mark.
  - Else, if the snapshot gave `seq` S and `replayCount` is more than 0, send `Last-Event-ID` = max(0, S − replayCount). Each streamed event of the matching name with a whole-number id of S or less is sent as `.replay`. The other events are sent as `.event`, as now.
  - Else send no `Last-Event-ID`, as now.
- The `seq` and the replay mark belong to one attempt. A new attempt reads a new snapshot.

App:

- Value client: `snapshotURL: event.metadataURL`, `replayCount: 8`, `continueCodes: ["metadata_not_found"]`. In `handleValue`, decode a `.snapshot` with `decodeMetadataSnapshot`. Decode `.event` and `.replay` with `decode`, and give both to the boost model, as now.
- Display client: `replayCount: 4`, no `continueCodes`. A `.replay` display state goes only to `sync.receive`. It never goes to the timed apply of ADR 0008, and it never sets the relay track of a session with no ICY. A `.snapshot` and an `.event` work as now.
- `GET /display` has no `seq` on 2026-10-06, so the display replay does not occur yet. Do not add a second request to find it.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100. Comments name ADR 0018.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `RelayEvent.metadataURL` for one event. No test or source refers to `remoteValueURL`.
- `decodeMetadataSnapshot`: a body with a payload gives the payload. A body with `"metadata": {}` gives nil. A body with no `metadata` object throws.
- Client: the snapshot is read from the given URL, and its body is sent as `.snapshot`.
- Client: a `404` snapshot with `{"error":"metadata_not_found"}` and that code in `continueCodes` opens the stream, with no `.snapshot` and no `Last-Event-ID`.
- Client: a `404` snapshot with `{"error":"event_not_found"}` stops the client with the existing stop reason.
- Client: a `404` snapshot with `metadata_not_found` and no `continueCodes` stops the client. This is the display client rule.
- Client: a snapshot with `"seq": 20` and `replayCount` 8 opens the stream with `Last-Event-ID` 12. Events with ids 13 and 20 are `.replay`, and an event with id 21 is `.event`.
- Client: a snapshot with `"seq": 3` and `replayCount` 8 sends `Last-Event-ID` 0.
- Client: a snapshot with no `seq` sends no `Last-Event-ID`, and each event is `.event`.
- Client: a reconnect after an event with id 21 sends `Last-Event-ID` 21, and its events are `.event`.
- Pairing: a relay track with `value.blockGuid` B, and a `/metadata` snapshot body whose payload has the block B: after `decodeMetadataSnapshot` and `receive`, `BoostPairing.payload(for:)` gives that payload.
- `scripts/check.sh` passes.

Manual (by the reviewer): a `.replay` display state goes only to the ICY sync list.

Visual (on an iPhone): the ADR 0018 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- The parser does not give the id of each event, so the replay mark needs a parser change outside this list.
- A change is necessary in a file in "Do not touch".

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-replay-task-001-metadata-snapshot-and-replay.md
- docs/adr/0018-instant-snapshots-and-replay-on-connect.md
- the files listed in "Files to inspect"

Goal:
- Read the value snapshot from GET /metadata, and replay the recent updates on connect.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
