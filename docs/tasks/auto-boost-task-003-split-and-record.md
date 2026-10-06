# Auto-boost task 003: Split, boost record, plan, BOLT11 and LNURL rules

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 2. Model: Opus.
- Decision: [ADR 0012](../adr/0012-auto-boost.md) §The split, §The payment, §The limits.
- Depends on: task 001 (`LiveValueDestination`, `LiveValuePayload`, `BoostPairing`) and task 004 (`TLVRecord`).

## Goal

Add the pure rules of a boost. These are the split, the boost record and the boost decision. They also include the BOLT11 amount and the LNURL-pay checks.

## Files to inspect

- `docs/adr/0012-auto-boost.md`
- `CitizenRadio/Core/LiveValue.swift`, `CitizenRadio/Core/BoostPairing.swift` (task 001)
- `CitizenRadio/Core/NWCPayment.swift` (task 004, `TLVRecord`)
- `CitizenRadio/Core/SpendingLimit.swift`, `CitizenRadio/Core/TrackDisplay.swift`

## Files likely to change

- `CitizenRadio/Core/BoostSplit.swift`, `BoostRecord.swift`, `BoostPlan.swift`, `Bolt11.swift`, `LightningAddress.swift` (new)
- `Tests/CitizenRadioCoreTests/BoostSplitTests.swift`, `BoostRecordTests.swift`, `BoostPlanTests.swift`, `Bolt11Tests.swift`, `LightningAddressTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Each file imports only `Foundation`. Use exactly this API:

```swift
public struct BoostPart: Equatable, Sendable {
    public let destination: LiveValueDestination
    public let sats: Int
}

public enum BoostSplit {
    public static func parts(amountSats: Int, destinations: [LiveValueDestination]) -> [BoostPart]
}

public enum BoostRecord {
    public static let recordType: UInt64 = 7_629_169
    public static let appName = "CitizenRadio"
    /// The boost record JSON, with sorted keys, in UTF-8.
    public static func json(part: BoostPart, payload: LiveValuePayload, totalSats: Int) -> Data
    /// The boost record, then the custom record if the destination has one.
    public static func tlvRecords(part: BoostPart, payload: LiveValuePayload, totalSats: Int) -> [TLVRecord]
}

public enum BoostSkipReason: Equatable, Sendable {
    case disabled, noTrack, noPayload, alreadyPaid, overDailyLimit(remainingSats: Int), nothingToPay
}

public enum BoostDecision: Equatable, Sendable {
    case pay(payload: LiveValuePayload, parts: [BoostPart])
    case skip(BoostSkipReason)
}

public enum BoostPlan {
    public static func decide(
        enabled: Bool, amountSats: Int, track: TrackDisplay?, pairing: BoostPairing,
        paidBlocks: Set<String>, limit: SpendingLimit, day: String
    ) -> BoostDecision
}

public enum Bolt11 {
    /// The invoice amount in millisats, or nil for no amount or an invalid amount.
    public static func amountMsat(_ invoice: String) -> Int64?
}

public enum LightningAddress {
    public struct PayRequest: Equatable, Sendable {
        public let callback: URL
        public let minSendable: Int64
        public let maxSendable: Int64
        public let commentAllowed: Int
    }
    public enum Failure: Error, Equatable {
        case invalidResponse, notPayRequest, insecureCallback, amountOutOfRange, invoiceAmountMismatch
        case serviceError(String)
    }
    public static let comment = "Boost from CitizenRadio"
    public static func wellKnownURL(name: String, host: String) -> URL
    public static func decodePayRequest(_ data: Data) throws -> PayRequest
    public static func callbackURL(for request: PayRequest, amountMsat: Int64) throws -> URL
    public static func decodeInvoice(_ data: Data, amountMsat: Int64) throws -> String
}
```

Split rules (ADR 0012 §The split). Calculate in millisats with `Int64`:

1. `total = amountSats * 1000`.
2. Each `fee` destination: `part = floor(total * split / 100)`. If the sum of the fee parts is more than `total`, give no parts.
3. `rest = total - sum of fee parts`. Each other destination: `part = floor(rest * split / sum of the non-fee splits)`.
4. `sats = part / 1000`, rounded down. A part with 0 sats is left out.
5. Keep the destination order.

Boost record keys (ADR 0012 §The payment), with `JSONSerialization` and `.sortedKeys`:

- Always: `action` = `"boost"`, `app_name` = `"CitizenRadio"`, `value_msat_total` = `totalSats * 1000`, `value_msat` = `part.sats * 1000`, `episode` = payload title, `event_guid`, `block_guid`.
- Only when present: `name` (destination name), `guid` (`feedGuid`), `episode_guid` (`itemGuid`).
- `TLVRecord.value` is the lowercase hex of the bytes.
- The custom record: only for a destination with both `customKey` and `customValue`, and a `customKey` that parses as `UInt64`. Its value is the hex of the UTF-8 bytes of `customValue`.

Decision rules, in this order:

1. Not enabled: `.skip(.disabled)`.
2. No track: `.skip(.noTrack)`.
3. `pairing.payload(for: track)` is nil: `.skip(.noPayload)`.
4. The payload `blockGuid` is in `paidBlocks`: `.skip(.alreadyPaid)`.
5. `limit.permits(amountSats, on: day)` is false: `.skip(.overDailyLimit(remainingSats: limit.remaining(on: day)))`.
6. `BoostSplit.parts` is empty: `.skip(.nothingToPay)`.
7. Else `.pay(payload:parts:)`.

BOLT11 amount rules:

- Lowercase the text. It must start with `ln`. The human-readable part ends at the last `1`.
- After `ln`, the network is `bcrt`, `bc`, `tbs`, `tb` or `sb`. Test the longer names first.
- The rest is the amount: digits with no leading zero, then an optional multiplier `m`, `u`, `n` or `p`. No digits: nil.
- Millisats: no multiplier × 100,000,000,000; `m` × 100,000,000; `u` × 100,000; `n` × 100; `p` ÷ 10, and a `p` amount that is not a multiple of 10 gives nil. An overflow gives nil.

LNURL rules (LUD-06, LUD-12, LUD-16):

- `wellKnownURL` is `https://{host}/.well-known/lnurlp/{name}`.
- `decodePayRequest`:
  - A JSON object with `"status": "ERROR"` throws `serviceError(reason)`.
  - `tag` must be `"payRequest"`, else `notPayRequest`.
  - `callback` must be an `https` URL with a host, else `insecureCallback`.
  - `minSendable` and `maxSendable` are positive integers with min ≤ max. A missing `commentAllowed` is 0.
  - Anything else throws `invalidResponse`.
- `callbackURL`: an amount outside min to max throws `amountOutOfRange`. Add `amount` to the present query items. If `commentAllowed` > 0, add `comment` with `LightningAddress.comment` cut to `commentAllowed` characters.
- `decodeInvoice`: `"status": "ERROR"` throws `serviceError(reason)`. `pr` must be a string, else `invalidResponse`. `Bolt11.amountMsat(pr)` must equal `amountMsat`, else `invoiceAmountMismatch`.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- Split: 100 sats, A share 90, B share 10, fee C 5 %, gives C 5, A 85, B 9. Fixed expected numbers, not a formula in the test.
- Split: a part under 1 sat is left out. Fee splits over 100 % give no parts. The sum is never more than the amount.
- Boost record: the exact JSON text for a fixed part and payload, with and without the optional keys. The TLV hex of a known short JSON. The custom record for `customKey` `"696969"` and `customValue` `"abc"` is type 696969 with value `"616263"`. A `customKey` `"x"` gives no custom record.
- Decision: one test for each rule, and the rule order.
- BOLT11: `lnbc2500u1…` gives 250,000,000; `lnbc20m1…` gives 2,000,000,000; `lnbc1p…` (no amount digits) gives nil; `lntb10n1…` gives 1,000; `lnbc15p1…` gives nil; `lnbc10p1…` gives 1; an invalid prefix gives nil.
- LNURL: each rule of `decodePayRequest`, `callbackURL` and `decodeInvoice`, with fixed JSON literals.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "BoostSplitTests|BoostRecordTests|BoostPlanTests|Bolt11Tests|LightningAddressTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A rule in this packet disagrees with LUD-06, LUD-16 or BOLT11 as you know them. Report it, do not change the rule.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-003-split-and-record.md
- docs/adr/0012-auto-boost.md
- CitizenRadio/Core/LiveValue.swift, CitizenRadio/Core/BoostPairing.swift, CitizenRadio/Core/NWCPayment.swift
- CitizenRadio/Core/SpendingLimit.swift, CitizenRadio/Core/TrackDisplay.swift

Goal:
- Add BoostSplit, BoostRecord, BoostPlan, Bolt11 and LightningAddress with the exact API and rules in the task file.

Constraints:
- Only Foundation. No network, no time, no logging.
- Tests use fixed literals and fixed expected values. A test must not repeat the code's calculation.
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
