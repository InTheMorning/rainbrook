# Auto-boost task 010: Manual boost, history writes and history screen

- Plan: [auto-boost phase plan](../plans/auto-boost-plan.md), wave C. Model: Opus.
- Decision: [ADR 0013](../adr/0013-boosts.md) §Manual boost, §The limits, §The history. [ADR 0014](../adr/0014-player-screen-with-boost-button.md) for the Boost button.
- Depends on: tasks 007 to 009.

## Goal

Add the Boost button and the boost sheet. Write each boost to the history. Add the history screen to Settings.

## Files to inspect

- `docs/adr/0013-boosts.md`, `docs/adr/0014-player-screen-with-boost-button.md`
- `CitizenRadio/BoostModel.swift`, `CitizenRadio/TrackInfoModel.swift`, `CitizenRadio/PlayerView.swift`, `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift`
- `CitizenRadio/Core/BoostPlan.swift`, `BoostPayer.swift`, `BoostHistory.swift`, `BoostSettings.swift`, `BoostStatusText.swift`
- `docs/reviews/relay-display-review-checklist.md` §4

## Files likely to change

- `CitizenRadio/BoostModel.swift`
- `CitizenRadio/BoostSheet.swift` (new)
- `CitizenRadio/BoostHistoryView.swift` (new)
- `CitizenRadio/PlayerView.swift`, `CitizenRadio/SettingsView.swift`, `CitizenRadio/WalletSettingsView.swift`
- `CitizenRadio/TrackInfoModel.swift` (only if a new call is necessary)

## Do not touch

- The core types, except to call them.
- Playback, chime, audio session, ICY sync and the relay clients.

## Constraints

`BoostModel` changes:

- Keep the present track: `selectedTrack(_:)` also stores the track, also nil, as `currentTrack`.
- `@Published private(set) var manualTarget: TrackDisplay?`: `currentTrack` when `pairing.payload(for:)` gives a payable payload, else nil. Update it after `selectedTrack`, `payload` and `sessionEnded`.
- `func sendManualBoost(amountSats: Int, message: String) async -> String`:
  1. `BoostPlan.decideManual(amountSats:track: manualTarget, pairing:)`. A skip gives its `BoostStatusText` text, or "No boost. No V4V track plays." when the text is nil.
  2. A sender from `BoostSender(settings:)`, with the message of the sheet (an empty message gives nil).
  3. Add `amountSats` to `reservedSats` while it pays, as auto-boost does, so an auto-boost at the same time counts it.
  4. Pay as auto-boost does, record `paidSats + unknownSats` in `SpendingLimitStore`, write a history entry, and give `BoostStatusText.text(for:)`.
- History:
  - `init` gets `history: any BoostHistoryStoring = BoostHistoryFileStore(fileURL: <Application Support>/CitizenRadio/boost-history.json)`. Make the URL with `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)`.
  - After each paid auto-boost and each manual boost that reached the payer, add an entry: the date, the kind, the relay track title and artist, the amount, the message, and `result.parts`. A skipped boost gives no entry.
  - `@Published private(set) var history: [BoostHistoryEntry]`. Load it in a task at `init`, and set it from the value that `add` gives.
- The history store is an actor, so its file work is off the main actor.

Boost button and sheet:

- `PlayerView`: a **Boost** button with the SF Symbol `bolt.heart` and the label "Boost", identifier `boostButton`, in the control row near the AirPlay button. It is disabled when `trackInfo.boost.manualTarget` is nil.
- The button opens `BoostSheet` with `.sheet(isPresented:)` on the button or on the control row, not on a `Section`.
- `BoostSheet`: a `NavigationStack` with a `Form`:
  - The track title and artist of `manualTarget`, read-only.
  - `TextField("Amount", text:)` with `.keyboardType(.numberPad)`, prefilled with `BoostSettings().amountSats`, and "sats" after it. Invalid text shows "Enter 1 to 100,000 sats." in red.
  - `TextField("Message", text:, axis: .vertical)`, empty, cut to `BoostSettings.maxMessageLength` characters.
  - **Send**, identifier `sendBoostButton`. It is disabled while the amount is not valid, or while a boost sends. While it sends, show a `ProgressView`.
  - After the result, show the result text, and change **Send** to **Done**, which closes the sheet.
  - **Cancel** in the toolbar closes the sheet. A boost that started continues.
  - The sheet keeps the track of the moment that it opened. If `manualTarget` changes while the sheet is open, the sheet does not change.

History screen:

- `WalletSettingsView`, when a wallet is connected: `NavigationLink("Boost history")` to `BoostHistoryView`, identifier `boostHistoryLink`. Give it `trackInfo.boost.history` through `SettingsView`, in the style of `boostStatus`.
- `BoostHistoryView`: a `List`. Each row: the title, the date and time (`.dateTime`), "Auto-boost" or "Boost", and `BoostHistoryText.summary(for:)`. No entry: the text "No boosts yet."
- A row opens a detail view: the title and artist, the amount, the message if there is one, and each part: the name (or "Recipient"), "Keysend" or "Lightning address", the sats, and `BoostHistoryText.label(for:)`.

Other:

- No `@unchecked Sendable` and no `nonisolated(unsafe)`. No log of a title or a message.
- No `.sheet`, `.alert`, `.confirmationDialog` or `.fullScreenCover` on a `Section`.
- User texts and comments in ASD-STE100.

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes, so all iOS files compile in Swift 6 mode.

Manual (by the reviewer):

- A manual boost reserves its amount while it pays, and records the paid and unknown sats.
- A skipped boost writes no history entry.
- The history file work is in the store actor, not on the main actor.
- The boost sheet keeps its track.

Visual (on an iPhone): the ADR 0013 and ADR 0014 visual criteria. Report them as open.

## Test commands

```sh
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the results
3. behavior changed
4. deviations from task
5. unresolved concerns, with the open visual checks

## Escalation triggers

- A core type needs a change.
- Swift 6 requires `@unchecked Sendable` or `nonisolated(unsafe)`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/auto-boost-task-010-manual-boost-and-history.md
- docs/adr/0013-boosts.md, docs/adr/0014-player-screen-with-boost-button.md
- the files listed in "Files to inspect"

Goal:
- Add the Boost button and boost sheet, write each boost to the history, and add the history screen.

Constraints:
- Use the exact rules in the task file. BoostModel stays @MainActor. History file work stays in the store actor.
- No @unchecked Sendable or nonisolated(unsafe). No sheet or alert on a Section. No log of titles or messages.
- Comments and user texts in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- scripts/check.sh passes.

Test commands:
- the commands in the "Test commands" section of the task file

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
