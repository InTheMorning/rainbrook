#if os(iOS)
import SwiftUI
import Vision
import VisionKit
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// A QR code scanner for a wallet connection text.
/// The task packet names this view. ADR 0007 §QR code scanning owns the rule.
struct QRScannerView: UIViewControllerRepresentable {
    /// Receives the text of a scanned QR code.
    /// The closure answers yes when the text is a wallet connection. The scanner then stops.
    let onText: (String) -> Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    /// Starts the scanner the first time SwiftUI shows this view controller.
    /// `DataScannerViewController` is public and not open, so this file cannot add
    /// a `viewDidAppear` override through a subclass. The coordinator flag gives the
    /// same one-time start.
    /// VisionKit runs the camera on its own thread. This call does not stop the app.
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !context.coordinator.hasStarted else { return }
        context.coordinator.hasStarted = true
        try? uiViewController.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onText: onText)
    }

    /// The scanner delegate. It reads each barcode and reports its text.
    @MainActor
    final class Coordinator: DataScannerViewControllerDelegate {
        private let onText: (String) -> Bool
        /// The value is yes after the first call to `startScanning()`.
        var hasStarted = false

        init(onText: @escaping (String) -> Bool) {
            self.onText = onText
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let text = barcode.payloadStringValue else { continue }
                if onText(text) {
                    dataScanner.stopScanning()
                    return
                }
            }
        }
    }
}
#endif
