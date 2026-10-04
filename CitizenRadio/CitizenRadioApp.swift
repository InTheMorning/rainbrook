#if os(iOS)
import SwiftUI
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

@main
@MainActor
struct CitizenRadioApp: App {
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
