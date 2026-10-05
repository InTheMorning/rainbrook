# Relay display review checklist

- Plan: [relay display phase plan](../plans/relay-display-phase-plan.md).
- Decision: [ADR 0008](../adr/0008-relay-display-metadata.md). This checklist does not make rules.

Use this checklist for the diff of each task. Give one result: pass, or fail with the required fixes.

## 1. Scope

- [ ] The diff changes only the files in "Files likely to change" of the task.
- [ ] The public API agrees with the task packet.
- [ ] The diff contains no cleanup, no reformatting, and no change to playback, the buffer, the chime, the audio session, the App Intents or the wallet.
- [ ] The report lists each deviation, and each deviation has a reason.

## 2. Threading (ADR 0006)

- [ ] Network calls use async `URLSession` methods. No completion handler waits, and there is no `DispatchSemaphore`.
- [ ] Image download and decode run in `ArtworkLoader`, not on the main thread.
- [ ] The `AVPlayerItemMetadataOutput` delegate runs on a private queue.
- [ ] `MPMediaItemArtwork` is made in a `nonisolated` function, because its handler does not run on the main thread.
- [ ] `@MainActor` types do no blocking work. Scheduled applies are tasks that sleep, not timers.
- [ ] No `@unchecked Sendable` and no `nonisolated(unsafe)` without a written approval.

## 3. Module boundaries

- [ ] `CitizenRadioCore` does not import `Network`, UIKit, SwiftUI, AVFoundation or MediaPlayer, and does not use `URLSession`.
- [ ] `EventStreamClient` depends only on `LineStreamOpening`, `SnapshotFetching`, `EventStreamParser` and the injected sleep function.
- [ ] New iOS files start with `#if os(iOS)` and import `CitizenRadioCore` inside `#if SWIFT_PACKAGE`.
- [ ] Only task 009 changes `CitizenRadio.xcodeproj/project.pbxproj`.

## 4. SwiftUI

- [ ] No `.sheet`, `.alert`, `.confirmationDialog` or `.fullScreenCover` is attached to a `Section` in a `Form` or `List`. See the wallet review checklist.
- [ ] A view only reads model values. The rules are in core types with tests.

## 5. Transport correctness

- [ ] The SSE line reader keeps empty lines. It does not use `bytes.lines`.
- [ ] The watchdog counts each line, also comments.
- [ ] The client closes each stream on all paths, and `stop()` finishes the update stream.
- [ ] `404` and `409` stop the client. Other failures use the backoff.
- [ ] No connection opens while playback is stopped or the **Track info** field is empty.

## 6. Data and privacy

- [ ] No log contains a URL query, a header, a body, a title or image data.
- [ ] An image larger than 524,288 bytes, or not JPEG or PNG, is not shown.

## 7. Tests

- [ ] Each mechanical acceptance criterion of the task has a test that fails without the change.
- [ ] Tests use no network and no real time.
- [ ] `PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh` passes. The reviewer runs it again.

## 8. Documentation

- [ ] Changed prose follows ASD-STE100, and the STE checker has no new confirmed defect.
- [ ] A changed rule changes its decision record in the same commit.

## 9. Result

Return:

1. pass or fail
2. required fixes
3. optional improvements
4. if the task can be committed
5. if the next task packet needs a change
