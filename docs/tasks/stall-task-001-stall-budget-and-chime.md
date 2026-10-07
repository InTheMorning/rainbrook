# Stall task 001: Stall budget, restart and chime

- Decision: [ADR 0021](../adr/0021-stalls-on-a-bad-network.md). [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for threading. Model: Opus.
- Depends on: none.

## Goal

In the played phase, a drop waits for the network. It makes a new item for the same stream when necessary. It fails only after 60 seconds with a network. The chime waits 3 seconds in the played phase. The screen shows "Waiting for the network" with no path.

## Files to inspect

- `docs/adr/0021-stalls-on-a-bad-network.md`, `docs/adr/0017-stations-with-alternate-stream.md` §The fallback
- `CitizenRadio/RadioPlayer.swift` (all of it: `play`, `startPlayer`, `refreshPlayback`, `startConnectionTimeout`, `observeItem`, `streamFailed`, `releaseItem`, `updateChime`)
- `CitizenRadio/NetworkPathMonitor.swift`, `CitizenRadio/Core/NetworkPathSummary.swift`
- `CitizenRadio/Core/ChimeSetting.swift`, `CitizenRadio/Core/PlayerScreenModel.swift`, `CitizenRadio/Core/PlaybackState.swift` and their tests
- `CitizenRadio/PlayerView.swift` (how it makes `PlayerScreenModel`)

## Files likely to change

- `CitizenRadio/Core/StallBudget.swift` (new), `Tests/CitizenRadioCoreTests/StallBudgetTests.swift` (new)
- `CitizenRadio/Core/ChimeSetting.swift`, `CitizenRadio/Core/PlayerScreenModel.swift` and their tests
- `CitizenRadio/RadioPlayer.swift`, `CitizenRadio/PlayerView.swift`
- `CitizenRadio.xcodeproj/project.pbxproj`: one file reference and one build file for `StallBudget.swift`

## Do not touch

- `PlaybackState` cases. `playAndWait` and the intents. The station, relay, boost and quality code.
- `automaticallyWaitsToMinimizeStalling` stays true.

## Constraints

Core API (only `Foundation`):

```swift
/// ADR 0021 §The stall budget. It has no clock. The caller gives each second.
public struct StallBudget: Equatable, Sendable {
    public static let limitSeconds = 60
    public init()
    /// Counts one second. A second with no satisfied path does not count.
    /// Gives true when the counted seconds reach limitSeconds.
    public mutating func tick(pathSatisfied: Bool) -> Bool
    public var countedSeconds: Int { get }
}

public struct ChimeSetting {
    public static let playedPhaseDelaySeconds = 3
    /// dropSeconds: nil in the start phase, else the seconds since the drop started.
    public static func shouldPlay(state: PlaybackState, enabled: Bool, dropSeconds: Int?) -> Bool
    // The old shouldPlay(state:enabled:) is removed. Update its callers.
}

public struct PlayerScreenModel {
    /// waitingForNetwork: true during a drop with no satisfied path.
    public init(state: PlaybackState, hasSavedStream: Bool, waitingForNetwork: Bool = false)
    // status "Waiting for the network" when waitingForNetwork and state is .connecting.
}
```

Player:

- `RadioPlayer` owns one `NetworkPathMonitor` subscription for its life. It keeps the last `isSatisfied` value. The start value is true.
- A `hasPlayed` flag for the stream that plays. It becomes true at the first `.playing` of that stream. A new **Play**, Stop and a fallback set it to false.
- In the start phase (`hasPlayed` false), each rule of today applies, also the 20-second limit and `streamFailed`.
- In the played phase:
  - A stall, an item failure or an end of the stream starts a drop, if no drop runs. The state is `.connecting`.
  - A drop runs one task. Each second it calls `budget.tick(pathSatisfied:)` and adds one to `dropSeconds`. When `tick` gives true, the drop ends and `streamFailed` runs with the message of today.
  - An item failure or an end of the stream releases the item (new session identifier) and makes a new item for the same stream URL. Start it only while the path is satisfied. If the path is not satisfied, start it at the next satisfied path.
  - When the path becomes satisfied during a drop, call `play()` on the player.
  - At `.playing`, the drop ends: cancel its task, clear `dropSeconds` and the budget.
  - The 20-second limit does not run in the played phase.
- `@Published private(set) var waitingForNetwork: Bool`: true during a drop while the path is not satisfied. `PlayerView` gives it to `PlayerScreenModel`.
- The chime uses `ChimeSetting.shouldPlay(state:enabled:dropSeconds:)`. `dropSeconds` is nil in the start phase. Update the chime when `dropSeconds` changes.
- Each callback keeps the `sessionID` check of today.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`. No blocking work on the main thread. Comments in ASD-STE100. Comments name ADR 0021.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `StallBudget`: 59 ticks with a path give false, and the 60th gives true. 30 ticks with no path then 59 with a path give false, and the next gives true. `countedSeconds` counts only the ticks with a path.
- `ChimeSetting.shouldPlay`: `.connecting` with `dropSeconds` nil gives true. 0 and 2 give false. 3 and 10 give true. `.playing` gives false with each value. Disabled gives false.
- `PlayerScreenModel`: `.connecting` with `waitingForNetwork` true gives "Waiting for the network". With false, it gives "Connecting". `.playing` with true gives "Playing live".
- The existing tests pass, with the callers of the old `shouldPlay` updated.
- `scripts/check.sh` passes. The project ID check prints `missing: []`, and the Swift file reference count equals the Swift file count.

Manual (by the reviewer):

- The two phases.
- The new item for the same stream, and its start at a satisfied path.
- The call to `play()` at a path change.
- No 20-second limit in the played phase.

Visual (on an iPhone): the ADR 0021 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "StallBudgetTests|ChimeSettingTests|PlayerScreenModelTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- The played phase needs a new `PlaybackState` case.
- `playAndWait` or the intents must change.
- A change is necessary in a file in "Do not touch".

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/stall-task-001-stall-budget-and-chime.md
- docs/adr/0021-stalls-on-a-bad-network.md
- the files listed in "Files to inspect"

Goal:
- In the played phase, a drop waits for the network, restarts the same stream when necessary, and fails only after 60 seconds with a network.
- The chime waits 3 seconds in the played phase. The screen shows "Waiting for the network" with no path.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). No blocking work on the main thread. Tests use fixed values.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch".

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
