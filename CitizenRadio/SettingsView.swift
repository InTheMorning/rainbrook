#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@MainActor
struct SettingsView: View {
    @ObservedObject var player: RadioPlayer
    @Binding var savedURL: String
    let relayStatus: EventStreamStatus?
    @State private var draft: StreamSettingsDraft
    @State private var error: String?
    @State private var relayError: String?
    @StateObject private var wallet = WalletSettingsModel()
    @Environment(\.dismiss) private var dismiss

    init(player: RadioPlayer, savedURL: Binding<String>, relayStatus: EventStreamStatus?) {
        self.player = player
        _savedURL = savedURL
        self.relayStatus = relayStatus
        _draft = State(initialValue: StreamSettingsDraft(
            savedURL: savedURL.wrappedValue,
            chimeEnabled: ChimeSetting().isEnabled,
            dailyLimitSats: SpendingLimitStore().limit.dailySats,
            relayText: RelayEventStore().savedText
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://radio.example.org/live", text: $draft.text)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { if draft.canSave { save() } }
                        .accessibilityLabel("Stream URL")
                        .accessibilityIdentifier("streamURL")
                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Stream URL")
                } footer: {
                    Text("Enter a direct MP3 or AAC stream URL. Use HTTPS when available.")
                }

                Section {
                    TextField("https://api.musicindex.org/v1/liveitems/…", text: $draft.relayText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("trackInfoURL")
                    if let relayError {
                        Text(relayError)
                            .foregroundStyle(.red)
                    }
                    if let relayMessage = RelayStatusText.message(for: relayStatus) {
                        Text(relayMessage)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("trackInfoStatus")
                    }
                } header: {
                    Text("Track info")
                } footer: {
                    Text("Paste the relay event address from the stream producer. Leave it empty to use the stream title only.")
                }

                Section {
                    Toggle("Chime while connecting", isOn: $draft.chimeEnabled)
                        .accessibilityIdentifier("chimeToggle")
                } footer: {
                    Text("The chime plays until the stream starts.")
                }

                WalletSettingsView(model: wallet, dailyLimitSats: $draft.dailyLimitSats)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await wallet.load()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave)
                        .accessibilityIdentifier("saveStream")
                }
            }
        }
    }

    private func save() {
        let trimmedRelayText = draft.relayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRelayText.isEmpty {
            do {
                _ = try RelayEvent(uri: trimmedRelayText)
            } catch {
                relayError = error.localizedDescription
                return
            }
        }
        relayError = nil
        do {
            if draft.urlChanged {
                let address = try StreamStore().save(draft.text)
                if address.url.absoluteString != savedURL {
                    player.stop()
                }
                savedURL = address.url.absoluteString
            }
            ChimeSetting().isEnabled = draft.chimeEnabled
            SpendingLimitStore().setDailySats(draft.dailyLimitSats)
            try RelayEventStore().save(draft.relayText)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
