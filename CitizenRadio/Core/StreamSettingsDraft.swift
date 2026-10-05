import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var text: String
    public var chimeEnabled: Bool
    public var bufferSeconds: Int
    public var dailyLimitSats: Int
    public var relayText: String
    public let savedURL: String
    public let savedChimeEnabled: Bool
    public let savedBufferSeconds: Int
    public let savedDailyLimitSats: Int
    public let savedRelayText: String

    public init(
        savedURL: String, chimeEnabled: Bool, bufferSeconds: Int, dailyLimitSats: Int, relayText: String
    ) {
        self.text = savedURL
        self.chimeEnabled = chimeEnabled
        self.bufferSeconds = bufferSeconds
        self.dailyLimitSats = dailyLimitSats
        self.relayText = relayText
        self.savedURL = savedURL
        self.savedChimeEnabled = chimeEnabled
        self.savedBufferSeconds = bufferSeconds
        self.savedDailyLimitSats = dailyLimitSats
        self.savedRelayText = relayText
    }

    public var urlChanged: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != savedURL
    }

    public var canSave: Bool {
        if urlChanged {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let relayTextChanged =
            relayText.trimmingCharacters(in: .whitespacesAndNewlines)
            != savedRelayText.trimmingCharacters(in: .whitespacesAndNewlines)
        return chimeEnabled != savedChimeEnabled
            || bufferSeconds != savedBufferSeconds
            || dailyLimitSats != savedDailyLimitSats
            || relayTextChanged
    }
}
