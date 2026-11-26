# ADR 0029: The app name is Rainbrook

- Status: accepted
- Date: 2026-11-25
- Bar: crosses repositories. The `project-baseline` skill and the `AGENTS.md` of musicindex-research cite the paths
  of this app. The bundle ID is also difficult to change, because a new bundle ID makes a new app on the iPhone.
- Changes: [ADR 0017](0017-stations-with-alternate-stream.md) §The first start after the update, and the items of
  §Consequences, §Invariants and §Acceptance criteria that name that rule.
- Related: HitIt ADR 0096 (`~/build/HitIt/docs/adr/0096-the-app-name-is-hitit.md`) is the example for Decision 7.

## Context

The app had the name CitizenRadio. On 2026-11-25 the operator renamed the app Rainbrook, a streaming and music
client. The operator moved the checkout to `~/build/xcode/rainbrook` and renamed the GitHub repository to
`InTheMorning/rainbrook`. The orchestrator session relayed the operator decisions of 2026-11-25.

The display name, the Info.plist texts, the App Intents titles, the bundle ID and the URL scheme used the name
CitizenRadio. The Xcode project, the Swift package targets and the source folder also used it.

## Decision

1. The display name of the app is Rainbrook. Text that a person reads uses Rainbrook. This text includes the
   Info.plist texts, the App Intents titles and phrases, the navigation title and the status texts. It also
   includes the default **App name** of a boost.
2. The bundle ID is `org.rainbrook.Rainbrook`. The log subsystem, the dispatch queue labels and the Keychain service
   start with `org.rainbrook.Rainbrook`.
3. The URL scheme is `rainbrook://`. The control kind is `org.rainbrook.control`.
4. The machine name is `Rainbrook`:
   - The Xcode project is `Rainbrook.xcodeproj`, with the scheme and the target `Rainbrook`.
   - The source folder is `Rainbrook/`, and the shared code is in `Rainbrook/Core/`.
   - The Swift package targets are `Rainbrook`, `RainbrookCore`, `RainbrookBuildValues` and `RainbrookCoreTests`.
   - The app entry point is `RainbrookApp` in `Rainbrook/RainbrookApp.swift`.
   - The environment variables of the build values start with `RAINBROOK_`.
   - The UserDefaults keys start with `rainbrook.`. The Application Support folder is `Rainbrook/`.
5. The app does not move the data of CitizenRadio. iOS installs Rainbrook as a new app. The saved stations, the
   settings, the playback log, the boost history and the Keychain wallet connection stay in CitizenRadio. The
   operator enters them again. The app has no migration code for them.
   The first start rule of ADR 0017 is removed, because a new install has no keys of the single station. With no
   stored station list, the list is empty and no station is selected.
6. The app icon is concept A of musicindex-research commit `31fb3a9`. The AppIcon set uses
   `research_notes/ui-design/rainbrook-logo/rainbrook-icon-square-1024.png` with square corners, because iOS applies
   the mask.
7. Records with a date before 2026-11-25 keep the name CitizenRadio, because they are history. This applies to ADRs
   0003 to 0028, the archived ADRs, the plans, the tasks, the reviews, the proposals and the research notes. In
   those records, the name CitizenRadio means Rainbrook. Their paths, targets, keys and identifiers with
   `CitizenRadio`, `citizenRadio` or `citizenradio` mean the forms of Decisions 2 to 4.
8. The station host `bastone.heycitizen.xyz` and the station name HeyCitizen are not the app name. The test data
   keeps them.

## Consequences

- `Configuration/AppIntents/Metadata.appintents` must come from Xcode (ADR 0003). Until a person runs
  `scripts/generate-app-intents-metadata.sh` on a Mac, the committed metadata names the module `CitizenRadio`. Then
  Shortcuts and Siri can fail to show **Play Rainbrook** and **Stop Rainbrook**.
- The intent symbols in the binary are `9Rainbrook15PlayRadioIntentV` and `9Rainbrook15StopRadioIntentV`, and
  `scripts/check.sh` looks for these names. The previous names `PlayB6IntentV` and `StopB6IntentV` used a Swift
  mangling substitution. `B6` pointed to the word "Radio" in the module name CitizenRadio. The module name
  Rainbrook has no word "Radio", so the mangled name spells `PlayRadioIntent` in full.
- The orchestrator changes the `Rainbrook/Core/` paths and the section name of this app in the `project-baseline`
  skill and in the `AGENTS.md` of musicindex-research.
- No test enforces Decisions 1 to 4, because no incident broke them. A person examines the home screen name, the
  icon and the Shortcuts actions after a change to the name.

## Acceptance criteria

### Mechanical

- `scripts/check.sh` passes.
- A case-insensitive search for "citizen" outside the records of Decision 7 finds only the station data of
  Decision 8 and `Configuration/AppIntents/Metadata.appintents` until its next generation.

### Visual

A person must examine these items on an iPhone. Report each item as open until a person completes that check.

- The home screen shows Rainbrook with the icon of Decision 6.
- After the metadata generation, Shortcuts shows **Play Rainbrook** and **Stop Rainbrook**, and each action works.
- `rainbrook://play` starts the saved station.
