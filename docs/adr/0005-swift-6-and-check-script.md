# ADR 0005: Swift 6 and the check script

- Status: accepted
- Date: 2026-10-04
- Class: durable. These rules apply to all designs of the app.

## Context

The package used Swift 5 language mode. In that mode, the xtool iOS build gave zero warnings.
A review in Xcode reported many problems, so the Linux build did not find problems that Xcode found.

A test build in Swift 6 language mode found 6 errors in `CitizenRadio/RadioIntents.swift`.
Each intent declared `title`, `description` and `openAppWhenRun` as `static var`.
Swift 6 rejects mutable static properties, because any thread can change them.

The development computer is Linux. xtool compiles the app with the iOS SDK, so a Linux build can find these errors.

## Decision

- The Swift package uses Swift tools 6.0 and Swift 6 language mode.
- The Xcode target uses `SWIFT_VERSION` 6.0, so the two builds apply the same checks.
- `scripts/check.sh` must pass before a commit. It runs these checks in sequence:
  1. `swift test --build-system native` on Linux.
  2. `xtool dev build`. Each Swift 6 error stops the build.
  3. The App Intents symbol check of [ADR 0003](0003-committed-app-intents-metadata.md).
- Each failure message in the script names the decision record that owns the rule and the fix.

## Alternatives considered

- Keep Swift 5 mode and set `SWIFT_STRICT_CONCURRENCY=complete`. That gives warnings, not errors, and warnings did not stop a build.
- Make all warnings errors. No warning has caused a defect in this app. A guard without a failure costs maintenance and can block work.
- Run SwiftLint or `swift format lint`. No defect from style has occurred. Add a lint step when one occurs.
- Use a Mac or a macOS CI runner for each check. The development computer is Linux, and xtool gives the same iOS compile.

## Consequences

- Swift 6 errors in the iOS code show on Linux before installation.
- The script needs `xtool` and `llvm-nm` on the PATH.
- The checks do not replace the device checks in the [setup runbook](../runbooks/iphone-setup.md). They do not run the app.
- Xcode can report problems that these checks do not find. Add a guard for each such problem when it causes a defect.
- Step 1 uses `--build-system native` because [ADR 0007](0007-nwc-wallet-configuration.md) needs it for `swift-crypto`.

## Invariants

- The package uses Swift 6 language mode.
  The `xtool dev build` step of `scripts/check.sh` enforces this rule for the code. A change of the mode in `Package.swift` is visible in review.
- `scripts/check.sh` passes before each commit.
  Manual check: run the script. No hook runs it automatically.
