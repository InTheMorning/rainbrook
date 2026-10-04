# ADR 0007: NWC wallet configuration

- Status: accepted. The visual acceptance criteria are open.
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

This record includes only the configuration: entry, validation, storage, spending limit, connection test and disconnection.
A different record will include the payments, the value data source and the payment schedule.

## Decision

### Scope

- The first version stores and tests a wallet connection. It sends no payment.
- Without a wallet connection, the app plays as before.

### Settings

The settings sheet gets a **Wallet** section with these items:

- When no wallet is connected:
  - **Paste Connection** is a SwiftUI `PasteButton`. It reads the URI from the clipboard one time, when the user taps it. iOS shows no paste permission alert for this system button.
  - **Scan QR Code** opens the camera and reads a QR code that contains the URI.
- When a wallet is connected:
  - The relay host, the first 8 characters of the wallet public key, and the `lud16` address if the URI has one.
  - **Test Connection**.
  - **Disconnect**, which deletes the stored URI.
- **Daily limit**: the maximum sats that the app pays in one local calendar day. The default is 1000 sats.
- After the app saves the secret, it does not show the secret again.

### QR code scanning

- The scanner uses VisionKit `DataScannerViewController` for QR codes.
  The deployment target is iOS 17, and all iPhones with iOS 17 have the A12 chip or a newer chip that VisionKit requires.
- The app asks for camera access only when the user taps **Scan QR Code**. `NSCameraUsageDescription` gives the reason.
- If `DataScannerViewController.isSupported` or `isAvailable` is false, the app hides the button and shows the paste method only.
- The scanner passes the text to the same `NWCConnection` validation as the paste method. It closes after the first valid URI.

### Daily limit

- `SpendingLimit` in `CitizenRadioCore` decides if a payment fits in the remaining amount for the day.
- The limit and the amount spent today go in UserDefaults. They are not secret.
- A new local calendar day resets the amount spent.
- This record stores the limit. The payment record will apply it to each payment.
- The wallet budget stays in force. The lower of the two limits stops the payments.

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
- The libraries are:
  - `swift-secp256k1` from 21-DOT-DEV, version 0.23.2, product `P256K`: Schnorr signatures and ECDH.
  - `swift-crypto` from Apple, versions 4.0.0 to 5.x, products `Crypto` and `CryptoExtras`: SHA-256, HKDF, HMAC, ChaCha20 and AES-CBC.
- A probe build on 2026-10-04 confirmed these libraries:
  - On Linux, a test signed and verified a Schnorr signature, derived an ECDH x-coordinate, and ran HKDF, ChaCha20 and AES-CBC.
  - With xtool, the iOS app built and linked these functions. It also linked the iOS system `libc++`. The debug binary grew from 0.8 MB to 4.3 MB.
  - On Linux, the default SwiftPM build system did not find the C++ headers of GCC 16 for BoringSSL in `swift-crypto`. The native build system (`swift test --build-system native`) worked.

### Module boundaries

- `CitizenRadioCore` contains all logic that Linux tests can examine:
  the URI parser, the wallet summary, the daily limit, Nostr events, NIP-44 and NIP-04, the relay messages and `NWCClient`.
- `CitizenRadioCore` defines two protocols for the parts that need iOS:
  - `SecretStore` reads, writes and deletes the URI.
  - `RelayConnection` sends and receives relay text messages.
- The app target supplies `KeychainSecretStore` and `URLSessionRelayConnection`. Tests use fakes of the two protocols.
- `NWCClient` uses only these protocols. It does not import Security or use `URLSession` directly.
- The Xcode project gets the new files and the two package dependencies in one task at the end. Only a Mac build can examine that project file.

### Test wallet

The tests use Alby Hub. It supports NWC with NIP-44 encryption and `pay_keysend`.

## Non-goals

- Payments of any kind: keysend, invoices, boosts and streaming payments.
- The value data source, such as `podcast:value` in a feed.
- Notifications from the wallet (NIP-47 kinds 23196 and 23197).
- More than one wallet connection.
- The `nostr+walletconnect` URL scheme and the NWC deep link flow.

## Alternatives considered

- **Store the URI in UserDefaults.** UserDefaults does not encrypt, and backups include it.
- **`kSecAttrAccessibleWhenUnlocked`.** Payments during locked playback could then not read the secret.
- **iCloud Keychain synchronization.** It copies a spending key to other devices without a user action.
- **A text field for the URI.** Paste from a button keeps the secret off the screen and out of the keyboard history.
- **QR code scanning with `AVCaptureMetadataOutput`.** It needs more code than VisionKit. Its `startRunning()` blocks, so it also needs a background queue.
- **No daily limit in the app.** The wallet budget alone can be too high, because a person can set a large budget when they make the connection.
- **Register the `nostr+walletconnect` URL scheme.** Other wallet apps can register the same scheme, and iOS does not guarantee which app opens it.
- **A binary Nostr SDK, such as Rust bindings in an XCFramework.** Linux tests cannot load it, and it makes the xtool build larger.

## Consequences

- The app gets its first external dependencies: `swift-secp256k1` and `swift-crypto`.
- `scripts/check.sh` must run `swift test --build-system native`, because the default build system fails on this computer. This changes the first step in [ADR 0005](0005-swift-6-and-check-script.md).
- The app asks for camera access. The Info.plist and `Configuration/xtool-info.plist` get `NSCameraUsageDescription`.
- The privacy manifest must be examined for the Keychain and network use before release.
- Keychain access with an xtool free signing account is not tested.
- The settings sheet gets a third section. ADR 0004 permits this, because it puts all configuration in the settings sheet.

## Invariants

These rules apply while this decision is current.

- The URI and the secret are stored only through `SecretStore`, and the app implementation is the Keychain.
- The URI and the secret do not appear in UserDefaults, logs or error messages.
- Keychain, network and camera calls do not block the main thread.
- `NWCClient` depends only on `SecretStore` and `RelayConnection`, not on iOS frameworks.

The task that adds each rule also adds its test, or names the manual check.

## Acceptance criteria

### Mechanical

Each criterion has a test in `Tests/CitizenRadioCoreTests/`.

- `NWCConnection` accepts a valid URI with one relay, and a valid URI with two relays.
- `NWCConnection` rejects a wrong scheme, a short public key, a missing relay, a `ws` relay, a missing secret, and a zero secret.
- The `NWCConnection` error description does not contain the secret.
- The NIP-44 encryption agrees with the published NIP-44 test vectors.
- `SpendingLimit` permits a payment that fits in the remaining daily amount, rejects a payment that does not fit, and resets on a new local day.
- The default daily limit is 1000 sats.
- A `get_info` request event has kind 23194, the wallet `p` tag, and a valid Schnorr signature.
- `scripts/check.sh` passes.

### Visual

A person must examine these items on an iPhone. Report each item as open until that examination is complete.

- **Paste Connection** saves a URI from Alby Hub, and the secret is not shown.
- **Scan QR Code** reads the connection QR code from Alby Hub on another screen.
- The camera permission request shows only after a tap on **Scan QR Code**.
- **Test Connection** shows the wallet methods within 10 seconds.
- **Disconnect** removes the wallet. After a restart of the app, the wallet stays removed.
- After a restart of the phone and one unlock, a background test can read the stored connection while the phone is locked.
