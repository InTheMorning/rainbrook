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
    /// ADR 0017 §The station list: Play is active only with a selected station.
    @State private var hasSelectedStation = StationStore().selected != nil
    @State private var showingSettings = false
    @State private var showingBoost = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(player: RadioPlayer) {
        self.player = player
        _trackInfo = StateObject(wrappedValue: TrackInfoModel(player: player))
    }

    private var model: PlayerScreenModel {
        PlayerScreenModel(
            state: player.state,
            hasSavedStream: hasSelectedStation,
            waitingForNetwork: player.waitingForNetwork
        )
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
            .sheet(isPresented: $showingSettings, onDismiss: {
                hasSelectedStation = StationStore().selected != nil
                trackInfo.reloadSettings()
            }) {
                SettingsView(
                    player: player,
                    relayStatus: trackInfo.relayStatus,
                    boostStatus: trackInfo.boost.status
                )
                .environmentObject(trackInfo.boost)
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
                // ADR 0019: show the album below the artist. No line when there is no album.
                if let album = trackInfo.lines.album {
                    Text(album)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // ADR 0014 §Player screen: no status line while the stream plays.
                if let status = model.status {
                    Text(status)
                        .font(.body)
                        .foregroundStyle(player.state.errorMessage == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("playbackStatus")
                }
                // ADR 0017 §The fallback: show when the alternate stream plays.
                if player.usingAlternateStream {
                    Text("Alternate stream")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("alternateStream")
                }
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

            HStack(spacing: 32) {
                AudioRoutePicker()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Audio output")
                Button {
                    showingBoost = true
                } label: {
                    Label("Boost", systemImage: "bolt.heart")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .disabled(trackInfo.boost.manualTarget == nil)
                .accessibilityIdentifier("boostButton")
                // ADR 0013 §Manual boost: the sheet keeps the track of the moment that it opened.
                .sheet(isPresented: $showingBoost) {
                    BoostSheet(boost: trackInfo.boost)
                }
            }
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
                if let image, (image.images?.count ?? 0) >= 2 {
                    AnimatedArtwork(image: image)
                } else if let image {
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

/// Shows an animated image in a `UIImageView`, because SwiftUI `Image` does not animate it.
/// ADR 0015 §Display. The view fills and clips like the still image.
private struct AnimatedArtwork: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image !== image {
            uiView.image = image
        }
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
