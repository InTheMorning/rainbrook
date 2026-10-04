# NWC wallet task 005: NIP-44 and NIP-04 encryption

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 2.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Encryption and signatures.
- Depends on: task 004.

## Goal

Add NIP-44 version 2 encryption with the official test vectors, and NIP-04 encryption for older wallets.

## Files to inspect

- `CitizenRadio/Core/NostrKeys.swift`
- `.build/checkouts/swift-secp256k1/Sources/Shared/ECDH.swift` (`P256K.KeyAgreement`, `sharedSecretFromKeyAgreement(with:format:)`)
- `.build/checkouts/swift-crypto/Sources/CryptoExtras/ChaCha20CTR/ChaCha20CTR.swift`
- `.build/checkouts/swift-crypto/Sources/CryptoExtras/AES/AES_CBC.swift`
- NIP-44: `https://github.com/nostr-protocol/nips/blob/master/44.md`
- NIP-04: `https://github.com/nostr-protocol/nips/blob/master/04.md`
- Test vectors: `https://raw.githubusercontent.com/paulmillr/nip44/main/nip44.vectors.json`

## Files likely to change

- `CitizenRadio/Core/NIP44.swift` (new)
- `CitizenRadio/Core/NIP04.swift` (new)
- `Tests/CitizenRadioCoreTests/NIP44Tests.swift` (new)
- `Tests/CitizenRadioCoreTests/NIP04Tests.swift` (new)
- `Tests/CitizenRadioCoreTests/Vectors/nip44.vectors.json` (new, downloaded without change)

## Do not touch

- All other files, including `Package.swift`. Task 004 added the `Vectors` resource.

## Constraints

Use exactly this API:

```swift
public enum NIP44 {
    public enum Error: Swift.Error, Equatable { case invalidKey, invalidPayload, invalidMAC, invalidPadding, messageLength }
    public static func conversationKey(secretKey: String, publicKey: String) throws -> Data  // 32 bytes
    public static func encrypt(_ plaintext: String, conversationKey: Data) throws -> String
    static func encrypt(_ plaintext: String, conversationKey: Data, nonce: Data) throws -> String  // for the vectors
    public static func decrypt(_ payload: String, conversationKey: Data) throws -> String
    static func paddedLength(_ length: Int) -> Int
}

public enum NIP04 {
    public enum Error: Swift.Error, Equatable { case invalidKey, invalidPayload }
    public static func encrypt(_ plaintext: String, secretKey: String, publicKey: String) throws -> String
    static func encrypt(_ plaintext: String, secretKey: String, publicKey: String, iv: Data) throws -> String
    public static func decrypt(_ payload: String, secretKey: String, publicKey: String) throws -> String
}
```

NIP-44 version 2 rules (the specification in `44.md` is the authority):

- The shared secret is the x-coordinate of the ECDH point. Make the peer public key from `0x02` and the 32 x-only bytes. `sharedSecretFromKeyAgreement` gives 33 bytes. Remove the first byte.
- `conversationKey` is HKDF-extract with SHA-256: the input key material is the shared x-coordinate, and the salt is the UTF-8 bytes of `nip44-v2`.
- The message keys are HKDF-expand with SHA-256: the key is the conversation key, the info is the 32-byte nonce, and the length is 76 bytes. Bytes 0 to 31 are the ChaCha20 key, 32 to 43 the ChaCha20 nonce, and 44 to 75 the HMAC key.
- Padding: a 2-byte big-endian length, the plaintext, then zeros to `paddedLength`. The plaintext length is 1 to 65535 bytes.
- The cipher is ChaCha20 with counter 0 (`Insecure.ChaCha20CTR`).
- The MAC is HMAC-SHA256 with the HMAC key over the nonce and then the ciphertext.
- The payload is base64 of: the byte `0x02`, the nonce, the ciphertext, the MAC.
- `decrypt` compares the MAC in constant time before it decrypts. A payload that starts with `#` is not supported and throws `.invalidPayload`.

NIP-04 rules:

- The shared secret is the ECDH x-coordinate, as in NIP-44, without hashing.
- AES-256-CBC with PKCS#7 padding (`AES._CBC`), with a random 16-byte IV.
- The payload is `base64(ciphertext) + "?iv=" + base64(iv)`.

Other constraints:

- No key, plaintext or shared secret goes into an error or a log.
- Prose and comments in ASD-STE100.

## Implementation steps

1. Download `nip44.vectors.json` to `Tests/CitizenRadioCoreTests/Vectors/`. Do not change it.
2. Write `NIP44.swift`, then the tests that read the vectors.
3. Write `NIP04.swift` and its tests.
4. Run the test commands.

## Acceptance criteria

Mechanical:

- `NIP44Tests` passes all entries in `v2.valid.get_conversation_key`, `v2.valid.calc_padded_len` and `v2.valid.encrypt_decrypt` (encryption with the given nonce, and decryption).
- `NIP44Tests` passes all entries in `v2.invalid.encrypt_msg_lengths`, `v2.invalid.get_conversation_key` and `v2.invalid.decrypt`: each one throws.
- A random-nonce `encrypt` followed by `decrypt` gives the plaintext.
- `NIP04Tests`: a round trip between two key pairs gives the plaintext. The payload has the `?iv=` shape. A changed payload does not give the plaintext.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "NIP44Tests|NIP04Tests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count and the number of vectors
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- The download of the vectors fails, or the file structure differs from the section names above.
- A valid vector fails after two attempts at a fix.
- `swift-crypto` has no constant-time compare. Do not write your own.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-005-encryption.md
- CitizenRadio/Core/NostrKeys.swift
- .build/checkouts/swift-secp256k1/Sources/Shared/ECDH.swift
- .build/checkouts/swift-crypto/Sources/CryptoExtras/ChaCha20CTR/ChaCha20CTR.swift
- .build/checkouts/swift-crypto/Sources/CryptoExtras/AES/AES_CBC.swift
- https://github.com/nostr-protocol/nips/blob/master/44.md
- https://github.com/nostr-protocol/nips/blob/master/04.md

Goal:
- Add NIP44 (version 2) and NIP04 in CitizenRadioCore, tested with the official NIP-44 vectors.

Constraints:
- Use the exact API and rules in the task file. The NIP-44 specification is the authority.
- Compare the MAC in constant time before decryption.
- No key, plaintext or shared secret in an error or a log.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- All valid and invalid NIP-44 vectors pass. NIP-04 round trips pass.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "NIP44Tests|NIP04Tests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
