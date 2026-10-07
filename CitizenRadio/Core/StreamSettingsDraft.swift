import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var text: String
    public var chimeEnabled: Bool
    public var dailyLimitSats: Int
    public var relayText: String
    public var boostEnabled: Bool
    public var boostAmountText: String
    public var boostMessage: String
    public var boostSenderName: String
    public var boostAppName: String
    public let savedURL: String
    public let savedChimeEnabled: Bool
    public let savedDailyLimitSats: Int
    public let savedRelayText: String
    public let savedBoostEnabled: Bool
    public let savedBoostAmountText: String
    public let savedBoostMessage: String
    public let savedBoostSenderName: String
    public let savedBoostAppName: String

    public init(
        savedURL: String, chimeEnabled: Bool, dailyLimitSats: Int, relayText: String,
        boostEnabled: Bool, boostAmountText: String, boostMessage: String,
        boostSenderName: String, boostAppName: String
    ) {
        self.text = savedURL
        self.chimeEnabled = chimeEnabled
        self.dailyLimitSats = dailyLimitSats
        self.relayText = relayText
        self.boostEnabled = boostEnabled
        self.boostAmountText = boostAmountText
        self.boostMessage = boostMessage
        self.boostSenderName = boostSenderName
        self.boostAppName = boostAppName
        self.savedURL = savedURL
        self.savedChimeEnabled = chimeEnabled
        self.savedDailyLimitSats = dailyLimitSats
        self.savedRelayText = relayText
        self.savedBoostEnabled = boostEnabled
        self.savedBoostAmountText = boostAmountText
        self.savedBoostMessage = boostMessage
        self.savedBoostSenderName = boostSenderName
        self.savedBoostAppName = boostAppName
    }

    public var urlChanged: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != savedURL
    }

    /// The value is no while the boost amount text is not a correct amount.
    /// Else a change of any boost value makes the value yes.
    public var canSave: Bool {
        guard BoostSettings.parseAmount(boostAmountText) != nil else {
            return false
        }
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
            || boostAmountText != savedBoostAmountText
            || boostMessage != savedBoostMessage
            || boostSenderName != savedBoostSenderName
            || boostAppName != savedBoostAppName
    }
}
