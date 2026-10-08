# Boost metadata task 001: Record keys and keysend first

- Decision: [ADR 0023](../adr/0023-boost-metadata-for-each-recipient.md). Model: Opus.
- Depends on: none.

## Goal

Add `podcast`, `uuid` and the `auto` action to the boost record. Pay a lightning address part by keysend when the address offers it, with the invoice as the fallback. Send the LUD-18 name.

## Files to inspect

- `docs/adr/0023-boost-metadata-for-each-recipient.md`, `docs/adr/0013-boosts.md` §The payment, `docs/adr/0016-boost-switch-back-play-time-and-retry.md` §The retry
- `CitizenRadio/Core/BoostRecord.swift`, `CitizenRadio/Core/LiveValue.swift`, `CitizenRadio/Core/LightningAddress.swift`
- `CitizenRadio/Core/BoostPayer.swift`, `CitizenRadio/Core/BoostHistory.swift` (`BoostRetryPayment`, `BoostPartResult`, `BoostHistoryText`)
- `CitizenRadio/BoostModel.swift` (`pay`, the retry path), `CitizenRadio/BoostHistoryView.swift` (the part rows)
- The tests of each core file above

## Files likely to change

- The core files above and their tests
- `CitizenRadio/BoostModel.swift`, `CitizenRadio/BoostHistoryView.swift`

## Do not touch

- The trigger, the plan, the pairing, the split, the limits and the settings. The player and relay code.

## Constraints

Core:

- `LiveValuePayload` gets `public let podcastName: String?`, from a non-empty string `podcastName` in the payload.
- `BoostRecord`: the record gets `podcast`, `uuid` and the action. Give the record builder a value with these three inputs, for example:

  ```swift
  public enum BoostAction: String, Codable, Sendable { case boost, auto }
  public struct BoostContext: Equatable, Sendable {
      public let action: BoostAction
      public let uuid: UUID
      /// The station name. `podcast` uses it when the payload has no podcastName.
      public let stationName: String?
  }
  ```

  `podcast` is `payload.podcastName ?? context.stationName`. A key with no value is left out, as now. `uuid` is `uuid.uuidString.lowercased()`.
- `LightningAddress`:
  - `keysendURL(name:host:) -> URL`: `https://host/.well-known/keysend/name`, with the encoding of `wellKnownURL`.
  - `decodeKeysend(_ data: Data) throws -> KeysendTarget`, where `KeysendTarget` has `pubkey` (lowercase) and `records: [TLVRecord]`. It needs `tag` equal to `keysend` and a pubkey of 66 hexadecimal characters. A `status` of `ERROR` throws. A `customData` entry with a `customKey` that is not a decimal number is skipped.
  - `PayRequest` gets `acceptsPayerName: Bool`, true when `payerData.name` is an object.
  - `callbackURL(for:amountMsat:comment:payerName:)` adds `payerdata` with the JSON `{"name":"<name>"}` only when `acceptsPayerName` is true and the name is not empty.
- `BoostPayer`:
  - `pay` gets the `BoostContext`.
  - For a lightning address part: read the keysend URL with the fetcher. With a valid target, the payment is a keysend with the boost record and the target records. Else, the invoice of today, with the payer name.
  - All first payments go in one wallet call, as now. After it, each lightning address part whose keysend gave `.walletError` or `.unsupported` gets an invoice. All these invoices go in a second wallet call.
  - Never send the invoice after `.paid`, `.timeout` or `.invalidResponse`.
- `BoostPartResult` gets `path: BoostPaymentPath?` (`keysend` or `invoice`), an optional key, so an old file decodes. For a node part it is `keysend`.
- `BoostRetryPayment.lightningAddress` also keeps the boost record TLV records and the payer name, as optional keys, so an old file decodes. A retry of such a part does the keysend-first steps again with the same records.
- `BoostHistoryText`: a path text, "Keysend" or "Invoice", for a lightning address part.

App:

- `BoostModel` makes one `BoostContext` for each boost: `.auto` or `.boost`, a new UUID, and `StationStore().selected?.name`.
- `BoostHistoryView` shows "Lightning address, keysend" or "Lightning address, invoice" for a lightning address part, else as now.

Other:

- No log of a message, a name, an invoice, a pubkey or a TLV value. Counts and paths only.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100. Comments name ADR 0023.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- Record: `podcast` from `podcastName`, else from the station name, else no key. One fixed UUID gives the same lowercase `uuid` in two splits. `action` is `auto` and `boost` for the two kinds.
- `decodeKeysend`: the Alby answer of 2026-10-07 gives the pubkey `02babb6a65ccd4c11caac12edbaa77659826c12a9b7fba6bdc00da6dd8b5b5cc01` and one record, type 696969, value hex of "1". A wrong `tag`, a short pubkey, `status: ERROR` and an HTML body throw. A non-decimal `customKey` is skipped.
- `callbackURL`: with `acceptsPayerName` and a name, the query has `payerdata` with the JSON. Without one of the two, it has no `payerdata`.
- Payer, with a fake wallet and a fake fetcher:
  - an address with a keysend answer is paid by keysend, with the record and the `696969` record, and the path is keysend.
  - an address with no keysend answer is paid by invoice, and the path is invoice.
  - a keysend that gives a wallet error is paid by invoice in a second call.
  - a keysend that gives a timeout gets no invoice.
  - a keysend that gives "not supported" is paid by invoice.
- History: an old JSON form with a lightning address part and its retry data decodes, with no path.
- `scripts/check.sh` passes.

Visual: the ADR 0023 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "BoostRecordTests|LightningAddressTests|BoostPayerTests|BoostHistoryTests|LiveValueTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- The old history file cannot decode with the new types.
- A change is necessary in a file in "Do not touch".

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/boost-metadata-task-001-record-and-keysend-first.md
- docs/adr/0023-boost-metadata-for-each-recipient.md
- the files listed in "Files to inspect"

Goal:
- Add podcast, uuid and the auto action to the boost record.
- Pay a lightning address part by keysend when the address offers it, with the invoice as the fallback. Send the LUD-18 name.

Constraints:
- Use the exact rules in the task file. Core files import only Foundation.
- The old history file must still decode.
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
