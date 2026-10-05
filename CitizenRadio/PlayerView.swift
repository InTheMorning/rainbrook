#if os(iOS)
import AVKit
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@MainActor
struct PlayerView: View {
    @ObservedObject var player: RadioPlayer
    @StateObject private var trackInfo: TrackInfoModel
    @State private var savedURL = StreamStore().savedURL
    @State private var showingSettings = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(player: RadioPlayer) {
        self.player = player
        _trackInfo = StateObject(wrappedValue: TrackInfoModel(player: player))
    }

    private var model: PlayerScreenModel {
        PlayerScreenModel(state: player.state, hasSavedStream: !savedURL.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Group {
                if verticalSizeClass == .compact {
                    HStack(spacing: 32) {
                        Artwork(image: trackInfo.image)
                        controls
                    }
                } else {
                    VStack(spacing: 32) {
                        Artwork(image: trackInfo.image)
                        controls
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("CitizenRadio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: { trackInfo.reloadSettings() }) {
                SettingsView(player: player, savedURL: $savedURL, relayStatus: trackInfo.relayStatus)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(trackInfo.lines.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if let artist = trackInfo.lines.artist {
                    Text(artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text(model.status)
                    .font(.body)
                    .foregroundStyle(player.state.errorMessage == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("playbackStatus")
            }

            Button {
                switch model.control {
                case .play: player.playFromControls()
                case .stop: player.stop()
                }
            } label: {
                Image(systemName: model.control == .stop ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            }
            .disabled(!model.isControlEnabled)
            .accessibilityLabel(model.control == .stop ? "Stop" : "Play")
            .accessibilityIdentifier("playbackButton")

            AudioRoutePicker()
                .frame(width: 44, height: 44)
                .accessibilityLabel("Audio output")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Artwork: View {
    let image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(uiColor: .secondarySystemFill))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 360, maxHeight: 360)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "radio")
                        .font(.system(size: 72, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif
