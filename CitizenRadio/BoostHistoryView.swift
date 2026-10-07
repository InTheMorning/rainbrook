#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The Boost history screen (ADR 0013 §The history). It shows the entries, newest first.
/// The player screen gives the boost model as an environment object.
/// So the screen updates after a retry (ADR 0016 §The retry).
@MainActor
struct BoostHistoryView: View {
    @EnvironmentObject private var boost: BoostModel

    var body: some View {
        List {
            if boost.history.isEmpty {
                Text("No boosts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(boost.history) { entry in
                    NavigationLink {
                        BoostHistoryDetailView(entryID: entry.id)
                            .environmentObject(boost)
                    } label: {
                        BoostHistoryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Boost history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One row of the history: the title, the date and time, the boost type and the summary.
private struct BoostHistoryRow: View {
    let entry: BoostHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
            Text(entry.date, format: .dateTime)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(BoostHistoryKindText.text(for: entry.kind))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(BoostHistoryText.summary(for: entry))
                .font(.subheadline)
        }
    }
}

/// The data of one entry: the track, the amount, the message and the result of each part.
/// The view reads the entry by its id from the boost model, so it shows the result of a retry.
@MainActor
private struct BoostHistoryDetailView: View {
    let entryID: UUID
    @EnvironmentObject private var boost: BoostModel

    var body: some View {
        if let entry = boost.history.first(where: { $0.id == entryID }) {
            details(of: entry)
        } else {
            Text("No boost.")
                .foregroundStyle(.secondary)
        }
    }

    private func details(of entry: BoostHistoryEntry) -> some View {
        List {
            Section {
                Text(entry.title)
                    .font(.headline)
                if let artist = entry.artist {
                    Text(artist)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Amount", value: "\(entry.amountSats) sats")
                if let message = entry.message {
                    Text(message)
                }
            }
            Section("Payments") {
                ForEach(Array(entry.parts.enumerated()), id: \.offset) { _, part in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(part.name ?? "Recipient")
                            .font(.headline)
                        Text(part.kind == .keysend ? "Keysend" : "Lightning address")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(part.sats) sats")
                            .font(.subheadline)
                        Text(BoostHistoryText.label(for: part.result))
                            .font(.subheadline)
                        // ADR 0016 §The failure reason: a failed part shows its reason.
                        if let reason = BoostHistoryText.reason(for: part) {
                            Text(reason)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if part.attempts > 1 {
                            Text("\(part.attempts) attempts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            // ADR 0016 §The retry: the button sends the retryable parts again.
            // It is not active while a retry of the entry runs.
            if entry.hasRetryableParts {
                Section {
                    Button("Retry") {
                        Task { await boost.retry(entryID: entry.id) }
                    }
                    .disabled(boost.retryingEntries.contains(entry.id))
                    .accessibilityIdentifier("boostRetryButton")
                }
            }
        }
        .navigationTitle(BoostHistoryKindText.text(for: entry.kind))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The user text for the boost type of an entry.
private enum BoostHistoryKindText {
    static func text(for kind: BoostHistoryEntry.Kind) -> String {
        switch kind {
        case .auto: "Auto-boost"
        case .manual: "Boost"
        }
    }
}
#endif
