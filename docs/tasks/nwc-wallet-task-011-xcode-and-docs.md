# NWC wallet task 011: Xcode project file and documentation

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 4.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §Module boundaries, §Consequences.
- Depends on: task 010.

## Goal

Add the new source files and the two package dependencies to the Xcode project.
Update the documentation for the Wallet feature.

## Files to inspect

- `CitizenRadio.xcodeproj/project.pbxproj`
- `docs/architecture/overview.md`, `README.md`, `docs/runbooks/iphone-setup.md`
- `docs/adr/0007-nwc-wallet-configuration.md`, `docs/plans/nwc-wallet-phase-plan.md`

## Files likely to change

- `CitizenRadio.xcodeproj/project.pbxproj`
- `docs/architecture/overview.md`
- `README.md`
- `docs/runbooks/iphone-setup.md`
- `docs/plans/nwc-wallet-phase-plan.md` (status line only)

## Do not touch

- All Swift sources, tests, plists and `Package.swift`.

## Constraints

Xcode project:

- Add a `PBXFileReference` and a `PBXBuildFile` in the Sources phase for each new Swift file:
  - Core: `NWCConnection`, `WalletSummary`, `SpendingLimit`, `NostrKeys`, `NostrEvent`, `NIP44`, `NIP04`, `RelayMessage`, `RelayConnection`, `NWCClient`, `SecretStore`, `WalletStatusText`. Their paths start with `Core/`.
  - App: `KeychainSecretStore`, `URLSessionRelayConnection`, `WalletSettingsModel`, `WalletSettingsView`, `QRScannerView`.
- Add the file references to the `CitizenRadio` group.
- Add two `XCRemoteSwiftPackageReference` objects:
  - `repositoryURL = "https://github.com/21-DOT-DEV/swift-secp256k1"`, `requirement = { kind = exactVersion; version = 0.23.2; }`
  - `repositoryURL = "https://github.com/apple/swift-crypto"`, `requirement = { kind = versionRange; minimumVersion = 4.0.0; maximumVersion = 6.0.0; }`
- Add three `XCSwiftPackageProductDependency` objects: `P256K`, `Crypto` and `CryptoExtras`, each with its `package`.
- Add `packageReferences` to the `PBXProject` object and `packageProductDependencies` to the `CitizenRadio` native target.
- Add a `PBXBuildFile` with `productRef` for each product to the Frameworks build phase.
- Use new 24-character hexadecimal IDs in the existing style. Each new ID must not exist in the file before.
- Use the quoted key style of the existing file.

Documentation:

- Architecture overview: add a row to the components table for each new type, with one sentence. Add the wallet flow to the data flow:
  `SettingsView -> WalletSettingsModel -> WalletStore -> KeychainSecretStore` and `WalletSettingsModel -> NWCClient -> URLSessionRelayConnection -> relay`.
  Change the file count sentence.
- README: one bullet in "Current implementation" for the wallet connection, and the dependencies sentence ("The project has no external dependencies" is no longer true).
- Runbook: a "Connect a wallet" procedure for Alby Hub (paste or scan, test, disconnect, daily limit). Add the ADR 0007 visual criteria to the device checks table.
- Plan status line: "Status: implemented, <date>. The visual checks are open."
- Prose in ASD-STE100. Run the STE checker on each changed document.

## Implementation steps

1. Change the project file.
2. Run the ID check below.
3. Change the documentation.
4. Run the test commands.

## Acceptance criteria

Mechanical:

- The ID check prints no missing ID: each quoted 24-character ID that the file uses is also defined.
- The number of `sourcecode.swift` file references equals the number of Swift files in `CitizenRadio/` and `CitizenRadio/Core/`.
- `scripts/check.sh` passes.
- All relative links in the changed documents resolve.

Visual (by a person with a Mac):

- `scripts/generate-app-intents-metadata.sh` on a Mac builds the Xcode project with the two packages. Report this item as open until the friend runs it.

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

- The project file uses a structure that this task does not describe.
- The ID check reports a missing ID that the change did not add.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-011-xcode-and-docs.md
- CitizenRadio.xcodeproj/project.pbxproj
- docs/architecture/overview.md
- README.md
- docs/runbooks/iphone-setup.md
- docs/adr/0007-nwc-wallet-configuration.md

Goal:
- Register the new Swift files and the two packages in the Xcode project, and update the documentation for the Wallet feature.

Constraints:
- Follow the project file rules in the task file. Use new unique 24-character IDs in the existing quoted style.
- Documentation in ASD-STE100. Change only the listed documents.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- Swift sources, tests, plists, Package.swift.

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
