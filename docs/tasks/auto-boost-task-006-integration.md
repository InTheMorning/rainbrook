# Auto-boost task 006: Integration and settings

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 4. Model: Opus.
- Decision: [ADR 0012](../adr/0012-auto-boost.md), all sections. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for threading.
- Depends on: tasks 001 to 005.

## Goal

Connect the boost parts to the app. The app reads the live value stream, gives the ICY texts to the trigger, and decides and pays each boost. The Wallet section gets the two settings and the result line.

## Files to inspect

- `docs/adr/0012-auto-boost.md`, `docs/adr/0011-icy-sync-of-the-relay-display.md`
- `CitizenRadio/TrackInfoModel.swift` (the relay client lifecycle, the ICY text and `sync.relayTrack`)
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift`, `CitizenRadio/WalletSettingsModel.swift`, `CitizenRadio/PlayerView.swift`
- `CitizenRadio/Core/StreamSettingsDraft.swift` and its tests
- The core types of tasks 001 to 005, `CitizenRadio/Core/SpendingLimit.swift`, `CitizenRadio/Core/SecretStore.swift`
- `docs/reviews/relay-display-review-checklist.md` §4 (no sheet on a Section)

## Files likely to change

- `CitizenRadio/BoostModel.swift` (new, iOS only)
- `CitizenRadio/TrackInfoModel.swift`
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift`, `CitizenRadio/PlayerView.swift`
- `CitizenRadio/Core/StreamSettingsDraft.swift`, `Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift`

## Do not touch

- The core types of tasks 001 to 005, except to call them.
- Playback, chime, audio session, buffer and timeout code. The ICY sync rules.

## Constraints

`BoostModel` (`@MainActor final class BoostModel: ObservableObject`):

- `@Published private(set) var status: String?` (from `BoostStatusText`).
- `init(walletStore: WalletStore = WalletStore(secrets: KeychainSecretStore()), connector: any RelayConnecting = URLSessionRelayConnector(), fetcher: any SnapshotFetching = URLSessionSnapshotFetcher())`.
- Inputs, all called by `TrackInfoModel` on the main actor:
  - `icyText(_ text: String)`: give it to `BoostTrigger.receiveIcyText`. On a completed candidate, start a boost (below).
  - `selectedTrack(_ track: TrackDisplay?)`: give it to `BoostTrigger.selectedTrack`.
  - `payload(_ payload: LiveValuePayload)`: give it to `BoostPairing.receive`.
  - `sessionEnded()`: `BoostTrigger.endSession()`, `BoostPairing.clear()`, and clear the paid block set.
- A boost:
  1. `BoostPlan.decide(enabled: BoostSettings().isEnabled, amountSats: BoostSettings().amountSats, track: completed.track, pairing:, paidBlocks:, limit: SpendingLimitStore().limit, day: SpendingLimit.dayKey(for: Date()))`.
  2. `.skip(reason)`: set `status` to `BoostStatusText.text(for: reason)` if it is not nil. Stop.
  3. `.pay(payload, parts)`: add `payload.blockGuid` to the paid block set before the payment starts, so a second completion cannot pay it again.
  4. In a `Task`: `try await walletStore.connection()`. No connection: `status = BoostStatusText.noWallet`. Else make `NWCClient(connection:connector:timeout: .seconds(30))` and `BoostPayer(wallet:fetcher:)`, and `await payer.pay(parts:payload:amountSats:)`.
  5. Record `result.paidSats + result.unknownSats` with `SpendingLimitStore().record(_:on:)` when it is more than 0. Set `status = BoostStatusText.text(for: result)` on the main actor.
- One boost at a time is not required. Two boosts can overlap. Each one has its own payer.
- The Keychain read, the NWC payment and the LNURL requests run in the payer, the wallet store and `NWCClient`, never on the main actor.
- The `boost` log category (`Logger(subsystem: "org.citizenradio.CitizenRadio", category: "boost")`, level `.notice`) records the decision kind, the amount, the count of parts and the paid count. No title, no key, no invoice.

`TrackInfoModel` changes:

- Own one `BoostModel`, made in the initializer. Publish it read-only as `boost`.
- Run a second `EventStreamClient` for the live value while the relay client runs and `BoostSettings().isEnabled` is true: `snapshotURL: event.remoteValueURL`, `streamURL: event.valueEventsURL`, `eventName: "remoteValue"`, the same opener and fetcher. Start, stop and `networkChanged()` it together with the display client.
- Each `.snapshot(data)` and `.event(event)` of the value client: `LiveValuePayload.decode`. A nil result or a decode error is ignored. Else `boost.payload(_:)`.
- After `sync.receiveIcyText(text)`: `boost.icyText(text)`, then `boost.selectedTrack(sync.relayTrack)`. After each other change of `sync.relayTrack`: `boost.selectedTrack(sync.relayTrack)`.
- Playback stops, a change of the Track info event, and a `404` or `409` stop: `boost.sessionEnded()`.
- `reloadSettings()` also starts or stops the value client when the Auto-boost setting changed.

Settings:

- `StreamSettingsDraft` gets `boostEnabled: Bool` and `boostAmountSats: Int`, with saved values, in the style of `dailyLimitSats`. `canSave` is true when either one changed. Add the two parameters at the end of the initializer.
- `SettingsView` reads them from `BoostSettings()` and saves them on **Save** with the other settings.
- `WalletSettingsView`, in the Wallet section when a wallet is connected: a `Toggle("Auto-boost", …)` with the identifier `autoBoostToggle`, and a `Picker("Boost amount", …)` over `BoostSettings.amountChoices` ("\(n) sats") with the identifier `boostAmountPicker`, disabled when the toggle is off. Under them, `boost.status` in the secondary style, if present. A footer text: "When you hear a V4V track from its start to its end, the app pays this amount to its artists. The daily limit applies."
- `PlayerView` passes `trackInfo.boost.status` to `SettingsView`, and `SettingsView` passes it to `WalletSettingsView`, in the style of `relayStatus`.
- No `.sheet`, `.alert`, `.confirmationDialog` or `.fullScreenCover` on a `Section`.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- Comments and user texts in ASD-STE100.

## Acceptance criteria

Mechanical:

- `StreamSettingsDraftTests`: a change of `boostEnabled` alone, and of `boostAmountSats` alone, enables Save. The present tests pass with the new parameters.
- `scripts/check.sh` passes, so all iOS files compile in Swift 6 mode.

Manual (by the reviewer):

- `BoostModel` adds the block to the paid set before the payment task starts.
- The Keychain read, NWC and LNURL work are not on the main actor.
- The value client runs only while the display client runs and Auto-boost is on.

Visual (on an iPhone): the ADR 0012 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter StreamSettingsDraftTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the results
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- A core type of tasks 001 to 005 needs a change.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.
- The change needs edits to playback, chime, audio session or ICY sync rules.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-006-integration.md
- docs/adr/0012-auto-boost.md
- the files listed in "Files to inspect"

Goal:
- Add BoostModel. Connect it to TrackInfoModel with a second EventStreamClient for the live value.
- Add the Auto-boost settings and the result line to the Wallet section.

Constraints:
- Use the exact rules in the task file. TrackInfoModel and BoostModel are @MainActor; payments, LNURL and Keychain work stay off the main actor.
- No @unchecked Sendable or nonisolated(unsafe). No sheet or alert on a Section.
- Comments and user texts in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- The mechanical criteria in the task file pass. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
