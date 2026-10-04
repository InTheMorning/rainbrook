import SwiftUI

@main
@MainActor
struct CitizenRadioApp: App {
    var body: some Scene {
        WindowGroup {
            RadioView(player: RadioPlayer.shared)
        }
    }
}

