#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The Boost history screen (ADR 0013 §The history). It shows the entries, newest first.
@MainActor
struct BoostHistoryView: View {
    let entries: [BoostHistoryEntry]

    var body: some View {
        List {
            if entries.isEmpty {
                Text("No boosts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    NavigationLink {
                        BoostHistoryDetailView(entry: entry)
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
private struct BoostHistoryDetailView: View {
    let entry: BoostHistoryEntry

    var body: some View {
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
                    }
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
