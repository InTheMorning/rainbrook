# NWC wallet task 004: Nostr event, ID and signature

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 2.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Encryption and signatures, §Module boundaries.
- Depends on: task 001.

## Goal

Add `NostrEvent` with the NIP-01 serialization, the event ID, a BIP-340 Schnorr signature and verification.

## Files to inspect

- `Package.swift`
- `.build/checkouts/swift-secp256k1/Sources/Shared/Schnorr/` (the `P256K.Schnorr` API: `PrivateKey`, `xonly`, `signature(message:auxiliaryRand:strict:)`, `isValid(_:for:)`)
- NIP-01: `https://github.com/nostr-protocol/nips/blob/master/01.md`, section "Events and signatures"
- BIP-340 test vectors: `https://raw.githubusercontent.com/bitcoin/bips/master/bip-0340/test-vectors.csv`

## Files likely to change

- `CitizenRadio/Core/NostrEvent.swift` (new)
- `CitizenRadio/Core/NostrKeys.swift` (new)
- `Tests/CitizenRadioCoreTests/NostrEventTests.swift` (new)
- `Tests/CitizenRadioCoreTests/Vectors/bip340-test-vectors.csv` (new, downloaded without change)
- `Package.swift` (only `resources: [.copy("Vectors")]` on the test target)

## Do not touch

- All other files.

## Constraints

Use exactly this API:

```swift
public enum NostrKeys {
    /// The x-only public key (64 lowercase hexadecimal characters) for a secret key.
    public static func publicKey(forSecret secretHex: String) throws -> String
}

public struct NostrEvent: Codable, Equatable, Sendable {
    public let id: String          // 64 lowercase hexadecimal characters
    public let pubkey: String      // 64 lowercase hexadecimal characters
    public let created_at: Int
    public let kind: Int
    public let tags: [[String]]
    public let content: String
    public let sig: String         // 128 lowercase hexadecimal characters

    /// The NIP-01 serialization: [0,pubkey,created_at,kind,tags,content] as UTF-8 JSON.
    public static func serialize(pubkey: String, createdAt: Int, kind: Int, tags: [[String]], content: String) -> Data

    public static func signed(
        kind: Int, tags: [[String]], content: String, createdAt: Int, secretKey secretHex: String
    ) throws -> NostrEvent

    /// True if `id` is the SHA-256 of the serialization and `sig` is a valid signature of `id` by `pubkey`.
    public func isValid() -> Bool
}
```

Rules:

- The serialization has no spaces and no line breaks.
- Do not use `JSONSerialization` or `JSONEncoder` for the serialization. They can escape `/` as `\/`, and NIP-01 does not permit that. Write the JSON by hand.
- String escape rules from NIP-01: escape only `"` as `\"`, `\` as `\\`, line feed as `\n`, carriage return as `\r`, tab as `\t`, backspace as `\b` and form feed as `\f`. Write all other characters as UTF-8 without change. This rule also applies to non-ASCII characters.
- `id` is the lowercase hexadecimal SHA-256 (`Crypto.SHA256`) of the serialization.
- The signature signs the 32 bytes of `id`, with 32 random bytes from `SystemRandomNumberGenerator` as auxiliary randomness.
- `Codable` uses the field names exactly as written, so the JSON agrees with NIP-01.
- A secret that is not 64 hexadecimal characters throws. Define a small `Error` enum for this in `NostrKeys.swift`.
- The secret key never goes into an error text or a description.
- Prose and comments in ASD-STE100.

## Implementation steps

1. Download the BIP-340 CSV to `Tests/CitizenRadioCoreTests/Vectors/bip340-test-vectors.csv`. Do not change it.
2. Add `resources: [.copy("Vectors")]` to the test target in `Package.swift`.
3. Write `NostrKeys.swift` and `NostrEvent.swift`.
4. Write the tests.
5. Run the test commands.

## Acceptance criteria

Mechanical (each one is a test in `NostrEventTests.swift`):

- For each BIP-340 vector that has a secret key, `NostrKeys.publicKey` gives the vector public key in lowercase.
- For each such vector, a signature with the vector auxiliary data agrees with the vector signature. Add an internal test entry point that takes the auxiliary bytes, if necessary.
- The serialization of a test event with `"a\"b\\c\nd/é"` as content contains `a\"b\\c\nd/é` without `\/` and without `é`.
- `NostrEvent.signed(...)` gives an event for which `isValid()` is true.
- A change of one character in `content` makes `isValid()` false.
- A JSON encode and decode of a signed event gives an equal event.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter NostrEventTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- The download of the BIP-340 vectors fails.
- The `P256K` API does not permit a signature with given auxiliary bytes.
- A BIP-340 vector fails.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-004-nostr-event.md
- Package.swift
- .build/checkouts/swift-secp256k1/Sources/Shared/Schnorr/
- https://github.com/nostr-protocol/nips/blob/master/01.md (Events and signatures)

Goal:
- Add NostrKeys and NostrEvent with the NIP-01 serialization, event ID, BIP-340 signature and verification.

Constraints:
- Use the exact API and escape rules in the task file. Write the serialization JSON by hand.
- Test with the official BIP-340 vectors in Tests/CitizenRadioCoreTests/Vectors/.
- The secret key never appears in an error or a description.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- All criteria in the task file have a passing test.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter NostrEventTests
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
