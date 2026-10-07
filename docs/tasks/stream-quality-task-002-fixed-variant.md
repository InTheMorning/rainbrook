# Stream quality task 002: Fixed variant

- Decision: [ADR 0020](../adr/0020-stream-quality-and-hls-live-offset.md) §Stream quality, amended 2026-10-07. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for threading. Model: Opus.
- Depends on: stream quality task 001, diagnosis task 001.

## Goal

High, Medium and Low play one fixed variant of the master playlist. There is no Auto. Medium is the default.

## Files to inspect

- `docs/adr/0020-stream-quality-and-hls-live-offset.md`, `docs/adr/0021-stalls-on-a-bad-network.md`
- `CitizenRadio/Core/StreamQuality.swift`, `Tests/CitizenRadioCoreTests/StreamQualityTests.swift`
- `CitizenRadio/RadioPlayer.swift` (`play`, `startPlayer`, `streamFailed`, `startNewItemIfDue`, `setQuality`, the `streams` list)
- `CitizenRadio/SettingsView.swift` (the quality picker, `save`), `CitizenRadio/Core/StreamSettingsDraft.swift`
- `CitizenRadio/PlaybackLogStore.swift` (`PlaybackDiagnostics.record`)
- The live master playlist: `curl -s https://bastone.heycitizen.xyz/hls/live.m3u8` (lines end with CR LF)

## Files likely to change

- `CitizenRadio/Core/StreamQuality.swift` and its tests
- `CitizenRadio/Core/HLSMasterPlaylist.swift` (new), `Tests/CitizenRadioCoreTests/HLSMasterPlaylistTests.swift` (new)
- `CitizenRadio/RadioPlayer.swift`, `CitizenRadio/SettingsView.swift`
- `CitizenRadio.xcodeproj/project.pbxproj`: one file reference and one build file for `HLSMasterPlaylist.swift`

## Do not touch

- The stall rules of ADR 0021, the live offset, the relay clients, the boost code and the station code.

## Constraints

Core API (only `Foundation`):

```swift
public enum StreamQuality: String, CaseIterable, Equatable, Sendable {
    case high, medium, low              // the picker order. A stored "auto" gives .medium.
    /// The maximum in bits each second. nil means no maximum (high).
    public var maximumBandwidth: Int? { get }    // high nil, medium 120_000, low 64_000
    /// preferredPeakBitRate when the app plays the URL as it is: 0, 120_000, 64_000, 0.
    public var peakBitRate: Double { get }       // 0, 120_000, 64_000
    public var label: String { get }             // "High", "Medium", "Low"
}
// StreamQualitySetting: the default becomes .medium. A stored value that is not a case gives .medium.

public struct HLSVariant: Equatable, Sendable {
    public let bandwidth: Int
    public let url: URL
}

public enum HLSMasterPlaylist {
    /// The variants of a master playlist, in file order. Each `#EXT-X-STREAM-INF` line with a
    /// whole-number BANDWIDTH and a URI on the next non-comment line gives one variant.
    /// A relative URI resolves against `baseURL`. Lines can end with CR LF.
    /// Gives an empty list for a text that is not a master playlist.
    public static func variants(in text: String, baseURL: URL) -> [HLSVariant]
    /// The variant for the quality: high, the highest bandwidth. medium and low, the highest
    /// bandwidth at or below the maximum, else the lowest bandwidth. An empty list gives nil.
    public static func select(_ quality: StreamQuality, from variants: [HLSVariant]) -> HLSVariant?
}
```

Player:

- At **Play**, in the existing task that activates the audio session (off the main actor for the network read), resolve each stream of the station:
  - Read the URL with `URLSession` and a time limit of 5 seconds. The reads of the streams run at the same time. If the status is 200 and `variants(in:baseURL:)` gives variants, use the URL of `select`. Else keep the URL.
  - Read the streams one after the other. A failure of one read only keeps that URL.
- Keep the resolved list for the session in place of `streams`. The fallback of ADR 0017 and each new item of ADR 0021 use it.
- `preferredPeakBitRate` on each item: 0 when the item plays a selected variant. Else `quality.peakBitRate`.
- Record each result with `PlaybackDiagnostics.record`: "Variant: stream N, <bandwidth>" or "Variant: stream N, as it is". No URL.
- Remove `setQuality(_:)` and its call. A change of the setting applies at the next **Play**.

Settings:

- The picker shows High, Medium and Low. The footer text: "High, Medium and Low each play one fixed bitrate, with no jumps after a network gap. A change applies at the next Play. This applies to HLS streams." Keep the chime sentence and the HLS buffer sentences.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`. No blocking work on the main thread. Comments in ASD-STE100. Comments name ADR 0020.

## Acceptance criteria

Mechanical. Each item is a test with fixed values:

- `variants(in:baseURL:)`: the live master text of 2026-10-07 with CR LF gives three variants: 140800 `…/aac.m3u8`, 52800 `…/aac_low.m3u8`, 105600 `…/aac_mid.m3u8`. A relative URI resolves against the base. A media playlist text gives an empty list. A `#EXT-X-STREAM-INF` line with no BANDWIDTH is skipped.
- `select`: with those three, high gives 140800, medium 105600, low 52800. Medium with only 140800 gives 140800. An empty list gives nil.
- `StreamQuality`: the four `maximumBandwidth`, `peakBitRate` and `label` values, and the case order.
- `StreamQualitySetting`: the default is `.medium`. A stored `"low"` gives `.low`. A stored `"auto"` and a stored `"bad"` give `.medium`.
- `scripts/check.sh` passes. The project ID check prints `missing: []`, and the Swift file reference count equals the Swift file count.

Manual (by the reviewer): the read is off the main actor, a failure keeps the URL, the fallback and the new items use the resolved list, and no URL is logged.

Visual (on an iPhone): with Medium, a network gap of 15 seconds on HLS gives no jump, and the server log shows only `aac_mid` requests.

## Test commands

```sh
swift test --build-system native --filter "StreamQualityTests|HLSMasterPlaylistTests|StreamSettingsDraftTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- A change is necessary in a file in "Do not touch".
- The resolve step cannot run before `startPlayer` with no change to the start phase of ADR 0021.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/stream-quality-task-002-fixed-variant.md
- docs/adr/0020-stream-quality-and-hls-live-offset.md
- the files listed in "Files to inspect"

Goal:
- High, Medium and Low play one fixed variant of the master playlist. There is no Auto. Medium is the default.

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
