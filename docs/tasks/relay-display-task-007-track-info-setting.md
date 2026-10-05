# Relay display task 007: Track info setting

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md), wave 2. Model: Sonnet.
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md) §Configuration. [ADR 0004](../adr/0004-player-screen-and-settings.md) puts all configuration in the settings sheet.
- Depends on: task 001.

## Goal

Add the **Track info** field to Settings. Store the relay event address in UserDefaults, and validate it with `RelayEvent`.

## Files to inspect

- `CitizenRadio/Core/RelayEvent.swift`
- `CitizenRadio/Core/StreamSettingsDraft.swift`, `CitizenRadio/Core/SpendingLimit.swift` (`SpendingLimitStore`, the pattern for a store)
- `CitizenRadio/SettingsView.swift`
- `Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift`

## Files likely to change

- `CitizenRadio/Core/RelayEventStore.swift` (new)
- `CitizenRadio/Core/StreamSettingsDraft.swift`
- `CitizenRadio/SettingsView.swift`
- `Tests/CitizenRadioCoreTests/RelayEventStoreTests.swift` (new)
- `Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift`

## Do not touch

- The Wallet section, the playback code and all other files.

## Constraints

Core API (`import Foundation` only):

```swift
public struct RelayEventStore {
    public init(defaults: UserDefaults = .standard)
    /// The saved text, or an empty text.
    public var savedText: String { get }
    /// The saved event, or nil when the text is empty or does not parse.
    public var event: RelayEvent? { get }
    /// Empty text (after trim) clears the setting and gives nil.
    /// Other text must parse with RelayEvent. Else it throws RelayEvent.ParseError, and the setting does not change.
    @discardableResult
    public func save(_ text: String) throws -> RelayEvent?
}
```

- UserDefaults key: `citizenRadio.relayEventURI`. Store the trimmed text.

`StreamSettingsDraft` changes:

- Add `public var relayText: String` and `public let savedRelayText: String`.
- Add the initializer parameter `relayText: String` after `dailyLimitSats`. Set both properties from it.
- `canSave` is also true when only `relayText` changes (compare trimmed texts), with the same rules as the buffer. An empty relay text is a permitted change.

`SettingsView` changes:

- Pass `RelayEventStore().savedText` to the draft.
- Add a section with the header "Track info", after the stream URL section:
  - `TextField("https://api.musicindex.org/v1/liveitems/…", text: $draft.relayText)` with `.keyboardType(.URL)`, `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()` and the accessibility identifier `trackInfoURL`.
  - The relay error, if present, in red.
  - The footer: "Paste the relay event address from the stream producer. Leave it empty to use the stream title only."
- Add `@State private var relayError: String?`.
- In `save()`, first parse a relay text that is not empty with `RelayEvent(uri:)`. On an error, set `relayError` to its `localizedDescription`, and return before any other setting is saved. Then save the other settings as now, and save the relay text with `RelayEventStore().save(draft.relayText)`.

Other constraints:

- Do not change the Wallet section.
- Prose, user texts and comments in ASD-STE100.

## Acceptance criteria

Mechanical (each one is a test):

- `RelayEventStore.save` with the station URL stores it, and `event` gives its event ID.
- `save` with spaces clears the setting and gives nil.
- `save` with `http://…` throws `.scheme`, and the saved text does not change.
- `StreamSettingsDraft.canSave` is true when only `relayText` changes, also to an empty text.
- `scripts/check.sh` passes.

Visual (on an iPhone):

- **Settings** shows the **Track info** section. A wrong address shows the error and saves nothing. A correct address saves.

## Test commands

```sh
swift test --build-system native --filter "RelayEventStoreTests|StreamSettingsDraftTests"
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- The draft change needs more than the changes that this packet names in `SettingsView`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/relay-display-task-007-track-info-setting.md
- CitizenRadio/Core/RelayEvent.swift
- CitizenRadio/Core/StreamSettingsDraft.swift
- CitizenRadio/Core/SpendingLimit.swift
- CitizenRadio/SettingsView.swift
- Tests/CitizenRadioCoreTests/StreamSettingsDraftTests.swift

Goal:
- Add RelayEventStore (core, tested), the relay text in StreamSettingsDraft, and the Track info section in SettingsView.

Constraints:
- Use the exact API, key, texts and SettingsView changes in the task file. Validate the relay text before any setting is saved.
- Do not change the Wallet section.
- Prose, user texts and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Any file that is not in "Files likely to change".

Acceptance criteria:
- Each mechanical criterion in the task file has a passing test. scripts/check.sh passes.

Test commands:
- swift test --build-system native --filter "RelayEventStoreTests|StreamSettingsDraftTests"
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
