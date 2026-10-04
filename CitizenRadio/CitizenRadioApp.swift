#if os(iOS)
import AppIntents
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@main
@MainActor
struct CitizenRadioApp: App {
    init() {
        // SwiftPM links the app code as a static archive. This reference keeps
        // RadioIntents.o, and so the App Intents, in the xtool binary. See ADR 0003.
        RadioShortcuts.updateAppShortcutParameters()
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
    }
}
#endif
