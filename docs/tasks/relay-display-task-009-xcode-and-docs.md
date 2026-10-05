# Relay display task 009: Xcode project and documentation

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 5. Model: Sonnet.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md), and ADR 0009, which task 008 writes.
- Depends on: task 008.

## Goal

Add the new Swift files to the Xcode project. Update the architecture overview, the README and the runbook for the track info feature.

## Files to inspect

- `CitizenRadio.xcodeproj/project.pbxproj`
- `docs/tasks/nwc-wallet-task-011-xcode-and-docs.md` (the same work for the wallet, with the ID check)
- `docs/architecture/overview.md`, `README.md`, `docs/runbooks/iphone-setup.md`
- `docs/adr/0008-relay-display-metadata.md`, `docs/adr/0009-player-screen-with-track-info.md`, `docs/plans/relay-display-phase-plan.md`

## Files likely to change

- `CitizenRadio.xcodeproj/project.pbxproj`
- `docs/architecture/overview.md`, `README.md`, `docs/runbooks/iphone-setup.md`
- `docs/plans/relay-display-phase-plan.md` (status line only)

## Do not touch

- All Swift sources, tests, plists, `Package.swift` and the ADRs.

## Constraints

Xcode project:

- Find each Swift file in `CitizenRadio/` and `CitizenRadio/Core/` that has no file reference in the project. The counts in "Test commands" show the difference.
- For each such file, add a `PBXFileReference` and a `PBXBuildFile` in the Sources phase.
- Add the file references to the `CitizenRadio` group. Paths of core files start with `Core/`.
- No new package is necessary. Do not change the package references.
- Use new unique 24-character uppercase hexadecimal IDs in the existing quoted style.

Documentation:

- Architecture overview: a row in the components table for each new type, with one sentence. Add the display flow to the data flow:
  `relay /display/events -> EventStreamClient -> TrackInfoModel -> PlayerView and Now Playing`, and `AVPlayer ICY metadata -> IcyMetadataReader -> RadioPlayer.icyTrack -> TrackInfoModel`. Change the file count sentence.
- README: one bullet in "Current implementation" for the track info.
- Runbook: a "Configure track info" procedure: paste the station relay address into **Track info**, tap **Save**, tap **Play**. Add the ADR 0008 visual criteria as rows in the device checks table.
- Plan status line: "Status: implemented, <date>. The visual checks are open."
- Prose in ASD-STE100. Run the STE checker on each changed document.

## Acceptance criteria

Mechanical:

- The ID check prints `missing: []`.
- The number of `sourcecode.swift` file references equals the number of Swift files in `CitizenRadio/` and `CitizenRadio/Core/`.
- `scripts/check.sh` passes.
- All relative links in the changed documents resolve.

Visual (by a person with a Mac):

- `scripts/generate-app-intents-metadata.sh` on a Mac builds the Xcode project. Report this item as open until the friend runs it.

## Test commands

```sh
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
python3 "$HOME/.agents/skills/asd-ste100/scripts/ste_lint.py" --check --no-heuristics README.md docs/architecture/overview.md docs/runbooks/iphone-setup.md
```

## Expected final summary format

1. files changed
2. tests run, with the results
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open Mac check

## Escalation triggers

- The project file uses a structure that the wallet task 011 did not meet.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-009-xcode-and-docs.md
- docs/tasks/nwc-wallet-task-011-xcode-and-docs.md
- CitizenRadio.xcodeproj/project.pbxproj
- docs/architecture/overview.md, README.md, docs/runbooks/iphone-setup.md

Goal:
- Register the new Swift files in the Xcode project, and update the documentation for the track info feature.

Constraints:
- Follow the project file rules in the task file. New unique 24-character IDs in the quoted style.
- Documentation in ASD-STE100. Change only the listed documents.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Swift sources, tests, plists, Package.swift, the ADRs.

Acceptance criteria:
- The ID check prints no missing ID. The Swift file reference count equals the Swift file count.
- scripts/check.sh passes. All relative links resolve.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
