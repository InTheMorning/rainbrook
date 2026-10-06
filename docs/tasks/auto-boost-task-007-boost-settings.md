# Auto-boost task 007: Boost settings

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave A. Model: Sonnet.
- Decision: [ADR 0013](../adr/0013-boosts.md) §Settings.
- Depends on: tasks 001 to 006.

## Goal

Replace the preset boost amounts with an exact amount. Add the boost message, the sender name and the app name. Show the new fields in the Wallet section.

## Files to inspect

- `docs/adr/0013-boosts.md` §Settings
- `CitizenRadio/Core/BoostSettings.swift`, `CitizenRadio/Core/StreamSettingsDraft.swift` and their tests
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift`
- `docs/reviews/relay-display-review-checklist.md` §4 (no sheet on a Section)

## Files likely to change

- `CitizenRadio/Core/BoostSettings.swift`, `Tests/CitizenRadioCoreTests/BoostSettingsTests.swift`
- `CitizenRadio/Core/StreamSettingsDraft.swift`, `Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift`
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift`

## Do not touch

- All other files. `BoostModel` reads `BoostSettings().amountSats` and `isEnabled`. Keep these two properties.

## Constraints

`BoostSettings` (only `Foundation`, not `Sendable`, like `ChimeSetting`). Use exactly this API:

```swift
public struct BoostSettings {
    public static let amountRange = 1...100_000
    public static let defaultAmountSats = 100
    public static let maxMessageLength = 200
    public static let maxNameLength = 64
    public static let defaultAppName = "CitizenRadio"
    public init(defaults: UserDefaults = .standard)
    public var isEnabled: Bool { get nonmutating set }     // default false
    public var amountSats: Int { get nonmutating set }     // default 100; a stored value outside amountRange gives 100
    public var message: String { get nonmutating set }     // default ""; the setter cuts it to maxMessageLength characters
    public var senderName: String { get nonmutating set }  // default ""; the setter cuts it to maxNameLength characters
    public var appName: String { get nonmutating set }     // default "CitizenRadio"; an empty or white-space value gives the default; cut to maxNameLength
    /// A whole number in amountRange, after trimming white space. Else nil.
    public static func parseAmount(_ text: String) -> Int?
}
```

- Remove `amountChoices`. Keep the stored keys of task 002 for `isEnabled` and `amountSats`.
- Cut a text by characters (`String.prefix`), not by bytes.

`StreamSettingsDraft` changes:

- Replace `boostAmountSats: Int` with `boostAmountText: String`, and its saved value.
- Add `boostMessage`, `boostSenderName` and `boostAppName` (all `String`), with saved values, in the style of `relayText`.
- The initializer takes the new values at the end, in this order: `boostEnabled`, `boostAmountText`, `boostMessage`, `boostSenderName`, `boostAppName`.
- `canSave` is false while `BoostSettings.parseAmount(boostAmountText)` is nil. Else a change of any boost value enables **Save**, as now.

Settings view:

- `SettingsView` loads the values from `BoostSettings()` (the amount as text) and saves them on **Save**. Read the amount with `if let amount = BoostSettings.parseAmount(text)`, not with `!`.
- `WalletSettingsView`, when a wallet is connected, in this order:
  - `Toggle("Auto-boost", …)`, identifier `autoBoostToggle`.
  - `TextField("Boost amount", text:)` with `.keyboardType(.numberPad)`, identifier `boostAmountField`, and the label text "sats" after it. If the text is not valid, show "Enter 1 to 100,000 sats." in red under it.
  - `TextField("Boost message", text:, axis: .vertical)`, identifier `boostMessageField`.
  - `TextField("From", text:)`, identifier `boostSenderField`, with the prompt "Your name".
  - `TextField("App name", text:)`, identifier `boostAppNameField`, with the prompt "CitizenRadio".
  - The boost status, as now.
  - The footer: "Auto-boost pays this amount when you hear a V4V track from its start to its end. A manual boost starts with this amount. The daily limit stops auto-boost, not a manual boost."
- No `.sheet`, `.alert`, `.confirmationDialog` or `.fullScreenCover` on a `Section`.
- User texts and comments in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test:

- `BoostSettings` defaults. A stored amount of 0 or of 100,001 gives 100. A stored amount of 1 or of 100,000 stays.
- The message setter cuts 250 characters to 200. The name setters cut 70 characters to 64. An app name of "" or "   " gives "CitizenRadio".
- `parseAmount`: "1" gives 1, " 250 " gives 250 and "100000" gives 100,000. "0", "100001", "-5", "12.5", "1e3", "abc" and "" give nil.
- `StreamSettingsDraft`: an invalid amount text disables Save, also with other changes. A change of each new value alone enables Save. The present tests pass with the new initializer.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "BoostSettingsTests|StreamSettingsDraftTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A file outside the list must change to compile.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-007-boost-settings.md
- docs/adr/0013-boosts.md §Settings
- the files listed in "Files to inspect"

Goal:
- Replace the preset amounts with an exact amount.
- Add the message, sender name and app name settings, and show them in the Wallet section.

Constraints:
- Use the exact API and rules in the task file. BoostSettings is not Sendable.
- Tests use fixed values. No sheet or alert on a Section.
- Comments and user texts in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
