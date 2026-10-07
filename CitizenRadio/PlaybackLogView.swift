#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The Playback log screen (ADR 0022 §The playback log). It shows the events, newest last.
/// The toolbar has Share and Clear.
@MainActor
struct PlaybackLogView: View {
    @State private var lines: [String] = []
    @State private var text = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if lines.isEmpty {
                    Text("No events yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: lines.count) { _, count in
                guard count > 0 else { return }
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
        .navigationTitle("Playback log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(text.isEmpty)
                .accessibilityIdentifier("playbackLogShare")
                Button("Clear") {
                    clear()
                }
                .disabled(lines.isEmpty)
                .accessibilityIdentifier("playbackLogClear")
            }
        }
        .task {
            await reload()
        }
    }

    /// Reads the entries from the store. The store reads the file off the main actor.
    private func reload() async {
        let log = PlaybackLog(entries: await PlaybackLogStore.shared.entries())
        text = log.text()
        lines = text.isEmpty ? [] : text.components(separatedBy: "\n")
    }

    private func clear() {
        Task {
            await PlaybackLogStore.shared.clear()
            text = ""
            lines = []
        }
    }
}
#endif
