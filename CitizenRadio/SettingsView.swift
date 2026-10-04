#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@MainActor
struct SettingsView: View {
    @ObservedObject var player: RadioPlayer
    @Binding var savedURL: String
    @State private var draft: StreamSettingsDraft
    @State private var error: String?
    @StateObject private var wallet = WalletSettingsModel()
    @Environment(\.dismiss) private var dismiss

    init(player: RadioPlayer, savedURL: Binding<String>) {
        self.player = player
        _savedURL = savedURL
        _draft = State(initialValue: StreamSettingsDraft(
            savedURL: savedURL.wrappedValue,
            chimeEnabled: ChimeSetting().isEnabled,
            bufferSeconds: BufferSetting().seconds,
            dailyLimitSats: SpendingLimitStore().limit.dailySats
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
                    Picker("Extra buffer", selection: $draft.bufferSeconds) {
                        ForEach(BufferSetting.choices, id: \.self) { seconds in
                            Text(seconds == 0 ? "Off" : "\(seconds) seconds").tag(seconds)
                        }
                    }
                    .accessibilityIdentifier("bufferPicker")
                } footer: {
                    Text("Playback starts after this much audio loads. A larger buffer helps in weak coverage, but playback starts later. The change applies at the next connection.")
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
        do {
            if draft.urlChanged {
                let address = try StreamStore().save(draft.text)
                if address.url.absoluteString != savedURL {
                    player.stop()
                }
                savedURL = address.url.absoluteString
            }
            ChimeSetting().isEnabled = draft.chimeEnabled
            BufferSetting().seconds = draft.bufferSeconds
            SpendingLimitStore().setDailySats(draft.dailyLimitSats)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
