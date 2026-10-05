# ICY sync task 002: The ICY text from the reader

- Plan: [ICY sync phase plan](../plans/icy-sync-plan.md), wave 1. Model: Sonnet.
- Decision: [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md) §The ICY text.
- Depends on: none.

## Goal

`IcyMetadataReader` gives the raw ICY text, and only for a group with a `StreamTitle` item. `RadioPlayer` publishes that text. Remove the ICY timing log.

## Files to inspect

- `CitizenRadio/IcyMetadataReader.swift`
- `CitizenRadio/RadioPlayer.swift` (the reader in `startPlayer`, `releasePlayer`)

## Files likely to change

- `CitizenRadio/IcyMetadataReader.swift`
- `CitizenRadio/RadioPlayer.swift`

## Do not touch

- All other files. Do not change playback, the chime, the audio session, Now Playing or the connection timeout.

## Constraints

Reader API:

```swift
final class IcyMetadataReader: NSObject, AVPlayerItemMetadataOutputPushDelegate, Sendable {
    /// Creates a reader. The reader calls `onText` once for each group with a StreamTitle item.
    init(onText: @escaping @Sendable (String) -> Void)
    func attach(to item: AVPlayerItem)
}
```

Reader rules:

- Find the title item as now: the `.icyMetadataStreamTitle` identifier, else the `.commonKeyTitle` common key.
- A group with no title item: do nothing. Do not call `onText`.
- A title item: read it with `try await item.load(.stringValue)`. A nil value or a load error gives `""`. Call `onText` with the text.
- Keep the `sending` parameter and the `Task` from the present code. It is how the code compiles in Swift 6.
- Remove `timingLog`, its `os` import if nothing else uses it, and each log call.

`RadioPlayer` changes:

- Add `@Published private(set) var icyText: String?`. Nil means no ICY text in this session.
- The reader callback sets, on the main actor, with the present session guard: `icyText = text` and `icyTrack = IcyTitle.parse(text)`.
- Keep `icyTrack` in this task, because `TrackInfoModel` uses it. Task 003 removes it.
- `releasePlayer()` sets `icyText` and `icyTrack` to nil.
- Remove the ICY timing log line in the reader callback.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`.
- Comments in ASD-STE100.

## Acceptance criteria

Mechanical:

- `git grep -n "timingLog\|icy-timing" -- CitizenRadio` prints nothing.
- `scripts/check.sh` passes, so the files compile in Swift 6 mode.

Manual (by the reviewer, because a Linux test cannot examine AVFoundation types):

- A group with no title item does not call `onText`.
- An empty title calls `onText("")`.

## Test commands

```sh
git grep -n "timingLog\|icy-timing" -- CitizenRadio || echo "no timing log"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the results
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- Swift 6 rejects the reader without `@unchecked Sendable` or `nonisolated(unsafe)`.
- The change needs edits outside the reader callback, `releasePlayer()` and the new property.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/icy-sync-task-002-icy-text.md
- CitizenRadio/IcyMetadataReader.swift
- CitizenRadio/RadioPlayer.swift

Goal:
- The reader gives the raw ICY text only for a group with a StreamTitle item. RadioPlayer publishes icyText. Remove the ICY timing log.

Constraints:
- Use the exact API and rules in the task file. Keep the sending parameter and the Task.
- No @unchecked Sendable or nonisolated(unsafe). Do not change playback, chime, audio session, Now Playing or timeout code.
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- No timing log remains. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
