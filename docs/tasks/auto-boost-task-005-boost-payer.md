# Auto-boost task 005: Boost payer and status text

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 3. Model: Opus.
- Decision: [ADR 0012](../adr/0012-auto-boost.md) §The payment, §The limits, §Threading and secrets.
- Depends on: tasks 001, 003 and 004.

## Goal

Add `BoostPayer` to `CitizenRadioCore`. It gets an invoice for each lightning address part, sends all parts through the wallet, and records the paid sats. Add `BoostStatusText` for the Settings result line.

## Files to inspect

- `docs/adr/0012-auto-boost.md`
- `CitizenRadio/Core/BoostSplit.swift`, `BoostRecord.swift`, `BoostPlan.swift`, `LightningAddress.swift`, `LiveValue.swift`
- `CitizenRadio/Core/NWCPayment.swift`, `NWCClient.swift`
- `CitizenRadio/Core/EventStreamClient.swift` (`SnapshotFetching`), `CitizenRadio/Core/WalletStatusText.swift` (the pattern for user texts)

## Files likely to change

- `CitizenRadio/Core/BoostPayer.swift` (new)
- `CitizenRadio/Core/BoostStatusText.swift` (new)
- `Tests/CitizenRadioCoreTests/BoostPayerTests.swift`, `BoostStatusTextTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Use exactly this API (only `Foundation`):

```swift
public protocol WalletPaying: Sendable {
    func pay(_ payments: [NWCPayment]) async throws -> [NWCPaymentOutcome]
}
// NWCClient conforms. Its pay uses the default requestTimeout.

public struct BoostResult: Equatable, Sendable {
    public let paidSats: Int        // parts with outcome .paid
    public let unknownSats: Int     // parts with outcome .timeout: the wallet can have paid them
    public let paidParts: Int
    public let unknownParts: Int
    public let totalParts: Int
}

public actor BoostPayer {
    public init(wallet: any WalletPaying, fetcher: any SnapshotFetching)
    /// Never throws. A failed part counts as not paid.
    public func pay(parts: [BoostPart], payload: LiveValuePayload, amountSats: Int) async -> BoostResult
}

public enum BoostStatusText {
    public static func text(for result: BoostResult) -> String
    public static func text(for reason: BoostSkipReason) -> String?
    public static let noWallet: String
}
```

Payer sequence:

1. For each lightning address part, in order:
   - `fetcher.fetch(LightningAddress.wellKnownURL(name:host:))`. Status 200, else the part fails.
   - `LightningAddress.decodePayRequest`, then `callbackURL(for:amountMsat:)` with `sats * 1000`, then `fetcher.fetch` of that URL with status 200, then `decodeInvoice(_:amountMsat:)`.
   - Any throw or other status fails the part. No retry.
2. Build the payments in part order, without the failed parts:
   - Node part: `.keysend(KeysendPayment(amountMsat: sats * 1000, pubkey:, tlvRecords: BoostRecord.tlvRecords(part:payload:totalSats: amountSats)))`.
   - Lightning address part: `.invoice(pr)`.
3. If no payment is left, give the result with 0 paid. Else call `wallet.pay` one time with all payments. If it throws, no part is paid.
4. `paidSats` is the sum of the parts with outcome `.paid`. `unknownSats` is the sum of the parts with outcome `.timeout`. `totalParts` is the count of all parts. Each other outcome, also `.notSent`, is a failed part.

The payer does not record the spending. The caller records `paidSats + unknownSats` in `SpendingLimitStore` (ADR 0012 §The limits).

Status texts (ASD-STE100, short):

| Input | Text |
|---|---|
| all parts paid | "Boosted \(paidSats) sats." |
| some parts paid | "Boosted \(paidSats) sats. \(failed) of \(totalParts) payments failed." |
| any part with an unknown result | the text above, then " The result of \(unknownParts) payments is not known." With no paid part, leave out "Boosted 0 sats." |
| no part paid | "The boost failed. No payment was sent." |
| `.overDailyLimit(remainingSats:)` | "No boost. Only \(remainingSats) sats of the daily limit remain." |
| `.nothingToPay` | "No boost. The track has no payment destination." |
| `.disabled`, `.noTrack`, `.noPayload`, `.alreadyPaid` | nil (no message) |
| `noWallet` | "No boost. Connect a wallet." |

## Acceptance criteria

Mechanical. Each item is a test with a fake wallet and a fake fetcher:

- Two node parts give one `wallet.pay` call with two keysend payments: the exact amounts, pubkeys and TLV records.
- A lightning address part fetches the well-known URL, then the callback with the amount, and pays the returned invoice. A fixed BOLT11 test invoice for the right amount is in the test.
- An invoice for a different amount is not paid. The other parts are paid.
- A well-known fetch with status 404 fails only that part.
- Outcomes `.paid`, `.walletError` and `.paid` give `paidParts` 2 and the sum of the two paid parts.
- Outcomes `.paid`, `.timeout` and `.notSent` give `paidParts` 1, `unknownParts` 1, and the sats of the second part in `unknownSats`.
- A throw from `wallet.pay` gives 0 paid.
- No payment left gives no `wallet.pay` call.
- Each status text row is a test.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "BoostPayerTests|BoostStatusTextTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A type of tasks 001, 003 or 004 needs a change.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-005-boost-payer.md
- docs/adr/0012-auto-boost.md
- the files listed in "Files to inspect"

Goal:
- Add WalletPaying, BoostResult, BoostPayer and BoostStatusText with the exact API, sequence and texts in the task file.

Constraints:
- Only Foundation. No real network and no real time in the tests.
- No @unchecked Sendable or nonisolated(unsafe). No log of invoices, keys or titles.
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
