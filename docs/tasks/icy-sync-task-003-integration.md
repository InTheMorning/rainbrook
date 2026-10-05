# ICY sync task 003: Integration and documents

- Plan: [ICY sync phase plan](../plans/icy-sync-plan.md), wave 2. Model: Opus.
- Decision: [ADR 0011](../adr/0011-icy-sync-of-the-relay-display.md), all sections, and §Changes at implementation.
- Depends on: tasks 001 and 002.

## Goal

`TrackInfoModel` uses `IcySync` when the session has ICY, and keeps the ADR 0008 timed rule without ICY. Remove `RadioPlayer.icyTrack`. Update the documents in the same change.

## Files to inspect

- `docs/adr/0011-icy-sync-of-the-relay-display.md`, `docs/adr/0008-relay-display-metadata.md`
- `CitizenRadio/Core/IcySync.swift`, `CitizenRadio/Core/TrackLines.swift`, `CitizenRadio/Core/DisplayTiming.swift`
- `CitizenRadio/TrackInfoModel.swift`, `CitizenRadio/RadioPlayer.swift`
- `docs/architecture/overview.md`, `docs/runbooks/iphone-setup.md`, `README.md`
- `CitizenRadio.xcodeproj/project.pbxproj` and `docs/tasks/relay-display-task-009-xcode-and-docs.md` (the ID check)

## Files likely to change

- `CitizenRadio/TrackInfoModel.swift`
- `CitizenRadio/RadioPlayer.swift` (remove `icyTrack` only)
- `CitizenRadio.xcodeproj/project.pbxproj` (add `Core/IcySync.swift`)
- `docs/adr/0008-relay-display-metadata.md` (§Display data and §Fallback, a reference to ADR 0011 only)
- `docs/adr/0011-icy-sync-of-the-relay-display.md` (§Changes at implementation, marked done)
- `docs/architecture/overview.md`, `docs/runbooks/iphone-setup.md`, `README.md`
- `docs/plans/icy-sync-plan.md` (status line only)

## Do not touch

- `IcySync`, `IcyMetadataReader` and the other core types, except to call them.
- Playback, chime, audio session, timeout, relay client and artwork loader code.

## Constraints

`TrackInfoModel`:

- Keep a `private var sync = IcySync()`.
- Observe `player.$icyText` in place of `player.$icyTrack`:
  - A nil value: do nothing. The playback stop resets the sync.
  - A text: note if `sync.hasIcy` was false. Call `sync.receiveIcyText(text)`. If this is the first ICY text, cancel all pending timed applies. Then update the lines.
- Each decoded snapshot and streamed state goes to `sync.receive(track)`, with or without ICY.
- With `sync.hasIcy`:
  - Snapshots and streamed states schedule no timed apply. Update the lines from `sync.lines`.
  - `.status(.waiting)` changes nothing (ADR 0011 §The session).
- Without `sync.hasIcy`: keep the present rules. A snapshot applies at once, a streamed state applies after `DisplayTiming.delay`, and `.waiting` clears the relay track.
- `.stopped(.notFound)` and `.stopped(.notReserved)`: call `sync.clearStates()`, and keep the present clear.
- `reloadSettings()` with a changed event: call `sync.clearStates()`.
- Playback stops: set `sync = IcySync()`, with the present clear.
- The lines: with `sync.hasIcy`, use `sync.lines`. Without it, use `TrackLines.select(relay: relayTrack, icy: nil)`.
- The artwork load and Now Playing stay as they are. They follow `lines`.

`RadioPlayer`:

- Remove `icyTrack` and its assignments. Keep `icyText`.

Xcode project:

- Add a `PBXFileReference` and a `PBXBuildFile` for `Core/IcySync.swift`, as in relay display task 009. The ID check must print `missing: []`.

Documents:

- ADR 0008 §Display data, the display delay item: add `With ICY in the session, [ADR 0011](0011-icy-sync-of-the-relay-display.md) replaces this rule.`
- ADR 0008 §Fallback, the backoff item: add "With ICY in the session, backoff keeps the relay track (ADR 0011)."
- ADR 0011 §Changes at implementation: mark each item "Done:".
- Architecture overview: a row for `IcySync`. The ICY flow becomes `AVPlayer ICY metadata -> IcyMetadataReader -> RadioPlayer.icyText -> IcySync in TrackInfoModel`. Change the file count sentence.
- Runbook: add the ADR 0011 visual criteria as rows in the device checks table.
- README: in "Current implementation", the track info bullet says that the relay track shows when the stream title names it.
- Plan status line: "Status: implemented, <date>. The visual checks are open."
- Prose in ASD-STE100. Run the STE checker on each changed document.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`.

## Acceptance criteria

Mechanical:

- `git grep -n "icyTrack" -- CitizenRadio/RadioPlayer.swift CitizenRadio/TrackInfoModel.swift` shows no use of `RadioPlayer.icyTrack`.
- The ID check prints `missing: []`. The `sourcecode.swift` count equals the Swift file count.
- `scripts/check.sh` passes.
- All relative links in the changed documents resolve.

Manual (by the reviewer):

- With ICY in the session, `TrackInfoModel` schedules no timed apply.

Visual (on an iPhone): the ADR 0011 visual criteria. Report them as open.

## Test commands

```sh
git grep -n "icyTrack" -- CitizenRadio/RadioPlayer.swift CitizenRadio/TrackInfoModel.swift
python3 - <<'EOF'
import re
s = open('CitizenRadio.xcodeproj/project.pbxproj').read()
defined = set(re.findall(r'^\s*"([0-9A-F]{24})" = \{', s, re.M))
used = set(re.findall(r'"([0-9A-F]{24})"', s))
print("missing:", sorted(used - defined))
EOF
grep -c sourcecode.swift CitizenRadio.xcodeproj/project.pbxproj
ls CitizenRadio/*.swift CitizenRadio/Core/*.swift | wc -l
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the results
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- `IcySync` or `IcyMetadataReader` needs a change.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.
- The change needs edits to playback, chime, audio session or timeout code.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/icy-sync-task-003-integration.md
- docs/adr/0011-icy-sync-of-the-relay-display.md
- the files listed in "Files to inspect"

Goal:
- Connect IcySync to TrackInfoModel for a session with ICY. Keep the ADR 0008 timed rule without ICY.
- Remove RadioPlayer.icyTrack, and add IcySync.swift to the Xcode project.
- Update the documents.

Constraints:
- Use the exact rules in the task file.
- No @unchecked Sendable or nonisolated(unsafe). Do not change playback, chime, audio session, timeout, relay client or artwork loader code.
- Prose and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- The mechanical criteria in the task file pass. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
