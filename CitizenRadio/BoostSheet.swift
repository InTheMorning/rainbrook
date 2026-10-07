#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The boost sheet. It sends one manual boost (ADR 0013 §Manual boost).
///
/// The sheet keeps the track of the moment that it opened. A change of `BoostModel.manualTarget`
/// while the sheet is open does not change the sheet. The sheet does not monitor the model.
@MainActor
struct BoostSheet: View {
    private let boost: BoostModel
    /// The track of the moment that the sheet opened.
    @State private var track: TrackDisplay?
    @State private var amountText = String(BoostSettings().amountSats)
    @State private var message = ""
    @State private var isSending = false
    @State private var resultText: String?
    @Environment(\.dismiss) private var dismiss

    init(boost: BoostModel) {
        self.boost = boost
        // SwiftUI uses this first value one time, for the life of the sheet.
        _track = State(initialValue: boost.manualTarget)
    }

    private var amount: Int? {
        BoostSettings.parseAmount(amountText)
    }

    private var isFinished: Bool {
        resultText != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let track {
                        Text(track.title)
                            .font(.headline)
                        if !track.artist.isEmpty {
                            Text(track.artist)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("manualBoostAmountField")
                        Text("sats")
                            .foregroundStyle(.secondary)
                    }
                    if amount == nil {
                        Text("Enter 1 to 100,000 sats.")
                            .foregroundStyle(.red)
                    }
                    TextField("Message", text: $message, axis: .vertical)
                        .accessibilityIdentifier("manualBoostMessageField")
                        .onChange(of: message) { _, newValue in
                            if newValue.count > BoostSettings.maxMessageLength {
                                message = String(newValue.prefix(BoostSettings.maxMessageLength))
                            }
                        }
                }
                .disabled(isSending || isFinished)

                Section {
                    if let resultText {
                        Text(resultText)
                            .accessibilityIdentifier("manualBoostResult")
                    }
                    Button {
                        if isFinished {
                            dismiss()
                        } else {
                            send()
                        }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text(isFinished ? "Done" : "Send")
                        }
                    }
                    .disabled(isSending || (!isFinished && amount == nil))
                    .accessibilityIdentifier("sendBoostButton")
                }
            }
            .navigationTitle("Boost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // A boost that started continues after the sheet closes.
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// Starts the boost in a task. The task continues when the sheet closes.
    private func send() {
        guard let amount, !isSending else { return }
        isSending = true
        let boost = self.boost
        let track = self.track
        let message = self.message
        Task {
            let text = await boost.sendManualBoost(track: track, amountSats: amount, message: message)
            resultText = text
            isSending = false
        }
    }
}
#endif
