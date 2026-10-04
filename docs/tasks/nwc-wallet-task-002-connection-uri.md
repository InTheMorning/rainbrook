# NWC wallet task 002: Connection URI parser and wallet summary

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 1.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Validation, §Settings, §Invariants.
- Depends on: task 001.

## Goal

Add `NWCConnection`, which parses and validates a `nostr+walletconnect` URI.
Add `WalletSummary`, which holds the values that the settings sheet can show.

## Files to inspect

- `CitizenRadio/Core/StreamAddress.swift` (an example of validation with a `LocalizedError`)
- `Tests/CitizenRadioCoreTests/StreamAddressTests.swift`

## Files likely to change

- `CitizenRadio/Core/NWCConnection.swift` (new)
- `CitizenRadio/Core/WalletSummary.swift` (new)
- `Tests/CitizenRadioCoreTests/NWCConnectionTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Use exactly this API:

```swift
public struct NWCConnection: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public enum ParseError: Error, Equatable, LocalizedError {
        case scheme, publicKey, relay, secret
        public var errorDescription: String? { get }
    }

    public let walletPublicKey: String  // 64 lowercase hexadecimal characters
    public let relays: [URL]            // one or more, each with the scheme "wss"
    public let secret: String           // 64 lowercase hexadecimal characters, not all zero
    public let lud16: String?

    public init(uri: String) throws     // throws ParseError
    public var uri: String { get }      // the canonical URI for storage
    public var description: String { get }       // no secret
    public var debugDescription: String { get }  // no secret
    public var customMirror: Mirror { get }      // no secret
}

public struct WalletSummary: Equatable, Sendable {
    public let relayHost: String        // host of the first relay
    public let walletKeyPrefix: String  // first 8 characters of walletPublicKey
    public let lud16: String?
    public init(_ connection: NWCConnection)
}
```

Parser rules:

- Remove whitespace and newlines at the two ends of the input.
- The scheme is `nostr+walletconnect`. Compare it without case. Other schemes throw `.scheme`.
- The host is the wallet public key: 64 hexadecimal characters. Store it in lowercase. Else throw `.publicKey`.
- Read all `relay` query items, in sequence. `URLComponents` removes the percent encoding. Each relay must be a URL with the scheme `wss` and a host. No relay, or one relay that is not correct, throws `.relay`.
- The `secret` query item is 64 hexadecimal characters and not all zero. Store it in lowercase. Else throw `.secret`.
- `lud16` is optional. An empty value is `nil`.
- `uri` gives `nostr+walletconnect://<key>?relay=<percent-encoded relay>&...&secret=<secret>` and `&lud16=<value>` if present. `NWCConnection(uri: connection.uri)` must give an equal value.
- Error texts (`errorDescription`), exactly:
  - `.scheme`: "This is not a Nostr Wallet Connect link."
  - `.publicKey`: "The wallet key in the link is not correct."
  - `.relay`: "The link must contain a secure relay address (wss)."
  - `.secret`: "The secret in the link is not correct."
- `description`, `debugDescription` and `customMirror` show the wallet key prefix and the relay hosts, and never the secret.

Other constraints:

- No `import` other than `Foundation`.
- No logging.
- Prose and comments in ASD-STE100. Write a small number of comments, as in the other core files.

## Implementation steps

1. Write `NWCConnection.swift` with the API and rules.
2. Write `WalletSummary.swift`.
3. Write the tests for each acceptance criterion.
4. Run the test commands.

## Acceptance criteria

Mechanical (each one is a test in `NWCConnectionTests.swift`):

- A valid URI with one relay parses, and the values are lowercase.
- A valid URI with two relays keeps the two relays in sequence.
- A percent-encoded relay (`wss%3A%2F%2Frelay.example.com`) parses.
- These throw the named error: a wrong scheme (`.scheme`), a 63-character key (`.publicKey`), no relay (`.relay`), a `ws://` relay (`.relay`), no secret (`.secret`), a secret of 64 zeros (`.secret`).
- `NWCConnection(uri: connection.uri) == connection`.
- `String(describing:)`, `String(reflecting:)` and the `dump` output do not contain the secret.
- No `errorDescription` contains the input URI.
- `WalletSummary` gives the first relay host, the first 8 key characters and `lud16`.

## Test commands

```sh
swift test --build-system native --filter NWCConnectionTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- `URLComponents` does not parse the `nostr+walletconnect` scheme or the host as the rules require.
- The API needs a change to pass a test.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-002-connection-uri.md
- CitizenRadio/Core/StreamAddress.swift
- Tests/CitizenRadioCoreTests/StreamAddressTests.swift

Goal:
- Add NWCConnection and WalletSummary in CitizenRadioCore, with tests.

Constraints:
- Use the exact API, parser rules and error texts in the task file.
- The secret must not appear in description, debugDescription, customMirror or any error text.
- Only Foundation. No logging. Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- All criteria in the task file have a passing test in NWCConnectionTests.swift.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter NWCConnectionTests
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
