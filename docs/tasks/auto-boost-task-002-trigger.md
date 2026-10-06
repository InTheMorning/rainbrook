# Auto-boost task 002: Trigger and settings

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 1. Model: Sonnet.
- Decision: [ADR 0012](../adr/0012-auto-boost.md) §The trigger, §Settings.
- Depends on: none.

## Goal

Add `BoostTrigger`. It decides when the listener heard a track from its start to its end. Add `BoostSettings`. It stores the two settings.

## Files to inspect

- `docs/adr/0012-auto-boost.md`
- `CitizenRadio/Core/IcySync.swift` (`normalize`), `CitizenRadio/Core/TrackDisplay.swift`
- `CitizenRadio/Core/ChimeSetting.swift` (the pattern for a stored setting)

## Files likely to change

- `CitizenRadio/Core/BoostTrigger.swift` (new)
- `CitizenRadio/Core/BoostSettings.swift` (new)
- `Tests/CitizenRadioCoreTests/BoostTriggerTests.swift`, `BoostSettingsTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Each file imports only `Foundation`. Use exactly this API:

```swift
public struct BoostTrigger: Equatable, Sendable {
    public struct Completed: Equatable, Sendable {
        public let icyText: String
        /// The newest relay track that ICY sync selected while the track played, or nil.
        public let track: TrackDisplay?
    }
    public init()
    /// Gives a completed candidate, or nil.
    public mutating func receiveIcyText(_ text: String) -> Completed?
    /// The relay track that ICY sync selects now. Nil is a valid input and keeps the last non-nil track.
    public mutating func selectedTrack(_ track: TrackDisplay?)
    /// Stop, a playback error or a change of the Track info event. Drops the candidate and starts a new session.
    public mutating func endSession()
}

public struct BoostSettings: Sendable {
    public static let amountChoices = [21, 50, 100, 250, 500, 1000]
    public static let defaultAmountSats = 100
    public init(defaults: UserDefaults = .standard)
    public var isEnabled: Bool { get nonmutating set }   // default false
    public var amountSats: Int { get nonmutating set }   // default 100; a stored value not in amountChoices gives 100
}
```

Trigger rules (ADR 0012 §The trigger). Compare texts after `IcySync.normalize`:

- The first ICY text of a session starts no candidate. It becomes the present text.
- A text equal to the present text changes nothing.
- A different non-empty text T, with no candidate: start a candidate for T. P is the text before T. The present text is T.
- With a candidate for T:
  - A text equal to P drops the candidate. The present text is P, and the text before it is T.
  - Any other different text, also an empty text, completes the candidate and gives `Completed(icyText: T, track:)`. Then the new text starts the next candidate by the rule above, if it is non-empty.
- `selectedTrack(track)` while a candidate runs keeps the newest non-nil track for that candidate. A new candidate starts with no track.
- `endSession()` drops the candidate. The next ICY text is the first of a new session.

## Acceptance criteria

Mechanical. Each item is a test with fixed texts:

- The first text of a session gives no candidate. A then B then C completes B only.
- A, B, C, D completes B and then C.
- A, B, empty completes B. Empty, then D, then E completes D.
- A, B, A drops B (a repeat), and then B, C completes B.
- A, B, `endSession()`, C, D completes nothing. A new candidate starts only after C.
- The same text again, or a text that differs only in case or spaces, changes nothing.
- The completed track is the newest non-nil track given for that candidate, and a nil after it does not clear it. A candidate with no given track completes with nil.
- `BoostSettings`: the defaults, a stored value, and a stored amount that is not a choice gives 100. Use a separate `UserDefaults` suite.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter "BoostTriggerTests|BoostSettingsTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A rule gives two different results for one sequence.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-002-trigger.md
- docs/adr/0012-auto-boost.md
- CitizenRadio/Core/IcySync.swift, CitizenRadio/Core/TrackDisplay.swift, CitizenRadio/Core/ChimeSetting.swift

Goal:
- Add BoostTrigger and BoostSettings with the exact API and rules in the task file.

Constraints:
- Only Foundation. No time and no I/O in BoostTrigger.
- Tests use fixed texts and fixed expected values.
- Comments in ASD-STE100.
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
