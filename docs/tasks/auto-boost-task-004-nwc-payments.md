# Auto-boost task 004: NWC payments

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 1. Model: Opus.
- Decision: [ADR 0012](../adr/0012-auto-boost.md) §The payment. [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Connection test for the request sequence.
- Depends on: none.

## Goal

`NWCClient` sends a list of `pay_keysend` and `pay_invoice` requests over one relay connection, and gives one outcome for each request.

## Files to inspect

- `CitizenRadio/Core/NWCClient.swift` (the `get_info` sequence)
- `CitizenRadio/Core/NostrEvent.swift`, `RelayMessage.swift`, `RelayConnection.swift`
- `Tests/CitizenRadioCoreTests/NWCClientTests.swift` (the `FakeWallet`)

## Files likely to change

- `CitizenRadio/Core/NWCPayment.swift` (new)
- `CitizenRadio/Core/NWCClient.swift`
- `Tests/CitizenRadioCoreTests/NWCClientTests.swift`

## Do not touch

- All other files. Do not change the behavior or the result of `getInfo()`.

## Constraints

Use exactly this API (`NWCPayment.swift` imports only `Foundation`):

```swift
public struct TLVRecord: Equatable, Sendable {
    public let type: UInt64
    public let value: String        // lowercase hex
    public init(type: UInt64, value: String)
}

public struct KeysendPayment: Equatable, Sendable {
    public let amountMsat: Int64
    public let pubkey: String
    public let tlvRecords: [TLVRecord]
    public init(amountMsat: Int64, pubkey: String, tlvRecords: [TLVRecord])
}

public enum NWCPayment: Equatable, Sendable {
    case keysend(KeysendPayment)
    case invoice(String)
}

public enum NWCPaymentOutcome: Equatable, Sendable {
    case paid
    case unsupported                     // the wallet does not list the method
    case walletError(code: String, message: String)
    case timeout
    case invalidResponse
}

extension NWCClient {
    /// Sends the payments in order over one relay connection. Throws only when the connection
    /// or the info event fails. Each payment gets one outcome, in order.
    public func pay(_ payments: [NWCPayment], requestTimeout: Duration = .seconds(30)) async throws -> [NWCPaymentOutcome]
}
```

Sequence:

1. Connect to `connection.relays[0]`. Read the info event as `getInfo()` does: the methods and the encryption.
2. For each payment, in order:
   - The method is `pay_keysend` or `pay_invoice`. If the info event does not list it, the outcome is `.unsupported`, and no request is sent.
   - Content: `{"method":"pay_keysend","params":{"amount":<msat>,"pubkey":"<hex>","tlv_records":[{"type":<n>,"value":"<hex>"}]}}`. Leave out `tlv_records` when the list is empty. Or `{"method":"pay_invoice","params":{"invoice":"<text>"}}`. Build it with `JSONSerialization`.
   - Sign, encrypt, subscribe and send as in `requestGetInfo`. Use a new subscription for each request, and close it after the response.
   - The response must be a valid event from the wallet key that refers to the request. A `result` object gives `.paid`. An `error` object gives `.walletError`. Bad content gives `.invalidResponse`. No response within `requestTimeout` gives `.timeout`, and the next payment continues.
   - A relay `OK` with `false` for the request gives `.walletError(code: "RELAY_REJECTED", message: <message>)`.
3. Close the connection on all paths.

Other rules:

- Share the info event read and the encryption code with `getInfo()`. Do not copy them.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- No log of the secret, the content, an invoice or a pubkey.
- Comments in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test with the fake wallet:

- Two keysend payments give two `.paid`, and the fake records two requests with the exact decrypted JSON content, including `tlv_records`.
- `pay_invoice` content has the invoice.
- A wallet that does not list `pay_keysend` gives `.unsupported` and receives no request.
- A wallet error response gives `.walletError` with its code and message, and the next payment is still sent.
- A request with no response gives `.timeout` after the request time limit. The test uses a short limit. The next payment is still sent.
- A forged response from a different key is ignored.
- The connection is closed after success, after a timeout and after a connection error.
- The present `getInfo()` tests pass with no change.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter NWCClientTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- `getInfo()` must change its behavior.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-004-nwc-payments.md
- CitizenRadio/Core/NWCClient.swift, CitizenRadio/Core/NostrEvent.swift, CitizenRadio/Core/RelayMessage.swift, CitizenRadio/Core/RelayConnection.swift
- Tests/CitizenRadioCoreTests/NWCClientTests.swift

Goal:
- Add NWCClient.pay(_:requestTimeout:) for pay_keysend and pay_invoice over one connection, with the types in the task file.

Constraints:
- Use the exact API and sequence in the task file. Share code with getInfo(); do not copy it.
- No @unchecked Sendable or nonisolated(unsafe). No log of secrets, content, invoices or keys.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. The present getInfo tests pass unchanged. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
