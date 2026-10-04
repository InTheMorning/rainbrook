# NWC wallet task 010: QR code scanner

- Plan: [NWC wallet phase plan](../plans/nwc-wallet-phase-plan.md), phase 3.
- Decision: [ADR 0007](../adr/0007-nwc-wallet-configuration.md) §QR code scanning.
- Depends on: task 009.

## Goal

Add **Scan QR Code** to the Wallet section. The scanner reads a connection URI with VisionKit.

## Files to inspect

- `CitizenRadio/WalletSettingsView.swift`, `CitizenRadio/WalletSettingsModel.swift`
- `CitizenRadio/Info.plist`, `Configuration/xtool-info.plist`

## Files likely to change

- `CitizenRadio/QRScannerView.swift` (new, iOS only)
- `CitizenRadio/WalletSettingsView.swift`
- `CitizenRadio/WalletSettingsModel.swift` (camera permission state only)
- `CitizenRadio/Info.plist`
- `Configuration/xtool-info.plist`

## Do not touch

- The core, the tests, the player and all other files.

## Constraints

Scanner (`QRScannerView.swift`):

```swift
#if os(iOS)
struct QRScannerView: UIViewControllerRepresentable {
    let onText: (String) -> Bool   // returns true if the text is a valid connection
    // makeUIViewController gives a DataScannerViewController
}
#endif
```

- `DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)`.
- A `Coordinator` is the delegate. In `dataScanner(_:didAdd:allItems:)`, read `payloadStringValue` of each barcode and call `onText`. After the first `true`, call `stopScanning()`.
- Call `try? startScanning()` when the view controller appears. VisionKit runs the camera on its own thread, so this call does not block.

Wallet section changes:

- In `.notConnected`, add a **Scan QR Code** button below the paste button, only if `DataScannerViewController.isSupported && DataScannerViewController.isAvailable`.
- Before the scanner opens: if `AVCaptureDevice.authorizationStatus(for: .video)` is `.notDetermined`, call `await AVCaptureDevice.requestAccess(for: .video)`. If access is denied or restricted, show "Allow camera access in Settings to scan a QR code." and do not open the scanner.
- Show the scanner in a `.sheet` with a **Cancel** button and the text "Scan the connection QR code of your wallet."
- `onText` parses the text with `NWCConnection(uri:)`. A valid text closes the sheet and calls `connect(text:)`. An invalid text shows "This QR code is not a wallet connection." and the scan continues.
- Accessibility identifier: `walletScan`.

Plists:

- Add `NSCameraUsageDescription` with the text "CitizenRadio uses the camera only to scan the QR code of your wallet connection." to the two plists.

Other constraints:

- The text from the QR code does not go into a log.
- Prose, user texts and comments in ASD-STE100.

## Implementation steps

1. Write `QRScannerView.swift`.
2. Add the button, permission check and sheet to the Wallet section.
3. Add the plist key to the two plists.
4. Run the test commands.

## Acceptance criteria

Mechanical:

- `scripts/check.sh` passes.
- The two plists contain `NSCameraUsageDescription` with the same text. Examine with `grep -A1 NSCameraUsageDescription CitizenRadio/Info.plist Configuration/xtool-info.plist`.

Visual (on an iPhone):

- The camera permission request shows only after a tap on **Scan QR Code**.
- The scanner reads the Alby Hub connection QR code on another screen, closes, and the section shows the connected wallet.
- A QR code that is not a connection shows the message, and the scan continues.
- After a denial of camera access, the message tells the user to allow access in Settings.

## Test commands

```sh
grep -A1 NSCameraUsageDescription CitizenRadio/Info.plist Configuration/xtool-info.plist
PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh
```

## Expected final summary format

1. files changed
2. tests run, with the test count
3. behavior changed
4. deviations from task
5. unresolved concerns

## Escalation triggers

- VisionKit or `DataScannerViewController` is not in the iOS SDK that xtool uses.
- Swift 6 rejects the delegate conformance without `@unchecked Sendable` or `nonisolated(unsafe)`.

## Prompt for lower-context coding model

You are implementing one bounded task from a larger plan.

Implement only this task. Do not redesign the architecture.

Read:
- docs/tasks/nwc-wallet-task-010-qr-scanner.md
- CitizenRadio/WalletSettingsView.swift
- CitizenRadio/WalletSettingsModel.swift
- CitizenRadio/Info.plist
- Configuration/xtool-info.plist

Goal:
- Add a VisionKit QR scanner for the wallet connection, with camera permission on demand.

Constraints:
- Use the exact scanner setup, permission rules, texts and plist text in the task file.
- Ask for camera access only when the user taps Scan QR Code.
- No QR text in logs. No @unchecked Sendable or nonisolated(unsafe) without approval.
- Prose, user texts and comments in ASD-STE100.
- Do not run git commit. Keep the changes in the working tree.

Do not touch:
- The core, the tests, the player and any file that is not in "Files likely to change".

Acceptance criteria:
- scripts/check.sh passes. The two plists contain the same NSCameraUsageDescription.

Test commands:
- grep -A1 NSCameraUsageDescription CitizenRadio/Info.plist Configuration/xtool-info.plist
- PATH="$HOME/.local/bin:$PATH" APPIMAGE_EXTRACT_AND_RUN=1 scripts/check.sh

At the end, report:
1. files changed
2. tests run
3. behavior changed
4. deviations from task
5. unresolved concerns
