#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The Wallet section of the settings sheet.
/// ADR 0007 §Settings names this section.
struct WalletSettingsView: View {
    @ObservedObject var model: WalletSettingsModel
    @Binding var dailyLimitSats: Int
    @State private var showingDisconnectConfirmation = false

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
        if let message {
            Text(message)
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
}
#endif
