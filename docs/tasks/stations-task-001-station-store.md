# Stations task 001: Station and station store

- Decision: [ADR 0017](../adr/0017-stations-with-alternate-stream.md) §The station, §The first start after the update and §The fallback. Model: Sonnet.
- Depends on: none.

## Goal

Add the station type, the station store with its first-start rule, and an ICY session reset in `IcySync`. The app does not use them yet. Task 002 connects them.

## Files to inspect

- `docs/adr/0017-stations-with-alternate-stream.md`
- `CitizenRadio/Core/StreamStore.swift`, `CitizenRadio/Core/RelayEventStore.swift`, `CitizenRadio/Core/StreamAddress.swift`, `CitizenRadio/Core/RelayEvent.swift`
- `CitizenRadio/Core/IcySync.swift`, `Tests/CitizenRadioCoreTests/IcySyncTests.swift`
- `CitizenRadio/Core/BoostSettings.swift` (the pattern for a `UserDefaults` store with a test suite name)

## Files likely to change

- `CitizenRadio/Core/Station.swift` (new), `CitizenRadio/Core/StationStore.swift` (new)
- `Tests/CitizenRadioCoreTests/StationTests.swift` (new), `Tests/CitizenRadioCoreTests/StationStoreTests.swift` (new)
- `CitizenRadio/Core/IcySync.swift`, `Tests/CitizenRadioCoreTests/IcySyncTests.swift`

## Do not touch

- All app files. `StreamStore` and `RelayEventStore` stay in this task. Task 002 removes them.
- The boost files. Another task can change them.

## Constraints

Core API (only `Foundation`):

```swift
public struct Station: Codable, Equatable, Sendable, Identifiable {
    public static let maxNameLength = 40
    public let id: UUID
    public let name: String
    public let stream: URL
    public let alternateStream: URL?
    /// The relay event URI text, or nil.
    public let trackInfo: String?

    /// The primary stream, then the alternate stream if there is one.
    public var streams: [URL] { get }
    /// The relay event, or nil.
    public var event: RelayEvent? { get }

    /// Validates the texts. Each text is trimmed.
    /// - name: empty gives the host of the stream. A longer name is cut to maxNameLength.
    /// - streamText: StreamAddress rules.
    /// - alternateStreamText: empty gives nil. Else StreamAddress rules, and not equal to the stream.
    /// - trackInfoText: empty gives nil. Else RelayEvent(uri:) must parse.
    public init(id: UUID = UUID(), name: String, streamText: String,
                alternateStreamText: String, trackInfoText: String) throws
}

public enum StationError: LocalizedError, Equatable {
    case stream(StreamAddress.ValidationError)
    case alternateStream(StreamAddress.ValidationError)
    case sameStreams
    case trackInfo
    case listFull
}

public struct StationStore {
    public static let maximumCount = 20
    /// Runs the first-start rule of ADR 0017 one time.
    public init(defaults: UserDefaults = .standard)
    public var stations: [Station] { get }
    public var selectedID: UUID? { get }
    /// The selected station, or nil.
    public var selected: Station? { get }
    /// Adds the station at the end. Throws StationError.listFull at 20 stations.
    public func add(_ station: Station) throws
    /// Replaces the station with the same id. An unknown id changes nothing.
    public func update(_ station: Station)
    /// Removes the station. If it is the selected station, no station is selected.
    public func delete(id: UUID)
    /// Selects the station. An unknown id changes nothing.
    public func select(id: UUID)
}

public struct IcySync {
    /// ADR 0017 §The fallback: starts a new ICY session. After this call `hasIcy` is false,
    /// there is no ICY text and no selection. The list of display states stays.
    public mutating func resetIcy()
}
```

Rules:

- Keys: `citizenRadio.stations` (JSON array) and `citizenRadio.selectedStationID`. The old keys are `citizenRadio.streamURL` and `citizenRadio.relayEventURI`.
- First start: this rule applies when the `citizenRadio.stations` key is missing, and the old stream URL makes a valid `StreamAddress`.
  - Make one station with an empty name and that stream. It has no alternate stream. Its **Track info** is the old relay text. If the old relay text does not parse, use no **Track info**. Save the list, select the station, and remove the two old keys. If the old stream URL is missing or not valid, save an empty list and remove the old keys.
- A stored list that does not decode gives an empty list.
- Each `StationError` has a short `errorDescription`, for example "Enter a complete HTTP or HTTPS stream URL." for `.stream(.invalidURL)`, and "The alternate stream must be different from the stream." for `.sameStreams`.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100. Comments name ADR 0017.

## Acceptance criteria

Mechanical. Each item is a test with fixed values. Store tests use a `UserDefaults` suite with a unique name.

- `Station`:
  - An empty name gives the host. A name of 41 characters keeps 40.
  - An empty alternate gives nil. An alternate equal to the stream throws `.sameStreams`.
  - A bad stream throws `.stream(.invalidURL)`. A bad Track info throws `.trackInfo`.
  - `streams` gives one URL. With an alternate, it gives the stream, then the alternate.
- `StationStore`:
  - First start with an old stream URL and an old relay text gives one selected station with both, and the old keys are gone.
  - First start with an old stream URL and a bad relay text gives one station with no Track info.
  - First start with no old keys gives an empty list and no selection.
  - A second init does not run the first-start rule again.
  - `add` of a 21st station throws `.listFull`.
  - `delete` of the selected station clears the selection. `delete` of another station keeps it.
  - `update` replaces by id and keeps the position.
  - `select` of an unknown id changes nothing.
- `IcySync.resetIcy`: after a matched selection, `resetIcy` gives `hasIcy` false and no relay track. The next ICY text that matches a kept state selects that state.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "StationTests|StationStoreTests|IcySyncTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- `IcySync` keeps the ICY state in a form that `resetIcy` cannot clear with no change to the selection rules.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/stations-task-001-station-store.md
- docs/adr/0017-stations-with-alternate-stream.md
- the files listed in "Files to inspect"

Goal:
- Add Station, StationStore with its first-start rule, and IcySync.resetIcy.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

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
