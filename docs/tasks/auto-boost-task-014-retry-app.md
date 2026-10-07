# Auto-boost task 014: Automatic and manual retry in the app

- Decision: [ADR 0016](../adr/0016-boost-switch-back-play-time-and-retry.md) §The retry and §The limits of a retry. Model: Opus.
- Depends on: task 012 and task 013.

## Goal

The app sends the retryable parts of a boost again after 1 minute and after 10 more minutes. The history screen shows the failure reason of each part, and a **Retry** button.

## Files to inspect

- `docs/adr/0016-boost-switch-back-play-time-and-retry.md`, `docs/adr/0013-boosts.md` §The limits
- `CitizenRadio/BoostModel.swift`, `CitizenRadio/BoostHistoryView.swift`, `CitizenRadio/TrackInfoModel.swift` (how the history reaches the view)
- `CitizenRadio/Core/BoostHistory.swift`, `CitizenRadio/Core/BoostPayer.swift` (the API of task 013)
- `CitizenRadio/Core/BoostStatusText.swift`

## Files likely to change

- `CitizenRadio/BoostModel.swift`, `CitizenRadio/BoostHistoryView.swift`
- `CitizenRadio/Core/BoostStatusText.swift` and `Tests/CitizenRadioCoreTests/BoostStatusTextTests.swift` (only the retry text)
- `CitizenRadio/TrackInfoModel.swift` or `CitizenRadio/SettingsView.swift`, only if the history view needs the model to start a retry

## Do not touch

- The trigger, the plan, the payer, the history core and the settings. Tasks 012 and 013 own them.

## Constraints

`BoostModel`:

- `@Published private(set) var retryingEntries: Set<UUID>`.
- `func retry(entryID: UUID) async`: the manual retry. It does nothing when the entry has no retryable part or a retry of it runs.
- After `addHistoryEntry` of an auto-boost or a manual boost with a retryable part, start the automatic retry in a task:
  1. Wait 60 seconds with `Task.sleep`. Send the retryable parts again.
  2. If a part is still retryable, wait 600 seconds more and send again. Then stop.
  - If a manual retry of the entry runs at the time of an automatic retry, skip that attempt.
- One shared private path does each retry:
  - Find the entry in `history` by id. Add the id to `retryingEntries`. Remove it with `defer`.
  - Automatic retry of an `.auto` entry: check `entry.retryableSats` with `SpendingLimitStore().limit.recording(reservedSats, on: day).permits(_:on:)`. If it does not fit, set the status to the over-limit text and stop the automatic retries of that entry.
  - Add `entry.retryableSats` to `reservedSats` and remove it with `defer`, as `pay` does.
  - No wallet: set the status to `BoostStatusText.noWallet` and stop.
  - Make one `NWCClient` and one `BoostPayer`, as `pay` does, and call `payer.retry(parts:)`.
  - Record in `SpendingLimitStore` the confirmed and unknown sats of the parts that changed in this retry, not the full entry.
  - Update the entry in `history` on the main actor, then call `historyStore.update(_:)`.
  - Set `status` to `BoostStatusText.retryText(for: BoostResult(parts: newParts))`.
- The automatic retry tasks are not canceled at the end of a session. They stop when the app ends.
- Log only the counts and the attempt number, in the `boost` category.

`BoostStatusText.retryText(for result: BoostResult) -> String`: "Retry: " followed by `text(for: result)`.

`BoostHistoryView`:

- Each failed part shows `BoostHistoryText.reason(for:)` below it, in the secondary style.
- A part with attempts more than 1 shows "\(attempts) attempts".
- An entry with `hasRetryableParts` shows a **Retry** button. It is not active while `retryingEntries` contains the entry. A tap calls `retry(entryID:)` in a task.

Other:

- Threading: `BoostModel` stays `@MainActor`. The Keychain read, the NWC payments, the LNURL requests and the file write stay off the main actor, as now.
- No `@unchecked Sendable` and no `nonisolated(unsafe)`. Comments in ASD-STE100.

## Acceptance criteria

Mechanical:

- `retryText` has a test with a fixed value.
- `scripts/check.sh` passes.

Manual (by the reviewer):

- The schedule of 60 seconds, then 600 seconds.
- One retry for each entry at a time.
- The limit check of an automatic retry of an auto-boost.
- The spending record of only the changed parts.

Visual (on an iPhone): the ADR 0016 items for the reason, the automatic retry and **Retry**. Report them as open.

## Test commands

```sh
swift test --build-system native --filter "BoostStatusTextTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- The history view cannot reach `BoostModel` with no change to a file outside "Files likely to change".
- A retry needs a change to the core API of task 013.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-014-retry-app.md
- docs/adr/0016-boost-switch-back-play-time-and-retry.md
- the files listed in "Files to inspect"

Goal:
- Send the retryable parts again after 1 minute and after 10 more minutes.
- Show the failure reason of each part and a Retry button in the history.

Constraints:
- Use the exact rules in the task file. BoostModel stays @MainActor and does no blocking work.
- No @unchecked Sendable or nonisolated(unsafe).
- Comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file in "Do not touch", and any file that is not in "Files likely to change".

Acceptance criteria:
- retryText has a passing test. scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
