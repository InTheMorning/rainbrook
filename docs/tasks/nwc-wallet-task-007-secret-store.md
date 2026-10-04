# NWC wallet task 007: Secret store and Keychain

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 3.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Storage, §Module boundaries, §Invariants. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for blocking calls.
- Depends on: task 002.

## Goal

Add the `SecretStore` protocol and `WalletStore` in the core, and `KeychainSecretStore` in the app target.

## Files to inspect

- `CitizenRadio/Core/NWCConnection.swift`
- `CitizenRadio/RadioPlayer.swift` (`sessionQueue` and `activateSession(on:)`, the pattern for a blocking call on a queue)
- `Tests/CitizenRadioCoreTests/AudioSessionThreadTests.swift` (the pattern for a source guard test)

## Files likely to change

- `CitizenRadio/Core/SecretStore.swift` (new)
- `CitizenRadio/KeychainSecretStore.swift` (new, iOS only)
- `Tests/CitizenRadioCoreTests/WalletStoreTests.swift` (new)
- `Tests/CitizenRadioCoreTests/KeychainThreadTests.swift` (new)

## Do not touch

- All other files. The Xcode project file changes in task 011.

## Constraints

Use exactly this API:

```swift
// CitizenRadio/Core/SecretStore.swift
public protocol SecretStore: Sendable {
    func read() async throws -> String?
    func write(_ value: String) async throws
    func delete() async throws
}

public struct WalletStore: Sendable {
    public init(secrets: any SecretStore)
    public func connection() async throws -> NWCConnection?   // nil if nothing is stored
    public func save(_ connection: NWCConnection) async throws  // stores connection.uri
    public func remove() async throws
}

// CitizenRadio/KeychainSecretStore.swift
#if os(iOS)
final class KeychainSecretStore: SecretStore {
    init(service: String = "org.citizenradio.CitizenRadio.nwc", account: String = "default")
}
#endif
```

Keychain rules:

- `kSecClassGenericPassword` with `kSecAttrService` and `kSecAttrAccount`.
- `kSecAttrAccessible` is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- `kSecAttrSynchronizable` is `false`.
- `write` updates an existing item with `SecItemUpdate`, or adds one with `SecItemAdd`.
- `delete` succeeds if no item exists.
- An `OSStatus` error throws an error that contains only the status number.
- Each `SecItem` call runs inside a `DispatchQueue.async {` block on a private serial queue. Use `withCheckedThrowingContinuation`, as `RadioPlayer.activateSession(on:)` does.
- The class has only `let` properties, so it is `Sendable` without `@unchecked`.
- If `WalletStore.connection()` reads a stored value that does not parse, it returns `nil` and does not throw. The value does not go into a log.

Guard test (`KeychainThreadTests`):

- It scans `CitizenRadio/*.swift`. Each call of `SecItemCopyMatching`, `SecItemUpdate`, `SecItemAdd` or `SecItemDelete` must have `.async {` in the 4 lines before it. Constants such as `errSecItemNotFound` do not count.
- The failure message is: "ADR 0007 §Storage: <file>:<line> calls SecItem outside a dispatch queue block. Keychain calls can block the main thread. Call it on the KeychainSecretStore queue."
- It fails if it finds no `SecItem` call.

Other constraints:

- `KeychainSecretStore.swift` starts with `#if os(iOS)` and imports `Foundation` and `Security`. It imports `CitizenRadioCore` inside `#if SWIFT_PACKAGE`, as the other app files do.
- Prose and comments in ASD-STE100.

## Implementation steps

1. Write `SecretStore.swift` with the protocol and `WalletStore`.
2. Write `WalletStoreTests.swift` with an in-memory fake `SecretStore` (an actor).
3. Write `KeychainSecretStore.swift`.
4. Write `KeychainThreadTests.swift`.
5. Run the test commands. The iOS build in `scripts/check.sh` compiles `KeychainSecretStore`.

## Acceptance criteria

Mechanical:

- `WalletStore.save` followed by `connection()` gives an equal connection.
- `remove()` followed by `connection()` gives `nil`.
- A stored value that does not parse gives `nil`.
- `KeychainThreadTests` passes, and fails if a `SecItem` call is outside a queue block (test this one time by hand, then remove the probe).
- `scripts/check.sh` passes, so `KeychainSecretStore` compiles with the iOS SDK in Swift 6 mode.

Visual (on an iPhone, after task 009):

- A saved connection is still there after the app restarts.
- After a restart of the phone and one unlock, the app can read the connection while the phone is locked.
- The Keychain works with the xtool free signing account.

## Test commands

```sh
swift test --build-system native --filter "WalletStoreTests|KeychainThreadTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- Swift 6 requires `@unchecked Sendable` for `KeychainSecretStore`.
- The iOS build cannot find `Security` or a `kSecAttr` constant.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-007-secret-store.md
- CitizenRadio/Core/NWCConnection.swift
- CitizenRadio/RadioPlayer.swift (sessionQueue and activateSession(on:))
- Tests/CitizenRadioCoreTests/AudioSessionThreadTests.swift

Goal:
- Add SecretStore and WalletStore in CitizenRadioCore, KeychainSecretStore in the app target, and a guard test for Keychain calls.

Constraints:
- Use the exact API and Keychain rules in the task file.
- Each SecItem call runs in a DispatchQueue.async block on a private serial queue.
- No @unchecked Sendable. No secret in errors or logs.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change", including CitizenRadio.xcodeproj.

Acceptance criteria:
- All mechanical criteria in the task file pass.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "WalletStoreTests|KeychainThreadTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
