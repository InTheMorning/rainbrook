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
    /// The history entry of the sent boost, or nil.
    @State private var entryID: UUID?
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

                // ADR 0013 §Manual boost: the split for the amount, before Send.
                if !isFinished, let amount {
                    // Each recipient shows, also a recipient that gets 0 sats after rounding.
                    let shares = boost.manualShares(track: track, amountSats: amount)
                    if !shares.isEmpty {
                        Section("Split") {
                            ForEach(Array(shares.enumerated()), id: \.offset) { _, share in
                                splitRow(share)
                            }
                        }
                    }
                }

                Section {
                    if let resultText {
                        Text(resultText)
                            .accessibilityIdentifier("manualBoostResult")
                    }
                    if let entryID {
                        // ADR 0013 §Manual boost: a link to the history entry of the boost.
                        NavigationLink("Payment details") {
                            BoostHistoryDetailView(entryID: entryID)
                                .environmentObject(boost)
                        }
                        .accessibilityIdentifier("boostPaymentDetailsLink")
                    } else if !isFinished {
                        Button {
                            send()
                        } label: {
                            if isSending {
                                ProgressView()
                            } else {
                                Text("Send")
                            }
                        }
                        .disabled(isSending || amount == nil)
                        .accessibilityIdentifier("sendBoostButton")
                    }
                }
            }
            .navigationTitle("Boost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // A boost that started continues after the sheet closes.
                    Button(isFinished ? "Close" : "Cancel") { dismiss() }
                }
            }
        }
    }

    /// One recipient: the name and its split value, then the percentage and the sats that the app pays.
    private func splitRow(_ share: BoostShare) -> some View {
        LabeledContent {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Self.decimal(share.percent))%")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(Self.decimal(Double(share.sats))) sats")
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(share.destination.name ?? "Recipient")
                Text("(\(Self.decimal(share.destination.split)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A number with 0 to 2 decimals, for example "97", "96.04" or "0.5".
    private static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Starts the boost in a task. The task continues when the sheet closes.
    private func send() {
        guard let amount, !isSending else { return }
        isSending = true
        let boost = self.boost
        let track = self.track
        let message = self.message
        Task {
            let outcome = await boost.sendManualBoost(track: track, amountSats: amount, message: message)
            resultText = outcome.text
            entryID = outcome.entryID
            isSending = false
        }
    }
}
#endif
