# Auto-boost task 012: Switch back and minimum play time

- Decision: [ADR 0016](../adr/0016-boost-switch-back-play-time-and-retry.md) §The switch back and §The minimum play time. Model: Sonnet.
- Depends on: task 010. Task 013 can run at the same time, because it changes different files.

## Goal

The trigger tells a switch back from a reconnect repeat by the `blockGuid`, and gives the play time of each completed track. An auto-boost with a play time of less than the **Minimum play time** setting does not occur.

## Files to inspect

- `docs/adr/0016-boost-switch-back-play-time-and-retry.md`, `docs/adr/0013-boosts.md` §The trigger
- `CitizenRadio/Core/BoostTrigger.swift`, `Tests/CitizenRadioCoreTests/BoostTriggerTests.swift`
- `CitizenRadio/Core/BoostPlan.swift`, `CitizenRadio/Core/BoostStatusText.swift`, `CitizenRadio/Core/BoostSettings.swift`, `CitizenRadio/Core/StreamSettingsDraft.swift`
- `CitizenRadio/BoostModel.swift` (`icyText`, `boost`), `CitizenRadio/TrackInfoModel.swift` (`icyTextChanged`)
- `CitizenRadio/SettingsView.swift` and `CitizenRadio/WalletSettingsView.swift` (the **Boost amount** field is the pattern)

## Files likely to change

- `CitizenRadio/Core/BoostTrigger.swift`, `CitizenRadio/Core/BoostPlan.swift`, `CitizenRadio/Core/BoostStatusText.swift`, `CitizenRadio/Core/BoostSettings.swift`, `CitizenRadio/Core/StreamSettingsDraft.swift`
- `Tests/CitizenRadioCoreTests/BoostTriggerTests.swift`, `BoostPlanTests.swift`, `BoostStatusTextTests.swift`, `BoostSettingsTests.swift`, and the draft tests if `canSave` changes
- `CitizenRadio/BoostModel.swift` (only `icyText` and `boost`), `CitizenRadio/TrackInfoModel.swift` (only `icyTextChanged`)
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift` (only the new field)

## Do not touch

- `BoostHistory.swift`, `BoostPayer.swift`, `BoostHistoryView.swift`. Task 013 changes them.
- Playback, ICY sync, the relay clients and the artwork code.

## Constraints

Core API:

```swift
public struct BoostTrigger {
    public struct Completed: Equatable, Sendable {
        public let icyText: String
        public let track: TrackDisplay?
        /// The seconds from the ICY text of the candidate to the ICY text that completed it.
        public let playedSeconds: Double
    }
    /// track: the relay track that ICY sync selects for this text, or nil.
    /// time: seconds on a monotonic clock. The caller gives it. The trigger has no clock.
    public mutating func receiveIcyText(_ text: String, track: TrackDisplay?, at time: Double) -> Completed?
    public mutating func selectedTrack(_ track: TrackDisplay?)   // no API change
    public mutating func endSession()                           // no API change
}

public enum BoostSkipReason { /* existing cases */ case tooShort(minimumSeconds: Int) }

public enum BoostPlan {
    public static func decide(
        enabled: Bool, amountSats: Int, track: TrackDisplay?, pairing: BoostPairing,
        paidBlocks: Set<String>, limit: SpendingLimit, day: String,
        playedSeconds: Double, minimumPlaySeconds: Int
    ) -> BoostDecision
}

public struct BoostSettings {
    public static let minimumPlaySecondsRange = 0...600
    public static let defaultMinimumPlaySeconds = 60
    /// A stored value that is not in the range gives the default.
    public var minimumPlaySeconds: Int { get nonmutating set }
    /// A whole number in minimumPlaySecondsRange, after trimming white space. Else nil.
    public static func parseMinimumPlaySeconds(_ text: String) -> Int?
}
```

Trigger rules:

- The trigger keeps the `blockGuid` of the present text and of the text before it. A block is `track?.value?.blockGuid`.
  - `receiveIcyText` sets the block of the new present text from its `track`.
  - `selectedTrack` with a non-nil track that has a block sets the block of the present text. It also sets the candidate track, as now.
- A change back to the text before, while a candidate runs:
  - Both blocks known and different: complete the candidate with its play time. The texts and the blocks shift as for a new text. A new candidate starts for the new text at `time`.
  - Else: the reconnect repeat, as now. The candidate is dropped. The two texts and the two blocks change places.
- Each new candidate keeps its start `time` and its first `track` (non-nil only).
- The other rules of ADR 0013 §The trigger do not change. `endSession` also clears the blocks.

Plan rules: the sequence is disabled, noTrack, noPayload, alreadyPaid, tooShort, overDailyLimit, nothingToPay. `tooShort` applies when `minimumPlaySeconds > 0` and `playedSeconds < Double(minimumPlaySeconds)`. `decideManual` does not change.

Status text: `.tooShort(let seconds)` gives "No boost. The track played for less than \(seconds) seconds."

App:

- `TrackInfoModel.icyTextChanged`: call `boost.icyText(text, track: sync.relayTrack)` after `sync.receiveIcyText(text)`, as now.
- `BoostModel.icyText(_:track:)` gives `ProcessInfo.processInfo.systemUptime` as the time. `boost(_:)` reads `BoostSettings().minimumPlaySeconds` and gives `completed.playedSeconds` to `decide`.
- A `tooShort` skip does not add the block to `paidBlocks`.
- Settings: a **Minimum play time** text field in seconds below **Boost amount**, with the number keyboard. Use the pattern of the amount: a text in the draft, an error line for a bad value, and **Save** not possible with a bad value. The footer text says: "Auto-boost pays only for a track that plays for this number of seconds or more. 0 turns off this check."

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100. Comments name ADR 0016 where a rule comes from it.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- Trigger: texts A, B, A with blocks a1, b1, a2: the second A completes B and starts a candidate for A. Then C completes A.
- Trigger: texts A, B, A with blocks a1, b1, a1: the second A drops B. Then C completes nothing.
- Trigger: texts A, B, A with no block for the second A: the second A drops B.
- Trigger: texts A at 100, B at 130, C at 300: C completes B with `playedSeconds` 170.
- The existing trigger tests pass with the new API.
- Plan: minimum 60 and 59.5 seconds give `tooShort(minimumSeconds: 60)`. 60.0 seconds gives `pay`. Minimum 0 and 1 second gives `pay`. A track with no payload and a short play gives `noPayload`.
- Settings: the default is 60. 0 and 600 parse. 601, -1, "1.5" and "abc" give nil. A stored 601 gives 60.
- Status text for `tooShort(minimumSeconds: 60)`.
- `scripts/check.sh` passes.

Manual (by the reviewer): `BoostModel` gives the monotonic time, and a `tooShort` skip does not add the block to `paidBlocks`.

Visual (on an iPhone): the ADR 0016 items for the minimum play time and the switch back. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "BoostTriggerTests|BoostPlanTests|BoostSettingsTests|BoostStatusTextTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- `sync.relayTrack` after `sync.receiveIcyText` is not the selection for the new text.
- A change is necessary in a file in "Do not touch".

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-012-switch-back-and-play-time.md
- docs/adr/0016-boost-switch-back-play-time-and-retry.md
- the files listed in "Files to inspect"

Goal:
- The trigger tells a switch back from a reconnect repeat by the blockGuid, and gives the play time.
- An auto-boost shorter than the Minimum play time setting does not occur.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch", and any file that is not in "Files likely to change".

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
