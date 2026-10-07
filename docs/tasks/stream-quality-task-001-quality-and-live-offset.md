# Stream quality task 001: Quality setting and HLS live offset

- Decision: [ADR 0020](../adr/0020-stream-quality-and-hls-live-offset.md). Model: Sonnet.
- Depends on: none.

## Goal

Add the **Stream quality** setting, and set the bitrate maximum and the live offset on each player item.

## Files to inspect

- `docs/adr/0020-stream-quality-and-hls-live-offset.md`
- `CitizenRadio/Core/ChimeSetting.swift` (the pattern for a `UserDefaults` setting)
- `CitizenRadio/RadioPlayer.swift` (`startPlayer`)
- `CitizenRadio/SettingsView.swift`, `CitizenRadio/Core/StreamSettingsDraft.swift` and its tests

## Files likely to change

- `CitizenRadio/Core/StreamQuality.swift` (new), `Tests/CitizenRadioCoreTests/StreamQualityTests.swift` (new)
- `CitizenRadio/Core/StreamSettingsDraft.swift` and its tests
- `CitizenRadio/RadioPlayer.swift`, `CitizenRadio/SettingsView.swift`
- `CitizenRadio.xcodeproj/project.pbxproj`: one file reference and one build file for `StreamQuality.swift`, as the other Core files have

## Do not touch

- The fallback of ADR 0017, the connection time limit, the relay clients, the boost code and the station code.

## Constraints

Core API (only `Foundation`):

```swift
public enum StreamQuality: String, CaseIterable, Equatable, Sendable {
    case auto, medium, low
    /// The maximum in bits each second for preferredPeakBitRate. 0 means no maximum.
    public var peakBitRate: Double { get }   // auto 0, medium 120_000, low 64_000
    /// The text in Settings: "Auto", "Medium", "Low".
    public var label: String { get }
}

public struct StreamQualitySetting {
    public init(defaults: UserDefaults = .standard)
    /// The default is .auto. A stored value that is not a case gives .auto.
    public var quality: StreamQuality { get nonmutating set }
}
```

Player:

- In `startPlayer`, before `play()`, set on the new item: `preferredPeakBitRate` from `StreamQualitySetting().quality.peakBitRate`, `configuredTimeOffsetFromLive = CMTime(seconds: 30, preferredTimescale: 1)` and `automaticallyPreservesTimeOffsetFromLive = true`. This applies to the primary stream and to the alternate stream.
- `func setQuality(_ quality: StreamQuality)` sets `preferredPeakBitRate` on the current item, if there is one.

Settings:

- A **Stream quality** picker with Auto, Medium and Low, in the section of the chime toggle. The footer text: "Auto selects the bitrate for the network. Low uses less data. This applies to HLS streams."
- The picker value is part of `StreamSettingsDraft`, and **Save** stores it with the other settings. After **Save**, call `player.setQuality(_:)`.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100. Comments name ADR 0020.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `peakBitRate`: auto 0, medium 120,000, low 64,000. `label` for each case.
- `StreamQualitySetting`: the default is `.auto`. A stored `"low"` gives `.low`. A stored `"bad"` gives `.auto`.
- The draft: a change of the quality makes `canSave` true, and a change back to the saved value makes it false.
- `scripts/check.sh` passes. The Xcode project ID check prints `missing: []`, and the Swift file reference count equals the Swift file count.

Manual (by the reviewer): the three item properties in `startPlayer`, and `setQuality` on the current item.

Visual (on an iPhone): the ADR 0020 visual criteria. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "StreamQualityTests|StreamSettingsDraftTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- A property is not available on iOS 17.
- A change is necessary in a file in "Do not touch".

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/stream-quality-task-001-quality-and-live-offset.md
- docs/adr/0020-stream-quality-and-hls-live-offset.md
- the files listed in "Files to inspect"

Goal:
- Add the Stream quality setting, and set the bitrate maximum and the live offset on each player item.

Constraints:
- Use the exact API and rules in the task file. Core files import only Foundation.
- No @unchecked Sendable or nonisolated(unsafe). Tests use fixed values.
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
