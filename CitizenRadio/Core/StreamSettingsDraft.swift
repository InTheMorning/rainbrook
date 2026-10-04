import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var text: String
    public var chimeEnabled: Bool
    public var bufferSeconds: Int
    public var dailyLimitSats: Int
    public let savedURL: String
    public let savedChimeEnabled: Bool
    public let savedBufferSeconds: Int
    public let savedDailyLimitSats: Int

    public init(savedURL: String, chimeEnabled: Bool, bufferSeconds: Int, dailyLimitSats: Int) {
        self.text = savedURL
        self.chimeEnabled = chimeEnabled
        self.bufferSeconds = bufferSeconds
        self.dailyLimitSats = dailyLimitSats
        self.savedURL = savedURL
        self.savedChimeEnabled = chimeEnabled
        self.savedBufferSeconds = bufferSeconds
        self.savedDailyLimitSats = dailyLimitSats
    }

    public var urlChanged: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != savedURL
    }

    public var canSave: Bool {
        if urlChanged {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return chimeEnabled != savedChimeEnabled
            || bufferSeconds != savedBufferSeconds
            || dailyLimitSats != savedDailyLimitSats
    }
}
