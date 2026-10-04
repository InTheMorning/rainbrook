# NWC wallet task 003: Daily spending limit

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 1.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Daily limit, §Settings.
- Depends on: task 001. Can run in parallel with task 002.

## Goal

Add the daily limit logic and its storage.
Add the limit to the settings draft, so that **Save** applies it.

## Files to inspect

- `CitizenRadio/Core/BufferSetting.swift` (an example of a setting with fixed choices)
- `CitizenRadio/Core/StreamSettingsDraft.swift`
- `CitizenRadio/SettingsView.swift`
- `Tests/CitizenRadioCoreTests/BufferSettingTests.swift`
- `Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift`

## Files likely to change

- `CitizenRadio/Core/SpendingLimit.swift` (new)
- `CitizenRadio/Core/StreamSettingsDraft.swift`
- `CitizenRadio/SettingsView.swift` (only the `StreamSettingsDraft` initializer call and the save of the limit)
- `Tests/CitizenRadioCoreTests/SpendingLimitTests.swift` (new)
- `Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift`

## Do not touch

- The Settings user interface layout. Task 009 adds the limit picker.
- All other files.

## Constraints

Use exactly this API:

```swift
public struct SpendingLimit: Equatable, Sendable {
    public static let defaultDailySats = 1000
    public static let choices = [100, 500, 1000, 2500, 5000, 10000]

    public let dailySats: Int
    public let spentSats: Int
    public let day: String              // "yyyy-MM-dd" in the local time zone

    public init(dailySats: Int, spentSats: Int, day: String)
    public func remaining(on day: String) -> Int
    public func permits(_ amount: Int, on day: String) -> Bool
    public func recording(_ amount: Int, on day: String) -> SpendingLimit
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String
}

public struct SpendingLimitStore {
    public init(defaults: UserDefaults = .standard)
    public var limit: SpendingLimit { get }
    public func setDailySats(_ sats: Int)
    public func record(_ amount: Int, on day: String)
}
```

Rules:

- If `day` differs from the stored day, the spent amount for that day is 0.
- `remaining` is `max(0, dailySats - spent)`.
- `permits` is true only if `amount > 0` and `amount <= remaining`.
- `recording` adds the amount on that day, or starts from the amount on a new day.
- UserDefaults keys: `citizenRadio.dailyLimitSats`, `citizenRadio.spentSats`, `citizenRadio.spentDay`.
- A stored daily value that is not in `choices` gives `defaultDailySats`, as `BufferSetting` does.
- `StreamSettingsDraft` gets `public var dailyLimitSats: Int` and `public let savedDailyLimitSats: Int`, and an initializer parameter `dailyLimitSats` after `bufferSeconds`. `canSave` is also true when only the limit changes, with the same rules as the buffer.
- In `SettingsView`, pass `SpendingLimitStore().limit.dailySats` to the draft, and call `SpendingLimitStore().setDailySats(draft.dailyLimitSats)` in `save()` adjacent to the buffer save.
- Prose and comments in ASD-STE100.

## Implementation steps

1. Write `SpendingLimit.swift`.
2. Extend `StreamSettingsDraft` and its tests.
3. Change the two lines in `SettingsView.swift`.
4. Write `SpendingLimitTests.swift`.
5. Run the test commands.

## Acceptance criteria

Mechanical (each one is a test):

- The default daily limit is 1000 sats.
- A stored value that is not in `choices` gives 1000.
- `permits` is true for an amount that fits, false for an amount that does not fit, and false for 0.
- `recording` adds amounts on the same day.
- On a new day, `remaining` is the full daily limit.
- `dayKey` gives `"2026-10-04"` for a fixed date in a fixed time zone.
- `StreamSettingsDraft.canSave` is true when only `dailyLimitSats` changes.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "SpendingLimitTests|StreamSettingsDraftTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- The draft change needs more than the two `SettingsView` changes.
- A rule in this task disagrees with ADR 0007.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-003-spending-limit.md
- CitizenRadio/Core/BufferSetting.swift
- CitizenRadio/Core/StreamSettingsDraft.swift
- CitizenRadio/SettingsView.swift
- Tests/CitizenRadioCoreTests/BufferSettingTests.swift
- Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift

Goal:
- Add SpendingLimit and SpendingLimitStore, and add the daily limit to StreamSettingsDraft.

Constraints:
- Use the exact API, keys and rules in the task file.
- Change SettingsView.swift only at the draft initializer and in save().
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- The Settings layout and any file that is not in "Files likely to change".

Acceptance criteria:
- All criteria in the task file have a passing test.
- scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "SpendingLimitTests|StreamSettingsDraftTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
