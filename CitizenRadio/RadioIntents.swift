#if os(iOS)
import AppIntents

struct PlayRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play CitizenRadio"
    static let description = IntentDescription("Play the stream saved in CitizenRadio.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RadioPlayer.shared.playAndWait()
        return .result()
    }
}

struct StopRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Stop CitizenRadio"
    static let description = IntentDescription("Stop CitizenRadio playback.")
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
            shortTitle: "Play CitizenRadio",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopRadioIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: "Stop CitizenRadio",
            systemImageName: "stop.fill"
        )
    }
}
#endif
