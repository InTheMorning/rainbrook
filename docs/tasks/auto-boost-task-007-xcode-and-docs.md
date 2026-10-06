# Auto-boost task 007: Xcode project and documents

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave 5. Model: Sonnet.
- Decision: [ADR 0012](../adr/0012-auto-boost.md).
- Depends on: task 006.

## Goal

Add the new Swift files to the Xcode project. Document auto-boost in the architecture overview, the README and the runbook.

## Files to inspect

- `CitizenRadio.xcodeproj/project.pbxproj`
- `docs/tasks/relay-display-task-009-xcode-and-docs.md` (the same work, with the ID check)
- `docs/architecture/overview.md`, `README.md`, `docs/runbooks/iphone-setup.md`
- `docs/adr/0012-auto-boost.md`, `docs/plans/auto-boost-plan.md`

## Files likely to change

- `CitizenRadio.xcodeproj/project.pbxproj`
- `docs/architecture/overview.md`, `README.md`, `docs/runbooks/iphone-setup.md`
- `docs/plans/auto-boost-plan.md` (status line only)

## Do not touch

- All Swift sources, tests, plists, `Package.swift` and the ADRs.

## Constraints

Xcode project: as in relay display task 009. Each Swift file in `CitizenRadio/` and `CitizenRadio/Core/` gets one file reference and one build file in the Sources phase. New unique 24-character uppercase hexadecimal IDs in the quoted style.

Documents:

- Architecture overview: a row in the components table for each new type, with one sentence. Add the flows:
  - `relay /events (remoteValue) -> EventStreamClient -> BoostModel (BoostPairing)`
  - `ICY text -> TrackInfoModel -> BoostModel (BoostTrigger) -> BoostPlan -> BoostPayer -> NWCClient and LNURL`
  - Change the file count sentence.
- README: one bullet in "Current implementation" for auto-boost. The document list already has ADR 0012 and the plan.
- Runbook: a "Configure auto-boost" procedure: connect a wallet, open **Settings**, set **Auto-boost** on, select **Boost amount**, examine the daily limit, tap **Save**. Add the ADR 0012 visual criteria as rows in the device checks table.
- Plan status line: "Status: implemented, <date>. The visual checks are open."
- Prose in ASD-STE100. Run the STE checker on each changed document.

## Acceptance criteria

Mechanical:

- The ID check prints `missing: []`.
- The number of `sourcecode.swift` file references equals the number of Swift files in `CitizenRadio/` and `CitizenRadio/Core/`.
- `scripts/check.sh` passes.
- All relative links in the changed documents resolve.

Visual (by a person with a Mac):

- `scripts/generate-app-intents-metadata.sh` builds the Xcode project. Report it as open.

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

- The project file uses a structure that relay display task 009 did not meet.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-007-xcode-and-docs.md
- docs/tasks/relay-display-task-009-xcode-and-docs.md
- CitizenRadio.xcodeproj/project.pbxproj
- docs/architecture/overview.md, README.md, docs/runbooks/iphone-setup.md

Goal:
- Register the new Swift files in the Xcode project, and document auto-boost.

Constraints:
- Follow the project file rules in the task file. New unique 24-character IDs in the quoted style.
- Documents in ASD-STE100. Change only the listed documents.
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
