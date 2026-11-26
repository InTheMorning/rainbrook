#if os(iOS)
import AppIntents
import SwiftUI
#if SWIFT_PACKAGE
import RainbrookCore
#endif

@main
@MainActor
struct RainbrookApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // SwiftPM links the app code as a static archive. This reference keeps
        // RadioIntents.o, and so the App Intents, in the xtool binary. See ADR 0003.
        RadioShortcuts.updateAppShortcutParameters()
        // ADR 0022 §The playback log: the store reads the file off the main actor.
        Task { await PlaybackLogStore.shared.load() }
    }

    var body: some Scene {
        WindowGroup {
            PlayerView(player: RadioPlayer.shared)
                .onOpenURL { url in
                    switch RadioURLAction(url) {
                    case .play?: RadioPlayer.shared.playFromControls()
                    case .stop?: RadioPlayer.shared.stop()
                    case nil: break
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // ADR 0022 §The playback log: write the log when the app goes to the background.
            guard phase == .background else { return }
            Task { await PlaybackLogStore.shared.flush() }
        }
    }
}
#endif
