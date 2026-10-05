# Relay display task 006: ICY title reader

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 2. Model: Sonnet.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Fallback: the ICY title, §Invariants. [ADR 0006](../adr/0006-audio-session-off-main-thread.md) for blocking calls.
- Depends on: task 001.

## Goal

Read the Icecast `StreamTitle` from the playing stream, parse it with `IcyTitle`, and publish it as `RadioPlayer.icyTrack`.

## Files to inspect

- `CitizenRadio/RadioPlayer.swift` (`startPlayer(url:expectedID:)`, `releasePlayer()`, `sessionID`)
- `CitizenRadio/Core/IcyTitle.swift`

## Files likely to change

- `CitizenRadio/IcyMetadataReader.swift` (new, iOS only)
- `CitizenRadio/RadioPlayer.swift`

## Do not touch

- All other files. In `RadioPlayer.swift`, change only what this packet names. Do not change playback, the buffer, the chime or the audio session code.

## Constraints

App API:

```swift
#if os(iOS)
final class IcyMetadataReader: NSObject, AVPlayerItemMetadataOutputPushDelegate, Sendable {
    init(onTrack: @escaping @Sendable (IcyTrack?) -> Void)
    /// Adds an AVPlayerItemMetadataOutput to the item, with this reader as its delegate on a private serial queue.
    func attach(to item: AVPlayerItem)
}
#endif
```

Reader rules:

- Make `AVPlayerItemMetadataOutput(identifiers: nil)`, call `setDelegate(self, queue:)` with a private serial `DispatchQueue`, and add it to the item.
- In `metadataOutput(_:didOutputTimedMetadataGroups:from:)`, look for an item with the identifier `.icyMetadataStreamTitle`. If none, use an item with the common key `.commonKeyTitle`.
- Read its text with `try await item.load(.stringValue)` in a `Task`. Do not use the deprecated `stringValue` property.
- Call `onTrack(IcyTitle.parse(text))`. A missing text gives `onTrack(nil)`.
- The class has only `let` properties.

`RadioPlayer` changes:

- Add `@Published private(set) var icyTrack: IcyTrack?`.
- Add `private var icyReader: IcyMetadataReader?`.
- In `startPlayer(url:expectedID:)`, make a reader whose `onTrack` closure hops to the main actor and sets `icyTrack` only if `sessionID == expectedID`. Attach it to the new item, and keep it in `icyReader`.
- In `releasePlayer()`, set `icyReader` to nil and `icyTrack` to nil.

Threading:

- The delegate runs on the private queue. Only the parsed `IcyTrack` goes to the main actor.

Other constraints:

- No log of the title text.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- The new file starts with `#if os(iOS)` and imports `CitizenRadioCore` inside `#if SWIFT_PACKAGE`.
- Prose and comments in ASD-STE100.

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes, so the reader and the `RadioPlayer` change compile with the iOS SDK in Swift 6 mode.
- `AudioSessionThreadTests` still passes.
- `IcyMetadataReader.swift` does not use the `stringValue` property directly.

Visual (on an iPhone, after task 008):

- With an empty **Track info** field, the title and artist of the playing track show, from the stream title.

## Test commands

```sh
grep -n "\.stringValue" CitizenRadio/IcyMetadataReader.swift
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

The `grep` must show only `load(.stringValue)`.

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- Swift 6 rejects the delegate conformance or the `Sendable` class without `@unchecked`.
- The change needs edits to playback or audio session code in `RadioPlayer`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-006-icy-reader.md
- CitizenRadio/RadioPlayer.swift
- CitizenRadio/Core/IcyTitle.swift

Goal:
- Add IcyMetadataReader, and publish the parsed ICY title as RadioPlayer.icyTrack.

Constraints:
- Use the exact API and rules in the task file. The delegate runs on a private queue. Only the parsed result goes to the main actor.
- Change RadioPlayer only as the packet names. Do not change playback, buffer, chime or audio session code.
- No log of the title. No @unchecked Sendable or nonisolated(unsafe).
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- scripts/check.sh passes. No direct use of the stringValue property.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
