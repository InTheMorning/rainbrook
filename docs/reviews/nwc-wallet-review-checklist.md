# NWC wallet review checklist

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md).
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md). This checklist does not make rules.

Use this checklist for the diff of each task. Give one result: pass, or fail with the required fixes.

## 1. Scope

- [ ] The diff changes only the files in "Files likely to change" of the task.
- [ ] The public API agrees with the task packet. No type, method or parameter has a different name.
- [ ] The diff contains no opportunistic cleanup, no reformatting and no change to playback, the chime, the buffer or the App Intents.
- [ ] The report lists each deviation, and each deviation has a reason.

## 2. Secrets

- [ ] The URI and the secret go only through `SecretStore`, and the app implementation is the Keychain.
- [ ] No `description`, `debugDescription`, `Mirror`, error text or log line contains the secret, the URI, a plaintext or a shared secret.
- [ ] Each new `Logger` call is examined. It logs no wallet data.
- [ ] No secret goes into UserDefaults.

## 3. Threading (ADR 0006 and ADR 0007 §Invariants)

- [ ] Each `SecItem` call is in a dispatch queue block. `KeychainThreadTests` passes.
- [ ] Network calls use `async` methods. No completion handler waits, and there is no `DispatchSemaphore`.
- [ ] Camera access uses the `async` permission request. VisionKit starts the camera.
- [ ] `@MainActor` types do no blocking work.
- [ ] No `@unchecked Sendable` and no `nonisolated(unsafe)` without a written approval.

## 4. Module boundaries

- [ ] `CitizenRadioCore` does not import Security, VisionKit, UIKit or SwiftUI, and does not use `URLSession`.
- [ ] `NWCClient` depends only on `SecretStore`, `RelayConnection`, `RelayConnecting` and core types.
- [ ] New iOS files start with `#if os(iOS)` and import `CitizenRadioCore` inside `#if SWIFT_PACKAGE`.
- [ ] Only task 011 changes `CitizenRadio.xcodeproj/project.pbxproj`.
- [ ] No `.sheet`, `.alert`, `.confirmationDialog` or `.fullScreenCover` is attached to a `Section` in a `Form` or `List`. SwiftUI applies a `Section` modifier to each row, so the presentation closes at once. Attach it to one row or to a view outside the form. This defect closed the QR scanner on 2026-10-04.

## 5. Protocol correctness

- [ ] Event serialization writes the JSON by hand and follows the NIP-01 escape rules.
- [ ] The BIP-340 and NIP-44 vector files are unchanged downloads, and all vectors pass.
- [ ] The NIP-44 MAC comparison is constant time and comes before decryption.
- [ ] The NIP-47 request has kind 23194, the wallet `p` tag and, for NIP-44, the `encryption` tag.
- [ ] The client closes the relay connection on success, on error and on timeout.

## 6. Tests

- [ ] Each mechanical acceptance criterion of the task has a test that fails without the change.
- [ ] Tests use no network access.
- [ ] `PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh` passes. The reviewer runs it again and does not trust the report alone.

## 7. Documentation

- [ ] Changed prose follows ASD-STE100, and the STE checker has no new confirmed defect.
- [ ] The number of code comments is small, as in the existing files.
- [ ] A changed rule changes its decision record in the same commit.

## 8. Result

Return:

1. pass or fail
2. required fixes
3. optional improvements
4. if the task can be committed
5. if the next task packet needs a change
