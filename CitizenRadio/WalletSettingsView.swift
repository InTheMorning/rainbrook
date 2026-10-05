#if os(iOS)
import AVFoundation
import SwiftUI
import VisionKit
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The Wallet section of the settings sheet.
/// ADR 0007 §Settings names this section.
struct WalletSettingsView: View {
    @ObservedObject var model: WalletSettingsModel
    @Binding var dailyLimitSats: Int
    @State private var showingDisconnectConfirmation = false
    @State private var isShowingScanner = false
    @State private var cameraAccessMessage: String?
    @State private var scanMessage: String?

    /// The value is yes when the device hardware can operate the QR code scanner.
    /// `isAvailable` can also depend on camera access, so `startScan()` examines it after the permission step.
    private var scannerIsSupported: Bool {
        DataScannerViewController.isSupported
    }

    var body: some View {
        Section {
            switch model.state {
            case .loading:
                EmptyView()
            case .notConnected(let message):
                notConnectedRows(message: message)
            case .connected(let summary, let status, let warning, let isTesting):
                connectedRows(summary: summary, status: status, warning: warning, isTesting: isTesting)
            }
            Picker("Daily limit", selection: $dailyLimitSats) {
                ForEach(SpendingLimit.choices, id: \.self) { sats in
                    Text("\(sats) sats").tag(sats)
                }
            }
            .accessibilityIdentifier("dailyLimitPicker")
        } header: {
            Text("Wallet")
        } footer: {
            Text("The wallet connection is saved at once. Save applies the daily limit.")
        }
    }

    @ViewBuilder
    private func notConnectedRows(message: String?) -> some View {
        PasteButton(payloadType: String.self) { strings in
            Task { await model.connect(text: strings.first) }
        }
        .accessibilityIdentifier("walletPaste")
        if scannerIsSupported {
            Button("Scan QR Code") {
                Task { await startScan() }
            }
            .accessibilityIdentifier("walletScan")
            // A modifier on a Form Section applies to each row. Attach the sheet to this
            // one row, or each row presents a sheet and SwiftUI closes them at once.
            .sheet(isPresented: $isShowingScanner) {
                scannerSheet
            }
        }
        if let message {
            Text(message)
                .foregroundStyle(.red)
        }
        if let cameraAccessMessage {
            Text(cameraAccessMessage)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func connectedRows(summary: WalletSummary, status: String?, warning: String?, isTesting: Bool) -> some View {
        LabeledContent("Relay", value: summary.relayHost)
        LabeledContent("Wallet", value: summary.walletKeyPrefix + "…")
        if let lud16 = summary.lud16 {
            LabeledContent("Address", value: lud16)
        }
        Button {
            Task { await model.test() }
        } label: {
            if isTesting {
                ProgressView()
            } else {
                Text("Test Connection")
            }
        }
        .disabled(isTesting)
        .accessibilityIdentifier("walletTest")
        if let status {
            Text(status)
        }
        if let warning {
            Text(warning)
        }
        Button("Disconnect", role: .destructive) {
            showingDisconnectConfirmation = true
        }
        .accessibilityIdentifier("walletDisconnect")
        .confirmationDialog(
            "Disconnect the wallet?",
            isPresented: $showingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                Task { await model.disconnect() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView(onText: handleScannedText)
                .ignoresSafeArea()
                .safeAreaInset(edge: .bottom) {
                    Text(scanMessage ?? "Scan the connection QR code of your wallet.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingScanner = false
                        }
                    }
                }
        }
        .onDisappear {
            scanMessage = nil
        }
    }

    /// Asks for camera access on the first scan, then opens the scanner.
    /// Shows a message and keeps the scanner closed when access is denied or restricted.
    private func startScan() async {
        cameraAccessMessage = nil
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if status == .authorized {
            allowed = true
        } else if status == .notDetermined {
            allowed = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            allowed = false
        }
        if allowed && DataScannerViewController.isAvailable {
            scanMessage = nil
            isShowingScanner = true
        } else {
            cameraAccessMessage = "Allow camera access in Settings to scan a QR code."
        }
    }

    /// Checks a scanned text, and connects the wallet when the text is a connection.
    /// The closure answers yes when the text is a wallet connection. The text does not go into a log.
    private func handleScannedText(_ text: String) -> Bool {
        guard (try? NWCConnection(uri: text)) != nil else {
            scanMessage = "This QR code is not a wallet connection."
            return false
        }
        isShowingScanner = false
        Task { await model.connect(text: text) }
        return true
    }
}
#endif
