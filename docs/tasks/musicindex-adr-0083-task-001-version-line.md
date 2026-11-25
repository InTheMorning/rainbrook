# musicindex ADR 0083 Task 001: The Version Line

- Decision: [musicindex ADR 0083](../../../../musicindex/docs/adr/0083-each-app-shows-its-version-in-one-form.md).
  This task cites the rules. It does not write them again.
- Request: the operator, 2026-11-25: "Ensure the app shows its version info as per our suite's rules".

## Rules That Apply

- R-VERSION-1: the build values. The version is `CFBundleShortVersionString` (`0.1.0`), because the app has no
  `Cargo.toml`.
- R-VERSION-2 and R-VERSION-8 item 3: the line form. The app has no command line, so only the line form applies.
- R-VERSION-4: the line at the end of Settings, with selectable text and a "Copy" button.
- R-VERSION-8 item 1: the input values `CITIZENRADIO_GIT_REVISION` and `CITIZENRADIO_BUILT_AT` come before Git and
  the clock.
- R-VERSION-9: the line form has a test. The Settings line is a visual check.
- R-VERSION-3 does not apply: the app has no server route. R-VERSION-6 does not apply: the app sets no User-Agent.
  R-VERSION-7 is an operator task.

## Main Session Choices

1. A Swift app cannot use the Rust crate `musicindex-build-info` (`project-baseline` skill). A SwiftPM build tool
   plugin gives the git revision and the build time. xtool builds the app with SwiftPM and copies
   `Configuration/xtool-info.plist` with no change, so a value in the Info.plist cannot come from the build.
   `xtool dev` does not change.
2. The plugin command runs again when a Swift file of `CitizenRadio/`, `Package.swift`, `HEAD`, the file of the branch
   or the Git index changes. A change to a file that is not an input, for example a document, does not run it again.
   Then "-dirty" can be incorrect until the next commit.
3. The Xcode project does not have the module. A build with Xcode shows the line with no parentheses
   (R-VERSION-8 item 3). Open point: the Xcode project does not list the new Core files of ADR 0028 either, so the
   Xcode build is not current.
4. The line text is `BuildValues.versionLine`, in one place: `AppBuildValues.current`.

## Base components

| Component | Status | Location | Reason |
| --- | --- | --- | --- |
| Version line form | new | CitizenRadio/Core/BuildValues.swift | Searched CitizenRadio/Core, CitizenRadio and ~/build/musicindex-lib. musicindex-lib has the line form only in the Rust crate build-info/src/lib.rs. A Swift app cannot use a Rust crate. |
| Build values of the build | new | Plugins/BuildValuesPlugin/plugin.swift | Searched Package.swift, scripts, xtool.yml and ~/build/musicindex-lib. The Rust build script build-info/src/build.rs has the rules. This tool and plugin copy those rules in Swift. |
| Settings screen | extend | CitizenRadio/SettingsView.swift | The line is the last section of the form. |

## Changes

- `Package.swift`: the module `CitizenRadioBuildValues`, the tool `BuildValuesTool` and the plugin
  `BuildValuesPlugin`. The app target uses the module.
- `Tools/BuildValuesTool/main.swift`, `Plugins/BuildValuesPlugin/plugin.swift`,
  `Tools/CitizenRadioBuildValues/CitizenRadioBuildValues.swift` (new).
- `CitizenRadio/Core/BuildValues.swift` (new) and `CitizenRadio/AppBuildValues.swift` (new).
- `CitizenRadio/SettingsView.swift`: the version section at the end.
- `Tests/CitizenRadioCoreTests/BuildValuesTests.swift` (new).

## Acceptance Criteria

Mechanical:

- `scripts/check.sh` passes. It includes the iOS build.
- `BuildValuesTests`: `BuildValues.versionLine` gives `CitizenRadio 0.1.0 (a1b2c3d, 2026-11-25)`, keeps "-dirty",
  puts only the known values in the parentheses, and gives no parentheses with no known value.
- After `xtool dev build`, the binary `xtool/CitizenRadio.app/CitizenRadio` contains the short hash of `HEAD` and the
  build time. Method: `strings` on the binary.

Visual (open until the operator does the check):

- The last row of Settings shows the line, for example `CitizenRadio 0.1.0 (a1b2c3d, 2026-11-25)`. The hash is the
  commit of the build.
- A long press selects the text of the line.
- "Copy" puts the line on the clipboard.
