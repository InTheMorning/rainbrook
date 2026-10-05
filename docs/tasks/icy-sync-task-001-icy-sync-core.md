# ICY sync task 001: The IcySync core type

- Plan: [ICY sync phase plan](../plans/icy-sync-plan.md), wave 1. Model: Sonnet.
- Decision: [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md) §The list and the selection, §Matching.
- Depends on: none.

## Goal

Add `IcySync` to `CitizenRadioCore`. It keeps the display states and selects the track that the ICY text names. Test each ADR 0011 rule on Linux.

## Files to inspect

- `docs/adr/0011-icy-sync-of-the-relay-display.md`
- `CitizenRadio/Core/TrackDisplay.swift`, `CitizenRadio/Core/IcyTitle.swift`, `CitizenRadio/Core/TrackLines.swift`
- `Tests/CitizenRadioCoreTests/TrackLinesTests.swift` (the test style)

## Files likely to change

- `CitizenRadio/Core/IcySync.swift` (new)
- `Tests/CitizenRadioCoreTests/IcySyncTests.swift` (new)

## Do not touch

- All other files.

## Constraints

Use exactly this API. The file imports only `Foundation`.

```swift
/// ADR 0011: display states are early, and the ICY text releases them.
public struct IcySync: Equatable, Sendable {
    public static let capacity = 4
    public static let minimumPrefixCharacters = 8

    public init()

    /// True after the first ICY text, also an empty one.
    public private(set) var hasIcy: Bool
    /// The newest state whose key matches the ICY text, or nil.
    public private(set) var relayTrack: TrackDisplay?
    /// The parsed ICY text, or nil for an empty text or before the first ICY text.
    public private(set) var icyTrack: IcyTrack?

    /// TrackLines.select(relay: relayTrack, icy: icyTrack)
    public var lines: TrackLines { get }

    /// Adds a display state from the snapshot or the stream. A nil state (`{"track": null}`) is not added.
    public mutating func receive(_ track: TrackDisplay?)
    /// Sets the ICY text from a StreamTitle item. An empty text is a valid input.
    public mutating func receiveIcyText(_ text: String)
    /// Removes all display states. The ICY text stays.
    public mutating func clearStates()

    /// Trims, changes each run of white space to one space, applies Unicode NFC, and lowercases.
    public static func normalize(_ text: String) -> String
    /// normalize("\(artist) - \(title)")
    public static func key(of track: TrackDisplay) -> String
}
```

Rules:

- The list holds a maximum of `capacity` states, newest first. A new state with a key equal to an older state replaces the older state, and goes to the front.
- After each call to `receive`, `receiveIcyText` and `clearStates`, select again:
  - Before the first ICY text: `relayTrack` and `icyTrack` are nil.
  - An ICY text that is empty after `normalize`: `relayTrack` and `icyTrack` are nil.
  - Else `icyTrack = IcyTitle.parse(text)`, and `relayTrack` is the selection below.
- Selection for a normalized ICY text `t`:
  1. The newest state with `key == t`.
  2. Else, only if `t.count >= minimumPrefixCharacters` and `t` has a minimum of one character after its first `" - "`: the newest state whose key starts with `t`.
  3. Else nil.
- Use `precomposedStringWithCanonicalMapping` for NFC, and `lowercased()` for the case.
- No time, no I/O, no logging.
- Comments in ASD-STE100.

## Acceptance criteria

Mechanical. Each item is a test in `IcySyncTests.swift`:

- Before the first ICY text, `hasIcy` is false and `relayTrack` is nil, also with states in the list.
- A state that arrives before its ICY text is not the relay track until the ICY text names it.
- A state that arrives after its ICY text is the relay track immediately.
- An empty ICY text gives nil `relayTrack` and nil `icyTrack`, also with a matching state in the list. `hasIcy` is true.
- `receive(nil)` does not clear the relay track while the ICY text names it.
- An ICY text with no matching state gives nil `relayTrack` and the parsed `icyTrack`.
- Case, white space and NFC differences match. Use `"e\u{301}"` and `"\u{e9}"` for NFC.
- Prefix: `"Miles Davis - Pharaoh"` matches the key of `Miles Davis` / `Pharaoh's Dance`. `"Miles - P"` (9 characters) matches its full key. A text of 7 characters does not match by prefix.
- Prefix: `"HeyCitizen - "` and `"HeyCitizen"` do not match the key of `HeyCitizen` / `How Bout You?`.
- An exact match wins over a prefix match.
- The list keeps 4 states. After 5 different states, the first state no longer matches.
- A newer state with an equal key replaces the older state: the relay track is the newer state, with its artwork.
- `clearStates()` gives nil `relayTrack` and keeps `icyTrack`.
- `scripts/check.sh` passes.

## Test commands

```sh
swift test --build-system native --filter IcySyncTests
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- A rule in ADR 0011 conflicts with this API.
- `precomposedStringWithCanonicalMapping` is not available on Linux.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/icy-sync-task-001-icy-sync-core.md
- docs/adr/0011-icy-sync-of-the-relay-display.md
- CitizenRadio/Core/TrackDisplay.swift, CitizenRadio/Core/IcyTitle.swift, CitizenRadio/Core/TrackLines.swift
- Tests/CitizenRadioCoreTests/TrackLinesTests.swift

Goal:
- Add IcySync with the exact API and rules in the task file, and a test for each acceptance criterion.

Constraints:
- Only Foundation. No time, no I/O, no logging.
- Tests use fixed values. A test must not repeat the calculation of the code.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter IcySyncTests
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
