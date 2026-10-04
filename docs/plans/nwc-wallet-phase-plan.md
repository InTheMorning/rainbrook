# NWC wallet configuration: phase plan

- Status: active, 2026-10-04.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md). This plan does not make rules. ADR 0007 owns them.
- Review: [review checklist](../reviews/nwc-wallet-review-checklist.md).

## Goal

The user can connect an Alby Hub wallet through Nostr Wallet Connect, store the connection safely, test it, set a daily limit, and disconnect it.

## Non-goals

- Payments, boosts and the value data source. A subsequent decision record will include them.
- Wallet notifications, more than one wallet, and the `nostr+walletconnect` URL scheme.
- Changes to playback, the chime, the buffer or the App Intents.

## Assumptions

- Alby Hub sends a NIP-47 info event (kind 13194) that lists NIP-44 encryption and `pay_keysend`.
- `swift-secp256k1` 0.23.2 and `swift-crypto` 4 to 5 build on Linux with `--build-system native` and with xtool. A probe build confirmed this on 2026-10-04.
- The Keychain works with an xtool free signing account. This is not tested. Task 007 has a device check for it.
- The NIP-44 test vectors are available at `https://github.com/paulmillr/nip44` in `nip44.vectors.json`.

## Affected modules

| Module | Change |
| --- | --- |
| `Package.swift` | Two dependencies for `CitizenRadioCore`. A test resource for the NIP-44 vectors. |
| `scripts/check.sh` | `swift test --build-system native`. |
| `CitizenRadio/Core/` | New files: `NWCConnection`, `WalletSummary`, `SpendingLimit`, `NostrKeys`, `NostrEvent`, `NIP44`, `NIP04`, `RelayMessage`, `RelayConnection`, `NWCClient`, `SecretStore`, `WalletStatusText`. |
| `CitizenRadio/` (iOS) | New files: `KeychainSecretStore`, `URLSessionRelayConnection`, `WalletSettingsModel`, `WalletSettingsView`, `QRScannerView`. `SettingsView` gets the Wallet section. |
| `CitizenRadio/Info.plist`, `Configuration/xtool-info.plist` | `NSCameraUsageDescription`. |
| `CitizenRadio.xcodeproj/project.pbxproj` | New files and the two package references. |
| `Tests/CitizenRadioCoreTests/` | A test file for each new core file. |
| Docs | ADR 0005, architecture overview, README, runbook. |

## Proposed sequence

Each task is one commit. A task starts only after the review of the task before it passes, except where the table says "parallel".

| Phase | Task | Content | Depends on |
| --- | --- | --- | --- |
| 1 Foundation | [001](../tasks/nwc-wallet-task-001-dependencies.md) | Dependencies, native build system in `check.sh`, ADR 0005 update | none |
| 1 Foundation | [002](../tasks/nwc-wallet-task-002-connection-uri.md) | `NWCConnection` parser and `WalletSummary` | 001 |
| 1 Foundation | [003](../tasks/nwc-wallet-task-003-spending-limit.md) | `SpendingLimit` and the daily limit setting | 001, parallel with 002 |
| 2 Nostr core | [004](../tasks/nwc-wallet-task-004-nostr-event.md) | `NostrEvent`: serialization, ID and Schnorr signature | 001 |
| 2 Nostr core | [005](../tasks/nwc-wallet-task-005-encryption.md) | NIP-44 v2 with test vectors, and NIP-04 | 004 |
| 2 Nostr core | [006](../tasks/nwc-wallet-task-006-nwc-client.md) | `RelayMessage`, NWC messages, `RelayConnection`, `NWCClient.getInfo` with a fake relay | 002, 005 |
| 3 App | [007](../tasks/nwc-wallet-task-007-secret-store.md) | `SecretStore` and `KeychainSecretStore` | 002 |
| 3 App | [008](../tasks/nwc-wallet-task-008-relay-connection.md) | `URLSessionRelayConnection` | 006 |
| 3 App | [009](../tasks/nwc-wallet-task-009-wallet-settings.md) | Wallet section: paste, summary, test, disconnect, daily limit | 003, 007, 008 |
| 3 App | [010](../tasks/nwc-wallet-task-010-qr-scanner.md) | QR scanner and camera permission | 009 |
| 4 Integration | [011](../tasks/nwc-wallet-task-011-xcode-and-docs.md) | Xcode project file and documentation | 010 |

## Schema and API implications

- New UserDefaults keys: `citizenRadio.dailyLimitSats`, `citizenRadio.spentSats`, `citizenRadio.spentDay`. None contains a secret.
- New Keychain item: service `org.citizenradio.CitizenRadio.nwc`, account `default`.
- New public types in `CitizenRadioCore`, as the module table lists. Their names are fixed by this plan. A task does not rename them.
- No change to the App Intents, so the intents metadata stays valid.

## Risk areas

| Risk | Control |
| --- | --- |
| NIP-01 serialization does not agree with other clients, so the wallet rejects the event ID. | Task 004 tests with a known event ID from the NIP-01 specification or a reference client. |
| NIP-44 mistakes leak data or break decryption. | Task 005 must pass all valid and invalid vectors. |
| The secret appears in a log or error. | Tasks 002, 007 and 009 test the error text. The review checklist examines each new log line. |
| Blocking calls on the main thread. | ADR 0006 rule. The review checklist examines each Keychain, network and camera call. |
| The Xcode project file breaks. Only a Mac can examine it. | One task (011) changes it. The friend's next metadata run is the check. |
| `swift-crypto` adds 3.5 MB to the debug binary. | Accepted in ADR 0007. Compare the release size before a store release. |

## Test strategy

- **Linux:** each core type has its own test file. `NWCClient` is tested with fake `SecretStore` and `RelayConnection` types.
- **iOS build:** `scripts/check.sh` runs `xtool dev build` in Swift 6 mode after each task.
- **Device:** the visual acceptance criteria in ADR 0007, after task 010 and again after task 011.

## Rollback strategy

- Each task is one commit. Use `git revert <commit>` for one task.
- Without a stored connection, the app plays as before, so an incomplete Wallet section does not stop playback.
- To remove the feature completely, revert the tasks from 011 back to 001 in reverse sequence.
