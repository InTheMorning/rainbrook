#if os(iOS)
import AppIntents

struct PlayRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Rainbrook"
    static let description = IntentDescription("Play the stream saved in Rainbrook.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RadioPlayer.shared.playAndWait()
        return .result()
    }
}

struct StopRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Stop Rainbrook"
    static let description = IntentDescription("Stop Rainbrook playback.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RadioPlayer.shared.stop()
        return .result()
    }
}

struct RadioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayRadioIntent(),
            phrases: ["Play \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Play Rainbrook",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopRadioIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: "Stop Rainbrook",
            systemImageName: "stop.fill"
        )
    }
}
#endif
