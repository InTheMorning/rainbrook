# Auto-boost task 013: Failure reason and retry core

- Decision: [ADR 0016](../adr/0016-boost-switch-back-play-time-and-retry.md) §The failure reason and §The retry. Model: Opus.
- Depends on: task 010. Task 012 can run at the same time, because it changes different files.

## Goal

Each part result keeps its failure reason, its attempt count and, for a retryable part, the payment data. `BoostPayer` can send the retryable parts of an entry again. The history can update an entry in place.

## Files to inspect

- `docs/adr/0016-boost-switch-back-play-time-and-retry.md`, `docs/adr/0013-boosts.md` §The payment and §The history
- `CitizenRadio/Core/BoostHistory.swift`, `Tests/CitizenRadioCoreTests/BoostHistoryTests.swift`
- `CitizenRadio/Core/BoostPayer.swift`, `Tests/CitizenRadioCoreTests/BoostPayerTests.swift`
- `CitizenRadio/Core/NWCPayment.swift` (`TLVRecord`, `KeysendPayment`, `NWCPaymentOutcome`)
- `CitizenRadio/BoostModel.swift` (the only user of `BoostHistoryStoring`)

## Files likely to change

- `CitizenRadio/Core/BoostHistory.swift`, `CitizenRadio/Core/BoostPayer.swift`, `CitizenRadio/Core/NWCPayment.swift` (only `Codable` on `TLVRecord`)
- `Tests/CitizenRadioCoreTests/BoostHistoryTests.swift`, `Tests/CitizenRadioCoreTests/BoostPayerTests.swift`

## Do not touch

- `BoostTrigger.swift`, `BoostPlan.swift`, `BoostStatusText.swift`, `BoostSettings.swift`, `BoostModel.swift`, `TrackInfoModel.swift` and the views. Task 012 and task 014 change them.

## Constraints

Core API:

```swift
/// ADR 0016 §The failure reason.
public enum BoostFailure: Codable, Equatable, Sendable {
    case walletError(code: String, message: String)   // message: a maximum of 200 characters
    case unsupported, invalidResponse, notSent, lightningAddress
    /// True for walletError, notSent and lightningAddress.
    public var isRetryable: Bool { get }
    /// Nil for .paid and .timeout.
    public init?(_ outcome: NWCPaymentOutcome)
}

/// The data to send one part again. ADR 0016 §The retry.
public enum BoostRetryPayment: Codable, Equatable, Sendable {
    case keysend(pubkey: String, amountMsat: Int64, tlvRecords: [TLVRecord])
    case lightningAddress(name: String, host: String, amountMsat: Int64, comment: String)
}

public struct BoostPartResult {
    // existing: name, kind, sats, result
    public let failure: BoostFailure?        // nil unless result is .failed
    public let retry: BoostRetryPayment?     // non-nil only when failure?.isRetryable == true
    public let attempts: Int                 // 1 after the first payment
    public var isRetryable: Bool { get }     // result == .failed && retry != nil
    // The existing initializer stays, with default values nil, nil, 1.
}

public struct BoostHistoryEntry {
    public var hasRetryableParts: Bool { get }
    /// The sum of the sats of the retryable parts.
    public var retryableSats: Int { get }
    /// The same entry (id, date, kind, title, artist, amount, message) with new parts.
    public func replacingParts(_ parts: [BoostPartResult]) -> BoostHistoryEntry
}

public struct BoostHistory {
    /// Replaces the entry with the same id, at the same position. No entry with that id: no change.
    public mutating func update(_ entry: BoostHistoryEntry)
}

public protocol BoostHistoryStoring: Sendable {
    // existing load() and add(_:)
    func update(_ entry: BoostHistoryEntry) async -> BoostHistory
}

public actor BoostPayer {
    // existing pay(parts:payload:amountSats:sender:) now fills failure, retry and attempts.
    /// Sends each retryable part again, in one wallet call. Other parts stay unchanged.
    /// Gives the full list in the same sequence. A retried part has attempts + 1.
    public func retry(parts: [BoostPartResult]) async -> [BoostPartResult]
}
```

Rules:

- `TLVRecord` gets `Codable`.
- Decoding of the stored history must accept the old file: `failure`, `retry` and `attempts` are optional keys. A missing `attempts` gives 1. Add a test with the old JSON form.
- `pay`: a keysend part keeps `.keysend` with its pubkey, amount and the same TLV records that it sent. A lightning address part keeps `.lightningAddress` with the name, the host, the amount and the comment. Keep the data only on a part with a retryable failure. An LNURL failure gives `.lightningAddress` as the failure. A wallet throw gives `.notSent` for each part.
- `retry`: a keysend part sends `KeysendPayment` from the stored data. A lightning address part gets a new invoice with the stored comment and the same checks as `pay`. A part with the result unknown or confirmed is never sent. A failed part with no retry data is never sent.
- `BoostHistoryText`: add `reason(for part: BoostPartResult) -> String?`:
  - walletError: "Wallet error \(code): \(message)"
  - unsupported: "The wallet does not support this payment."
  - invalidResponse: "The wallet answer was not valid."
  - notSent: "The payment was not sent."
  - lightningAddress: "The lightning address request failed."
  - nil when there is no failure.
- `BoostHistoryFileStore.update` loads, updates and writes, as `add` does. The only other store is in `BoostModel`, which uses the file store. Do not change `BoostModel`.
- No log of a message, a title, an invoice or a TLV value.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `BoostFailure(outcome)` for each outcome, and `isRetryable` for each case. A message of 250 characters keeps 200.
- `pay` with a fake wallet:
  - a keysend part with a wallet error keeps the reason, the retry data with the same TLV records, and attempts 1.
  - an unsupported part has no retry data.
  - a timeout part has no failure and no retry data.
  - an LNURL failure keeps `.lightningAddress` and the retry data with the comment.
- `retry` with a fake wallet:
  - two parts, one confirmed and one retryable: only the retryable part is sent, and the confirmed part stays the same.
  - a retried part that is paid becomes confirmed, with attempts 2 and no failure and no retry data.
  - an unknown part is never sent.
  - a lightning address part fetches a new invoice.
- History: `update` replaces an entry at its position and keeps the other entries. `update` with an unknown id changes nothing. The old JSON form decodes with attempts 1.
- `reason(for:)` gives each text above.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "BoostHistoryTests|BoostPayerTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- The old history file cannot decode with the new types.
- `BoostModel` must change to compile. Report the smallest change, and do not make others.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-013-retry-core.md
- docs/adr/0016-boost-switch-back-play-time-and-retry.md
- the files listed in "Files to inspect"

Goal:
- Each part result keeps its failure reason, its attempt count and, for a retryable part, the payment data.
- BoostPayer can send the retryable parts again, and the history can update an entry in place.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- The old history file must still decode.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch", and any file that is not in "Files likely to change".

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
