# Auto-boost task 009: Message, names, manual decision and part results

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave B. Model: Opus.
- Decision: [ADR 0013](../adr/0013-boosts.md) §The payment, §Manual boost, §The limits, §The history.
- Depends on: tasks 007 and 008.

## Goal

Put the message, the sender name and the app name into each boost. Add the manual boost decision. Give a result for each part, for the history.

## Files to inspect

- `docs/adr/0013-boosts.md`
- `CitizenRadio/Core/BoostRecord.swift`, `LightningAddress.swift`, `BoostPayer.swift`, `BoostPlan.swift`, `BoostSettings.swift`, `BoostHistory.swift`
- Their tests
- `CitizenRadio/BoostModel.swift` (the one call of `BoostPayer.pay`)

## Files likely to change

- `CitizenRadio/Core/BoostRecord.swift`, `LightningAddress.swift`, `BoostPayer.swift`, `BoostPlan.swift`
- `Tests/CitizenRadioCoreTests/BoostRecordTests.swift`, `LightningAddressTests.swift`, `BoostPayerTests.swift`, `BoostPlanTests.swift`
- `CitizenRadio/BoostModel.swift` (only the call of `BoostPayer.pay`)

## Do not touch

- All other files.

## Constraints

Only `Foundation` in core files. API changes:

```swift
/// The text items of a boost. An empty text is stored as nil.
public struct BoostSender: Equatable, Sendable {
    public let message: String?
    public let senderName: String?
    public let appName: String          // never empty: an empty value gives BoostSettings.defaultAppName
    public init(message: String?, senderName: String?, appName: String)
    /// Reads BoostSettings: the message, the sender name and the app name.
    public init(settings: BoostSettings)
}

// BoostRecord
public static func json(part: BoostPart, payload: LiveValuePayload, totalSats: Int, sender: BoostSender) -> Data
public static func tlvRecords(part: BoostPart, payload: LiveValuePayload, totalSats: Int, sender: BoostSender) -> [TLVRecord]
// Remove BoostRecord.appName.

// LightningAddress
public static func callbackURL(for request: PayRequest, amountMsat: Int64, comment: String) throws -> URL
public static func comment(for sender: BoostSender) -> String   // the message, else "Boost from \(appName)"
// Remove LightningAddress.comment (the constant).

// BoostResult gets the part results, in part order:
public let parts: [BoostPartResult]

// BoostPayer
public func pay(parts: [BoostPart], payload: LiveValuePayload, amountSats: Int, sender: BoostSender) async -> BoostResult

// BoostPlan
/// A manual boost: no enabled check, no paid block check and no daily limit check (ADR 0013 §The limits).
public static func decideManual(amountSats: Int, track: TrackDisplay?, pairing: BoostPairing) -> BoostDecision
```

Rules:

- Boost record: add `message` and `sender_name` when not nil. `app_name` is `sender.appName`. All other keys stay as now.
- LNURL comment: `comment(for:)`, then cut to `commentAllowed` characters in `callbackURL`, as now. `commentAllowed` 0 gives no comment.
- Part results: one `BoostPartResult` for each part, in part order:
  - `name` is the destination name. `kind` is `.keysend` for a node and `.lightningAddress` for a lightning address.
  - A part that failed before the wallet (an LNURL failure) is `.failed`.
  - A sent part maps its outcome with `BoostPaymentResult(_:)`.
  - A throw from `wallet.pay` gives `.failed` for each sent part.
- The counts in `BoostResult` stay as now, and agree with the part results.
- `decideManual` rules, in this order:
  1. No track gives `.skip(.noTrack)`.
  2. No payload gives `.skip(.noPayload)`.
  3. No part gives `.skip(.nothingToPay)`.
  4. Else `.pay`.
- `BoostModel`: change only the call to `pay(parts:payload:amountSats:sender: BoostSender(settings: BoostSettings()))`.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. No log of a message, a name or a title.
- Comments in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- The exact boost record JSON with a message and a sender name, and with neither. The app name comes from the sender.
- `BoostSender`: empty texts give nil, and an empty app name gives "CitizenRadio".
- `comment(for:)` gives the message, or "Boost from MyApp" with no message. A comment of 300 characters is cut to `commentAllowed` 100.
- The payer gives part results in part order for each of these cases:
  - two confirmed keysend parts
  - an LNURL failure
  - outcomes `.paid`, `.timeout` and `.notSent`
  - a throw from the wallet
- The payer sends the message in the keysend record and in the LNURL comment.
- `decideManual`: each rule, and it pays also when the paid block set and the daily limit would stop an auto-boost.
- The present tests pass with the new parameters.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "BoostRecordTests|LightningAddressTests|BoostPayerTests|BoostPlanTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A change outside the listed files is necessary.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-009-message-and-manual.md
- docs/adr/0013-boosts.md
- the files listed in "Files to inspect"

Goal:
- Put the message, sender name and app name into each boost, add the manual boost decision, and give a result for each part.

Constraints:
- Use the exact API and rules in the task file. Only Foundation in core files.
- Tests use fixed values. A test must not repeat the code's calculation.
- No @unchecked Sendable or nonisolated(unsafe). No log of a message, a name or a title.
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
