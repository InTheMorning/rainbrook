# NWC wallet task 009: Wallet section in Settings

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 3.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Settings, §Connection test, §Daily limit. [ADR 0004](../archive/adr/0004-player-screen-and-settings.md) for the settings sheet.
- Depends on: tasks 003, 007 and 008.

## Goal

Add the **Wallet** section to the settings sheet: paste, summary, connection test, disconnect and the daily limit.

## Files to inspect

- `CitizenRadio/SettingsView.swift`
- `CitizenRadio/Core/SecretStore.swift`, `CitizenRadio/Core/NWCClient.swift`, `CitizenRadio/Core/WalletSummary.swift`, `CitizenRadio/Core/SpendingLimit.swift`
- `CitizenRadio/KeychainSecretStore.swift`, `CitizenRadio/URLSessionRelayConnection.swift`
- `CitizenRadio/Core/PlayerScreenModel.swift` (the pattern: display text in the core, views only read it)

## Files likely to change

- `CitizenRadio/Core/WalletStatusText.swift` (new)
- `CitizenRadio/WalletSettingsModel.swift` (new, iOS only)
- `CitizenRadio/WalletSettingsView.swift` (new, iOS only)
- `CitizenRadio/SettingsView.swift` (insert the section and own the model)
- `Tests/CitizenRadioCoreTests/WalletStatusTextTests.swift` (new)

## Do not touch

- The player screen, the playback code and the other settings sections.
- `CitizenRadio.xcodeproj/`, the plists and all other files.

## Constraints

Core API:

```swift
public enum WalletStatusText {
    public static func connected(_ info: WalletInfo) -> String
    public static func keysendWarning(_ info: WalletInfo) -> String?   // nil if keysend is supported
    public static func failure(_ error: any Error) -> String
}
```

Texts, exactly:

| Input | Text |
| --- | --- |
| `connected`, alias present | "Connected to <alias>. <n> methods available." |
| `connected`, no alias | "Connected to the wallet. <n> methods available." |
| `keysendWarning`, no `pay_keysend` | "This wallet does not support keysend. Streaming payments need keysend." |
| `NWCConnection.ParseError` | its `errorDescription` |
| `.noInfoEvent` | "The wallet did not publish its information. Examine the connection in your wallet." |
| `.unsupportedEncryption` | "The wallet uses an encryption that CitizenRadio does not support." |
| `.relayRejected` | "The relay did not accept the request." |
| `.walletError(code:message:)` | "The wallet returned the error <code>." |
| `.invalidResponse` | "CitizenRadio cannot read the response of the wallet." |
| `.timeout` | "The wallet did not answer in 10 seconds." |
| any other error | "CitizenRadio cannot connect to the relay." |
| `storageFailure` (a Keychain error on read, save or remove) | "CitizenRadio cannot access the wallet connection in the Keychain." |

App model (`WalletSettingsModel.swift`):

```swift
#if os(iOS)
@MainActor
final class WalletSettingsModel: ObservableObject {
    enum State: Equatable {
        case loading
        case notConnected(message: String?)
        case connected(WalletSummary, status: String?, warning: String?, isTesting: Bool)
    }
    @Published private(set) var state: State = .loading
    init(store: WalletStore = WalletStore(secrets: KeychainSecretStore()),
         connector: any RelayConnecting = URLSessionRelayConnector())
    func load() async
    func connect(text: String?) async     // parse, save, then state .connected
    func test() async                     // NWCClient(...).getInfo()
    func disconnect() async
}
#endif
```

View rules (`WalletSettingsView.swift`):

- It is one `Section` with the header "Wallet" and these rows:
  - `.notConnected`: a SwiftUI `PasteButton(payloadType: String.self)` that calls `connect(text:)` with the first string, and the message if present.
  - `.connected`: `LabeledContent("Relay", value: relayHost)`, `LabeledContent("Wallet", value: walletKeyPrefix + "…")`, `LabeledContent("Address", value: lud16)` if present, a **Test Connection** button (disabled while `isTesting`, with a `ProgressView` while testing), the status and warning texts, and a **Disconnect** button with `role: .destructive` and a confirmation dialog.
  - Always: `Picker("Daily limit", selection: dailyLimitSats)` with `SpendingLimit.choices`, each shown as "<n> sats".
- The footer: "The wallet connection is saved at once. Save applies the daily limit."
- Inputs: `@ObservedObject var model: WalletSettingsModel` and `@Binding var dailyLimitSats: Int`.
- Accessibility identifiers: `walletPaste`, `walletTest`, `walletDisconnect`, `dailyLimitPicker`.

`SettingsView` changes:

- Own the model with `@StateObject private var wallet = WalletSettingsModel()`.
- Insert `WalletSettingsView(model: wallet, dailyLimitSats: $draft.dailyLimitSats)` after the chime section.
- Call `await wallet.load()` in a `.task` modifier.

Threading:

- The model is `@MainActor`. Keychain and network work happens in `WalletStore` and `NWCClient`, which do not block the main thread.
- Start each action from a button with `Task { await model.… }`.

Other constraints:

- No secret, URI or decrypted content in the state, a log or the view.
- Prose, user texts and comments in ASD-STE100.

## Implementation steps

1. Write `WalletStatusText.swift` and its tests.
2. Write `WalletSettingsModel.swift`.
3. Write `WalletSettingsView.swift`.
4. Change `SettingsView.swift`.
5. Run the test commands.

## Acceptance criteria

Mechanical:

- `WalletStatusTextTests` covers each row of the text table.
- `scripts/check.sh` passes, so the views compile with the iOS SDK in Swift 6 mode.

Visual (on an iPhone):

- **Paste** saves a URI from Alby Hub. The section then shows the relay, the wallet prefix and the address, but not the secret.
- A pasted text that is not a connection shows the parse error, and nothing is saved.
- **Test Connection** shows "Connected to …" within 10 seconds.
- **Disconnect** asks for confirmation and removes the wallet. The wallet stays removed after an app restart.
- The daily limit picker shows the saved value. **Save** keeps a new value. **Cancel** discards it.

## Test commands

```sh
swift test --build-system native --filter WalletStatusTextTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- `PasteButton` is not available for `String` with the iOS 17 deployment target.
- The model needs a type or method that tasks 002 to 008 did not supply.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-009-wallet-settings.md
- CitizenRadio/SettingsView.swift
- CitizenRadio/Core/SecretStore.swift
- CitizenRadio/Core/NWCClient.swift
- CitizenRadio/Core/WalletSummary.swift
- CitizenRadio/Core/SpendingLimit.swift
- CitizenRadio/KeychainSecretStore.swift
- CitizenRadio/URLSessionRelayConnection.swift
- CitizenRadio/Core/PlayerScreenModel.swift

Goal:
- Add WalletStatusText (core, tested), WalletSettingsModel and WalletSettingsView, and insert the Wallet section into SettingsView.

Constraints:
- Use the exact API, texts, rows, identifiers and SettingsView changes in the task file.
- The model is @MainActor. Actions start in Task blocks. No blocking calls on the main thread.
- No secret, URI or decrypted content in state, logs or the view.
- Prose, user texts and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- The player screen, playback code, other settings sections, the Xcode project, the plists.

Acceptance criteria:
- WalletStatusTextTests covers each text. scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter WalletStatusTextTests
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
