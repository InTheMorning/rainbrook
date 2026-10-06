import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var text: String
    public var chimeEnabled: Bool
    public var dailyLimitSats: Int
    public var relayText: String
    public var boostEnabled: Bool
    public var boostAmountSats: Int
    public let savedURL: String
    public let savedChimeEnabled: Bool
    public let savedDailyLimitSats: Int
    public let savedRelayText: String
    public let savedBoostEnabled: Bool
    public let savedBoostAmountSats: Int

    public init(
        savedURL: String, chimeEnabled: Bool, dailyLimitSats: Int, relayText: String,
        boostEnabled: Bool, boostAmountSats: Int
    ) {
        self.text = savedURL
        self.chimeEnabled = chimeEnabled
        self.dailyLimitSats = dailyLimitSats
        self.relayText = relayText
        self.boostEnabled = boostEnabled
        self.boostAmountSats = boostAmountSats
        self.savedURL = savedURL
        self.savedChimeEnabled = chimeEnabled
        self.savedDailyLimitSats = dailyLimitSats
        self.savedRelayText = relayText
        self.savedBoostEnabled = boostEnabled
        self.savedBoostAmountSats = boostAmountSats
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
            || dailyLimitSats != savedDailyLimitSats
            || relayTextChanged
            || boostEnabled != savedBoostEnabled
            || boostAmountSats != savedBoostAmountSats
    }
}
