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
    let boostStatus: String?
    @State private var draft: StreamSettingsDraft
    @State private var error: String?
    @State private var relayError: String?
    @StateObject private var wallet = WalletSettingsModel()
    @Environment(\.dismiss) private var dismiss

    init(
        player: RadioPlayer, savedURL: Binding<String>, relayStatus: EventStreamStatus?, boostStatus: String?
    ) {
        self.player = player
        _savedURL = savedURL
        self.relayStatus = relayStatus
        self.boostStatus = boostStatus
        let boostSettings = BoostSettings()
        _draft = State(initialValue: StreamSettingsDraft(
            savedURL: savedURL.wrappedValue,
            chimeEnabled: ChimeSetting().isEnabled,
            dailyLimitSats: SpendingLimitStore().limit.dailySats,
            relayText: RelayEventStore().savedText,
            boostEnabled: boostSettings.isEnabled,
            boostAmountText: String(boostSettings.amountSats),
            boostMessage: boostSettings.message,
            boostSenderName: boostSettings.senderName,
            boostAppName: boostSettings.appName,
            boostMinimumPlaySecondsText: String(boostSettings.minimumPlaySeconds)
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

                WalletSettingsView(
                    model: wallet,
                    dailyLimitSats: $draft.dailyLimitSats,
                    boostEnabled: $draft.boostEnabled,
                    boostAmountText: $draft.boostAmountText,
                    boostMessage: $draft.boostMessage,
                    boostSenderName: $draft.boostSenderName,
                    boostAppName: $draft.boostAppName,
                    boostMinimumPlaySecondsText: $draft.boostMinimumPlaySecondsText,
                    boostStatus: boostStatus
                )
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
            let boostSettings = BoostSettings()
            boostSettings.isEnabled = draft.boostEnabled
            if let amount = BoostSettings.parseAmount(draft.boostAmountText) {
                boostSettings.amountSats = amount
            }
            if let minimumPlaySeconds = BoostSettings.parseMinimumPlaySeconds(draft.boostMinimumPlaySecondsText) {
                boostSettings.minimumPlaySeconds = minimumPlaySeconds
            }
            boostSettings.message = draft.boostMessage
            boostSettings.senderName = draft.boostSenderName
            boostSettings.appName = draft.boostAppName
            try RelayEventStore().save(draft.relayText)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
