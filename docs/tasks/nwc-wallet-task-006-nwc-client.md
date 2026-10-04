# NWC wallet task 006: Relay messages and the NWC client

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 2.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Connection test, §Encryption and signatures, §Module boundaries.
- Depends on: tasks 002 and 005.

## Goal

Add the relay message types, the `RelayConnection` protocols and `NWCClient.getInfo()`.
Test the client with a fake wallet on a fake relay.

## Files to inspect

- `CitizenRadio/Core/NWCConnection.swift`
- `CitizenRadio/Core/NostrEvent.swift`, `CitizenRadio/Core/NostrKeys.swift`
- `CitizenRadio/Core/NIP44.swift`, `CitizenRadio/Core/NIP04.swift`
- NIP-01 (relay messages): `https://github.com/nostr-protocol/nips/blob/master/01.md`
- NIP-47: `https://github.com/nostr-protocol/nips/blob/master/47.md`

## Files likely to change

- `CitizenRadio/Core/RelayMessage.swift` (new)
- `CitizenRadio/Core/RelayConnection.swift` (new)
- `CitizenRadio/Core/NWCClient.swift` (new)
- `Tests/CitizenRadioCoreTests/RelayMessageTests.swift` (new)
- `Tests/CitizenRadioCoreTests/NWCClientTests.swift` (new, with the fake wallet)

## Do not touch

- All other files.

## Constraints

Use exactly this API:

```swift
public struct NostrFilter: Codable, Equatable, Sendable {
    public var kinds: [Int]?
    public var authors: [String]?
    public var eventReferences: [String]?   // JSON key "#e"
    public var limit: Int?
    public init(kinds: [Int]? = nil, authors: [String]? = nil, eventReferences: [String]? = nil, limit: Int? = nil)
}

public enum ClientMessage {
    public static func event(_ event: NostrEvent) -> String                         // ["EVENT",<event>]
    public static func request(subscriptionID: String, filter: NostrFilter) -> String  // ["REQ","<id>",<filter>]
    public static func close(subscriptionID: String) -> String                     // ["CLOSE","<id>"]
}

public enum RelayMessage: Equatable, Sendable {
    case event(subscriptionID: String, event: NostrEvent)
    case ok(eventID: String, accepted: Bool, message: String)
    case endOfStoredEvents(subscriptionID: String)
    case notice(String)
    case closed(subscriptionID: String, message: String)
    public init(text: String) throws
}

public protocol RelayConnection: Sendable {
    func send(_ text: String) async throws
    func receive() async throws -> String
    func close() async
}

public protocol RelayConnecting: Sendable {
    func connect(to url: URL) async throws -> any RelayConnection
}

public struct WalletInfo: Equatable, Sendable {
    public let alias: String?
    public let methods: [String]
    public let encryption: String           // "nip44_v2" or "nip04"
    public var supportsKeysend: Bool { methods.contains("pay_keysend") }
}

public actor NWCClient {
    public enum Error: Swift.Error, Equatable {
        case noInfoEvent, unsupportedEncryption, relayRejected(String), walletError(code: String, message: String), invalidResponse, timeout
    }
    public init(connection: NWCConnection, connector: any RelayConnecting, timeout: Duration = .seconds(10))
    public func getInfo() async throws -> WalletInfo
}
```

`getInfo()` sequence (NIP-47 is the authority):

1. Connect to `connection.relays[0]`.
2. Send a `REQ` with the filter: kind 13194, author the wallet key, limit 1. Read messages until `EOSE` for that subscription. Then send `CLOSE`.
   - No info event: throw `.noInfoEvent`.
   - The content is the methods, separated by spaces.
   - An `encryption` tag lists the encryptions, separated by spaces. Without that tag, the wallet supports only `nip04`.
   - Use `nip44_v2` if listed. Else use `nip04` if listed. Else throw `.unsupportedEncryption`.
3. Make the request event: kind 23194, content the encrypted JSON `{"method":"get_info","params":{}}`, tags `[["p", <wallet key>]]`, plus `["encryption","nip44_v2"]` for NIP-44. Sign it with `connection.secret`.
4. Send a `REQ` with the filter: kind 23195, author the wallet key, `#e` the request event ID. Then send the `EVENT`.
5. Read messages:
   - `OK` with `accepted == false` for the request ID: throw `.relayRejected(message)`.
   - An `EVENT` on the response subscription: decrypt the content with the same encryption.
     If it has `error`, throw `.walletError(code:message:)`. Else read `result.alias` and `result.methods`.
     If `result.methods` is missing, use the methods from the info event.
   - Ignore `NOTICE` and messages for other subscriptions.
6. Accept an info event or a response event only if `isValid()` is true and its `pubkey` is the wallet key. Ignore other events. A relay can send forged events.
7. Close the connection on all paths, also after an error.
8. The complete sequence has the time limit `timeout`. After it, throw `.timeout`. Use a task group in which one task sleeps.

Other constraints:

- `NWCClient` imports only `Foundation` and the core types. No Security and no `URLSession`.
- Subscription IDs are random, 16 lowercase hexadecimal characters.
- No secret, plaintext or decrypted content goes into an error, a log or a description.
- Prose and comments in ASD-STE100.

## Implementation steps

1. Write `RelayMessage.swift` (filter, client messages, relay messages) and its tests.
2. Write `RelayConnection.swift` (the two protocols).
3. Write `NWCClient.swift`.
4. In `NWCClientTests.swift`, write a fake wallet. It is a `RelayConnecting` that holds a wallet secret key. It answers `REQ` for kind 13194 with an info event and `EOSE`. It answers the request `EVENT` with `OK` and a signed kind 23195 response. Its behavior is set for each test.
5. Run the test commands.

## Acceptance criteria

Mechanical:

- `RelayMessage` decodes `EVENT`, `OK`, `EOSE`, `NOTICE` and `CLOSED`, and throws for an unknown or malformed message.
- `ClientMessage.request` encodes the `#e` key, and omits filter fields that are `nil`.
- `getInfo()` with a NIP-44 wallet gives the alias and the methods, and `encryption == "nip44_v2"`.
- `getInfo()` with a wallet whose info event has no `encryption` tag uses NIP-04 and succeeds.
- The request event that the fake wallet receives has kind 23194, the wallet `p` tag, and `isValid() == true`.
- A wallet error response throws `.walletError` with the code and message.
- `OK` false throws `.relayRejected`.
- No info event throws `.noInfoEvent`.
- A response with a wrong signature, or from a different public key, is ignored. Without a correct response, `getInfo()` throws `.timeout`.
- A wallet that does not answer throws `.timeout` within the test timeout of 200 milliseconds.
- The fake connection is closed after success and after each error.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "RelayMessageTests|NWCClientTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- NIP-47 in the current specification differs from the sequence above.
- Swift 6 concurrency checks require `@unchecked Sendable` or `nonisolated(unsafe)`. Do not add them without approval.
- A test needs real network access.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-006-nwc-client.md
- CitizenRadio/Core/NWCConnection.swift
- CitizenRadio/Core/NostrEvent.swift
- CitizenRadio/Core/NostrKeys.swift
- CitizenRadio/Core/NIP44.swift
- CitizenRadio/Core/NIP04.swift
- https://github.com/nostr-protocol/nips/blob/master/47.md

Goal:
- Add NostrFilter, ClientMessage, RelayMessage, the RelayConnection protocols and NWCClient.getInfo(), tested with a fake wallet.

Constraints:
- Use the exact API and the getInfo() sequence in the task file.
- NWCClient uses only Foundation and core types. No network access in tests.
- Accept only events with a correct signature from the wallet key.
- Close the connection on all paths. Enforce the timeout with a task group.
- No @unchecked Sendable or nonisolated(unsafe) without approval.
- No secret or decrypted content in errors or logs. Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- All criteria in the task file have a passing test.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "RelayMessageTests|NWCClientTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
