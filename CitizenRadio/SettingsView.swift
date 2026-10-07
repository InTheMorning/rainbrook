#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@MainActor
struct SettingsView: View {
    /// The station that the editor sheet shows. ADR 0017 §The station list.
    private struct EditorTarget: Identifiable {
        let id = UUID()
        /// Nil for a new station.
        let station: Station?
    }

    @ObservedObject var player: RadioPlayer
    let relayStatus: EventStreamStatus?
    let boostStatus: String?
    @State private var draft: StreamSettingsDraft
    @State private var stations: [Station]
    @State private var selectedID: UUID?
    @State private var editorTarget: EditorTarget?
    @StateObject private var wallet = WalletSettingsModel()
    @Environment(\.dismiss) private var dismiss

    init(player: RadioPlayer, relayStatus: EventStreamStatus?, boostStatus: String?) {
        self.player = player
        self.relayStatus = relayStatus
        let store = StationStore()
        _stations = State(initialValue: store.stations)
        _selectedID = State(initialValue: store.selectedID)
        self.boostStatus = boostStatus
        let boostSettings = BoostSettings()
        _draft = State(initialValue: StreamSettingsDraft(
            chimeEnabled: ChimeSetting().isEnabled,
            dailyLimitSats: SpendingLimitStore().limit.dailySats,
            streamQuality: StreamQualitySetting().quality,
            hlsBuffer: HLSBufferSetting().buffer,
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
                stationsSection

                Section {
                    Toggle("Chime while connecting", isOn: $draft.chimeEnabled)
                        .accessibilityIdentifier("chimeToggle")
                    Picker("Stream quality", selection: $draft.streamQuality) {
                        ForEach(StreamQuality.allCases, id: \.self) { quality in
                            Text(quality.label).tag(quality)
                        }
                    }
                    .accessibilityIdentifier("streamQualityPicker")
                    Picker("HLS buffer", selection: $draft.hlsBuffer) {
                        ForEach(HLSBuffer.allCases, id: \.self) { buffer in
                            Text(buffer.label).tag(buffer)
                        }
                    }
                    .accessibilityIdentifier("hlsBufferPicker")
                    // ADR 0022 §The playback log.
                    NavigationLink("Playback log") {
                        PlaybackLogView()
                    }
                    .accessibilityIdentifier("playbackLogLink")
                } footer: {
                    Text("The chime plays until the stream starts. Auto selects the bitrate for the network. Low uses less data. This applies to HLS streams. A larger HLS buffer survives a longer network problem, but you hear the stream later. A buffer change applies at the next Play.")
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
            .sheet(item: $editorTarget, onDismiss: reloadStations) { target in
                StationEditorView(station: target.station)
            }
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

    // MARK: - Stations

    /// ADR 0017 §The station list.
    private var stationsSection: some View {
        Section {
            if stations.isEmpty {
                Text("Add a station to play.")
                    .foregroundStyle(.secondary)
            }
            ForEach(stations) { station in
                stationRow(station)
            }
            .onDelete(perform: deleteStations)
            Button("Add Station") {
                editorTarget = EditorTarget(station: nil)
            }
            .disabled(stations.count >= StationStore.maximumCount)
            .accessibilityIdentifier("addStation")
        } header: {
            Text("Stations")
        } footer: {
            if let relayMessage = RelayStatusText.message(for: relayStatus) {
                Text(relayMessage)
                    .accessibilityIdentifier("trackInfoStatus")
            }
        }
    }

    private func stationRow(_ station: Station) -> some View {
        let isSelected = station.id == selectedID
        return HStack {
            Button {
                play(station)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .foregroundStyle(.primary)
                        Text(station.stream.host ?? station.stream.absoluteString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            Button {
                editorTarget = EditorTarget(station: station)
            } label: {
                Label("Edit \(station.name)", systemImage: "info.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
    }

    /// Selects the station, closes the sheet and starts playback.
    /// The onDismiss of the sheet in PlayerView reads the track info again.
    private func play(_ station: Station) {
        StationStore().select(id: station.id)
        selectedID = station.id
        dismiss()
        player.playFromControls()
    }

    /// A delete of the selected station stops the playback.
    private func deleteStations(at offsets: IndexSet) {
        let store = StationStore()
        let ids = offsets.map { stations[$0].id }
        let deletesSelected = ids.contains { $0 == store.selectedID }
        for id in ids {
            store.delete(id: id)
        }
        if deletesSelected {
            player.stop()
        }
        reloadStations()
    }

    private func reloadStations() {
        let store = StationStore()
        stations = store.stations
        selectedID = store.selectedID
    }

    // MARK: - Save

    private func save() {
        ChimeSetting().isEnabled = draft.chimeEnabled
        SpendingLimitStore().setDailySats(draft.dailyLimitSats)
        // ADR 0020 §Stream quality: a saved quality change applies to the current item.
        StreamQualitySetting().quality = draft.streamQuality
        player.setQuality(draft.streamQuality)
        // ADR 0020 §The HLS live offset: AVPlayer reads the offset when a stream starts.
        HLSBufferSetting().buffer = draft.hlsBuffer
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
        dismiss()
    }
}
#endif
