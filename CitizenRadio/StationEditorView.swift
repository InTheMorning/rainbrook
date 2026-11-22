#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Adds a station or changes a station. ADR 0017 §The station and §The station list.
@MainActor
struct StationEditorView: View {
    /// The station to change, or nil for a new station.
    private let station: Station?
    @State private var name: String
    @State private var streamText: String
    @State private var alternateStreamText: String
    @State private var trackInfoText: String
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(station: Station?) {
        self.station = station
        _name = State(initialValue: station?.name ?? "")
        _streamText = State(initialValue: station?.stream.absoluteString ?? "")
        _alternateStreamText = State(initialValue: station?.alternateStream?.absoluteString ?? "")
        _trackInfoText = State(initialValue: station?.trackInfo ?? "")
    }

    /// The stream is necessary. Save examines the other rules.
    private var canSave: Bool {
        !streamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Station name"))
                        .accessibilityIdentifier("stationName")
                } header: {
                    Text("Name")
                }

                Section {
                    urlField("Stream", text: $streamText, prompt: "https://radio.example.org/live")
                        .accessibilityIdentifier("stationStream")
                } header: {
                    Text("Stream")
                }

                Section {
                    urlField("Alternate stream", text: $alternateStreamText, prompt: "Optional")
                        .accessibilityIdentifier("stationAlternateStream")
                } header: {
                    Text("Alternate stream")
                } footer: {
                    Text("The app plays this stream when the stream fails.")
                }

                Section {
                    urlField("Live value address", text: $trackInfoText, prompt: "Optional")
                        .accessibilityIdentifier("stationTrackInfo")
                } header: {
                    Text("Live value address")
                } footer: {
                    Text("Paste the live value address from the stream producer. Leave it empty to use the stream title only.")
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("stationError")
                    }
                }
            }
            .navigationTitle(station == nil ? "Add Station" : "Edit Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveStation")
                }
            }
        }
    }

    private func urlField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        TextField(label, text: text, prompt: Text(prompt))
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    /// Makes a station with the same id, and saves it through StationStore.
    /// On an error, the editor shows the StationError text and stays open.
    private func save() {
        do {
            let result = try Station(
                id: station?.id ?? UUID(),
                name: name,
                streamText: streamText,
                alternateStreamText: alternateStreamText,
                trackInfoText: trackInfoText
            )
            let store = StationStore()
            if station == nil {
                try store.add(result)
            } else {
                store.update(result)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
