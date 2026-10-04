#if os(iOS)
import AppIntents

struct PlayRadioIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play CitizenRadio"
    static var description = IntentDescription("Play the stream saved in CitizenRadio.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try await RadioPlayer.shared.playAndWait()
        return .result()
    }
}

struct StopRadioIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Stop CitizenRadio"
    static var description = IntentDescription("Stop CitizenRadio playback.")
    static var openAppWhenRun = false

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
