# ADR 0007: NWC wallet configuration

- Status: proposed
- Date: 2026-10-04
- Class: situational. Supersede this record when the wallet connection method or its storage changes.
- Related: [ADR 0004](0004-player-screen-and-settings.md) puts all configuration in the settings sheet. [ADR 0006](0006-audio-session-off-main-thread.md) keeps blocking calls off the main thread.

## Context

The user wants value-for-value (V4V) payments while the stream plays, as podcast 2.0 apps do.
The wallet connection uses Nostr Wallet Connect (NWC, NIP-47).
The user copies a connection URI from a wallet. The URI has this shape:

```text
nostr+walletconnect://<wallet service public key>?relay=wss://<relay>&secret=<client secret>&lud16=<optional address>
```

- The public key and the secret are 64 hexadecimal characters.
- The URI can contain more than one `relay` parameter.
- The secret signs and encrypts the payment requests. A person with the secret can spend from the wallet. The wallet budget is the maximum.

The app stores its other settings in UserDefaults without encryption ([architecture overview](../architecture/overview.md#settings-and-network-access)).
That storage is not safe for the secret.

This record includes only the configuration: entry, validation, storage, connection test and disconnection.
A different record will include the payments, the value data source and the payment schedule.

## Decision

### Scope

- The first version stores and tests a wallet connection. It sends no payment.
- Without a wallet connection, the app plays as before.

### Settings

The settings sheet gets a **Wallet** section with these items:

- When no wallet is connected: **Paste Connection** reads the URI from the clipboard one time, when the user taps it.
- When a wallet is connected:
  - The relay host, the first 8 characters of the wallet public key, and the `lud16` address if the URI has one.
  - **Test Connection**.
  - **Disconnect**, which deletes the stored URI.
- After the app saves the secret, it does not show the secret again.

### Validation

`NWCConnection` in `CitizenRadioCore` parses the URI. It accepts a URI only if it agrees with all these conditions:

- The scheme is `nostr+walletconnect`.
- The host is a valid public key: 64 hexadecimal characters.
- The URI has a minimum of one `relay` parameter, and each relay uses `wss`.
- The `secret` parameter is 64 hexadecimal characters and is not zero.

An invalid URI shows an error, and the stored connection does not change.
The error message does not contain the URI or the secret.

### Storage

- `NWCStore` stores the complete URI in the Keychain as a generic password.
- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  - The app plays while the phone is locked, so payments must read the secret after the first unlock.
  - `ThisDeviceOnly` keeps the secret out of backups and other devices.
- The item is not synchronizable through iCloud Keychain.
- Keychain calls run on a background queue, as ADR 0006 requires for blocking calls.
- The URI and the secret do not go into UserDefaults, logs, Now Playing information, crash reports or error messages.

### Connection test

**Test Connection** sends a NIP-47 `get_info` request through the first relay and waits at most 10 seconds.

- The app shows the result: the wallet alias, if the wallet sends it, and the supported methods.
- If the wallet does not support `pay_keysend`, the app shows a warning. Podcast 2.0 streaming payments use keysend.
- The WebSocket connection uses `URLSessionWebSocketTask` with async calls. No network call runs on the main thread.

### Encryption and signatures

- NIP-47 requests need secp256k1 Schnorr signatures and NIP-44 encryption. Older wallets use NIP-04 encryption.
- The app uses NIP-44 if the wallet's info event lists it. It uses NIP-04 only if the wallet supports nothing else.
- The cryptography goes in `CitizenRadioCore`, so Linux tests can examine it with the NIP-44 test vectors.
- The cryptography libraries must be SwiftPM packages that build with xtool and on Linux. A binary framework is not permitted, because Linux tests cannot use it.

## Alternatives considered

- **Store the URI in UserDefaults.** UserDefaults does not encrypt, and backups include it.
- **`kSecAttrAccessibleWhenUnlocked`.** Payments during locked playback could then not read the secret.
- **iCloud Keychain synchronization.** It copies a spending key to other devices without a user action.
- **A text field for the URI.** Paste from a button keeps the secret off the screen and out of the keyboard history.
- **QR code scanning.** It needs camera permission and more code. Add it later if paste is not sufficient.
- **Register the `nostr+walletconnect` URL scheme.** Other wallet apps can register the same scheme, and iOS does not guarantee which app opens it.
- **A binary Nostr SDK, such as Rust bindings in an XCFramework.** Linux tests cannot load it, and it makes the xtool build larger.

## Consequences

- The app gets its first external dependencies: a secp256k1 package and probably `swift-crypto` for the Linux tests.
- The privacy manifest must be examined for the Keychain and network use before release.
- Keychain access with an xtool free signing account is not tested.
- The settings sheet gets a third section. ADR 0004 permits this, because it puts all configuration in the settings sheet.

## Acceptance criteria

### Mechanical

Each criterion has a test in `Tests/CitizenRadioCoreTests/`.

- `NWCConnection` accepts a valid URI with one relay, and a valid URI with two relays.
- `NWCConnection` rejects a wrong scheme, a short public key, a missing relay, a `ws` relay, a missing secret, and a zero secret.
- The `NWCConnection` error description does not contain the secret.
- The NIP-44 encryption agrees with the published NIP-44 test vectors.
- A `get_info` request event has kind 23194, the wallet `p` tag, and a valid Schnorr signature.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until that examination is complete.

- **Paste Connection** saves a URI from Alby or another NWC wallet, and the secret is not shown.
- **Test Connection** shows the wallet methods within 10 seconds.
- **Disconnect** removes the wallet. After a restart of the app, the wallet stays removed.
- After a restart of the phone and one unlock, a background test can read the stored connection while the phone is locked.

## Open questions

1. Is paste from the clipboard sufficient for the first version, or is QR code scanning necessary?
2. Which wallet will you use for the tests? Its `get_info` response and encryption support decide the first test case.
3. Do you want spending limits in the app, in addition to the wallet budget? If yes, they belong in this record. A proposed default is 1000 sats each day.
4. Which secp256k1 package: `swift-secp256k1` from 21-DOT-DEV, or another one that builds with xtool? I must test the build before this record is accepted.
