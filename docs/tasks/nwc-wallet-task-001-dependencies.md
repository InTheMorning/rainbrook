# NWC wallet task 001: Dependencies and check script

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 1.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Encryption and signatures, §Consequences.

## Goal

Add `swift-secp256k1` and `swift-crypto` to `CitizenRadioCore`, and make `scripts/check.sh` run the Linux tests with the native SwiftPM build system.

## Files to inspect

- `Package.swift`
- `scripts/check.sh`
- `docs/adr/0005-swift-6-and-check-script.md`
- `docs/adr/0007-nwc-wallet-configuration.md`

## Files likely to change

- `Package.swift`
- `Package.resolved` (new, made by SwiftPM)
- `scripts/check.sh`
- `docs/adr/0005-swift-6-and-check-script.md`

## Do not touch

- All Swift source files in `CitizenRadio/` and `Tests/`.
- `CitizenRadio.xcodeproj/` (task 011 changes it).
- `xtool.yml`, `Configuration/`.

## Constraints

- Use exactly these dependency declarations:
  - `.package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.23.2")`
  - `.package(url: "https://github.com/apple/swift-crypto", "4.0.0"..<"6.0.0")`
- `CitizenRadioCore` depends on the products `P256K` (package `swift-secp256k1`), `Crypto` and `CryptoExtras` (package `swift-crypto`).
- The `CitizenRadio` target does not get these dependencies directly.
- Keep Swift tools 6.0 and `swiftLanguageModes: [.v6]`.
- Include `Package.resolved` in the change.
- Write all prose in ASD-STE100 Simplified Technical English.

## Implementation steps

1. Add a `dependencies:` array to the package with the two declarations.
2. Add the three products to the `CitizenRadioCore` target `dependencies:`.
3. Run `swift package resolve`.
4. In `scripts/check.sh`, change `swift test` to `swift test --build-system native`. Add one comment line above it: the default build system does not find the GCC 16 C++ headers for BoringSSL in `swift-crypto`, see ADR 0007.
5. In ADR 0005 §Decision, change step 1 to "`swift test --build-system native` on Linux." Add one line to §Consequences that names ADR 0007 as the reason.
6. Run the test commands.

## Acceptance criteria

Mechanical:

- `swift package show-dependencies` lists `swift-secp256k1` 0.23.2 and `swift-crypto`.
- `scripts/check.sh` passes, and its first step runs `swift test --build-system native`.
- The 37 existing tests pass.

## Test commands

```sh
swift package show-dependencies
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- SwiftPM cannot resolve the packages, or resolves a different `swift-secp256k1` version.
- `xtool dev build` fails after the change.
- Any test fails.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-001-dependencies.md
- Package.swift
- scripts/check.sh
- docs/adr/0005-swift-6-and-check-script.md

Goal:
- Add swift-secp256k1 0.23.2 and swift-crypto 4 to 5 to CitizenRadioCore, and run Linux tests with `swift test --build-system native` in scripts/check.sh.

Constraints:
- Use the exact dependency declarations and products in the task file.
- Keep Swift tools 6.0 and Swift 6 language mode.
- Include Package.resolved in the change. Do not run git commit. Keep the changes in the working tree.
- Prose in ASD-STE100.

Do not touch:
- CitizenRadio/, Tests/, CitizenRadio.xcodeproj/, xtool.yml, Configuration/

Acceptance criteria:
- `swift package show-dependencies` lists both packages.
- scripts/check.sh passes and runs `swift test --build-system native`.
- 37 existing tests pass.

Test commands:
- swift package show-dependencies
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
