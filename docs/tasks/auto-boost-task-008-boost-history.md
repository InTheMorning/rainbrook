# Auto-boost task 008: Boost history core

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave A. Model: Sonnet.
- Decision: [ADR 0013](../adr/0013-boosts.md) §The history.
- Depends on: tasks 001 to 006.

## Goal

Add the boost history types, the 200-entry list, a file store, and the summary text of an entry.

## Files to inspect

- `docs/adr/0013-boosts.md` §The history
- `CitizenRadio/Core/NWCPayment.swift` (`NWCPaymentOutcome`)
- `CitizenRadio/Core/BoostStatusText.swift` (the style of user texts)

## Files likely to change

- `CitizenRadio/Core/BoostHistory.swift` (new)
- `Tests/CitizenRadioCoreTests/BoostHistoryTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Only `Foundation`. Use exactly this API:

```swift
public enum BoostPaymentResult: String, Codable, Equatable, Sendable {
    case confirmed, failed, unknown
    /// .paid gives confirmed, .timeout gives unknown, each other outcome gives failed.
    public init(_ outcome: NWCPaymentOutcome)
}

public struct BoostPartResult: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case keysend, lightningAddress }
    public let name: String?
    public let kind: Kind
    public let sats: Int
    public let result: BoostPaymentResult
    public init(name: String?, kind: Kind, sats: Int, result: BoostPaymentResult)
}

public struct BoostHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case auto, manual }
    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let title: String
    public let artist: String?
    public let amountSats: Int
    public let message: String?
    public let parts: [BoostPartResult]
    public init(id: UUID = UUID(), date: Date, kind: Kind, title: String, artist: String?,
                amountSats: Int, message: String?, parts: [BoostPartResult])
    public var confirmedSats: Int { get }   // sum of confirmed parts
}

public struct BoostHistory: Equatable, Sendable {
    public static let capacity = 200
    public private(set) var entries: [BoostHistoryEntry]   // newest first
    public init(entries: [BoostHistoryEntry] = [])          // keeps the first 200
    public mutating func add(_ entry: BoostHistoryEntry)    // inserts first, then keeps 200
    public func encoded() throws -> Data                    // JSON, ISO 8601 dates
    public static func decode(_ data: Data) throws -> BoostHistory
}

public protocol BoostHistoryStoring: Sendable {
    func load() async -> BoostHistory          // a missing or bad file gives an empty history
    func add(_ entry: BoostHistoryEntry) async -> BoostHistory
}

public actor BoostHistoryFileStore: BoostHistoryStoring {
    public init(fileURL: URL)
}

public enum BoostHistoryText {
    /// For example "Confirmed 99 of 100 sats." or "Failed. No payment was confirmed."
    public static func summary(for entry: BoostHistoryEntry) -> String
    /// "Confirmed", "Failed" or "Unknown".
    public static func label(for result: BoostPaymentResult) -> String
}
```

Rules:

- `BoostHistoryFileStore.add` loads the file, adds the entry, writes the file atomically (`.atomic`), and gives the new history. It creates the folder of the file if it is missing.
- A write error is ignored, so a history problem never stops a payment. The store gives the history in memory.
- Summary texts:
  - A minimum of one confirmed part: "Confirmed \(confirmedSats) of \(amountSats) sats." Then, if any part is unknown: " \(n) unknown." Then, if any part failed: " \(n) failed."
  - No confirmed part, some unknown: "Not known. \(n) payments have no result." Then " \(m) failed." if any failed.
  - No part, or all failed: "Failed. No payment was confirmed."
- No log.
- Comments and texts in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `BoostPaymentResult(outcome)` for each of the six outcomes.
- `add` puts the newest entry first. After 201 entries, the history has 200, and the first entry added is gone.
- `encoded()` then `decode` gives an equal history, with dates and part results.
- The file store, in a temporary folder:
  - `load` of a missing file is empty.
  - After `add`, a new store on the same file loads the entry.
  - A file with bad JSON loads as empty.
- Each summary text case, with fixed entries.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter BoostHistoryTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-008-boost-history.md
- docs/adr/0013-boosts.md §The history
- CitizenRadio/Core/NWCPayment.swift, CitizenRadio/Core/BoostStatusText.swift

Goal:
- Add BoostPaymentResult, BoostPartResult, BoostHistoryEntry, BoostHistory, BoostHistoryStoring, BoostHistoryFileStore and BoostHistoryText with the exact API and rules in the task file.

Constraints:
- Only Foundation. No log. No @unchecked Sendable or nonisolated(unsafe).
- Tests use fixed values and a temporary folder.
- Comments and texts in ASD-STE100.
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
