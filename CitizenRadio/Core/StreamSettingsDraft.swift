import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var chimeEnabled: Bool
    public var dailyLimitSats: Int
    /// ADR 0020 §Stream quality: the Settings choice for the HLS bitrate maximum.
    public var streamQuality: StreamQuality
    public var boostEnabled: Bool
    public var boostAmountText: String
    public var boostMessage: String
    public var boostSenderName: String
    public var boostAppName: String
    public var boostMinimumPlaySecondsText: String
    public let savedChimeEnabled: Bool
    public let savedDailyLimitSats: Int
    public let savedStreamQuality: StreamQuality
    public let savedBoostEnabled: Bool
    public let savedBoostAmountText: String
    public let savedBoostMessage: String
    public let savedBoostSenderName: String
    public let savedBoostAppName: String
    public let savedBoostMinimumPlaySecondsText: String

    public init(
        chimeEnabled: Bool, dailyLimitSats: Int, streamQuality: StreamQuality,
        boostEnabled: Bool, boostAmountText: String, boostMessage: String,
        boostSenderName: String, boostAppName: String, boostMinimumPlaySecondsText: String
    ) {
        self.chimeEnabled = chimeEnabled
        self.dailyLimitSats = dailyLimitSats
        self.streamQuality = streamQuality
        self.boostEnabled = boostEnabled
        self.boostAmountText = boostAmountText
        self.boostMessage = boostMessage
        self.boostSenderName = boostSenderName
        self.boostAppName = boostAppName
        self.boostMinimumPlaySecondsText = boostMinimumPlaySecondsText
        self.savedChimeEnabled = chimeEnabled
        self.savedDailyLimitSats = dailyLimitSats
        self.savedStreamQuality = streamQuality
        self.savedBoostEnabled = boostEnabled
        self.savedBoostAmountText = boostAmountText
        self.savedBoostMessage = boostMessage
        self.savedBoostSenderName = boostSenderName
        self.savedBoostAppName = boostAppName
        self.savedBoostMinimumPlaySecondsText = boostMinimumPlaySecondsText
    }

    /// The value is no while the boost amount text, or the minimum play time text, is not correct.
    /// Else a change of any boost value, or the stream quality, makes the value yes.
    public var canSave: Bool {
        guard BoostSettings.parseAmount(boostAmountText) != nil,
              BoostSettings.parseMinimumPlaySeconds(boostMinimumPlaySecondsText) != nil else {
            return false
        }
        return chimeEnabled != savedChimeEnabled
            || dailyLimitSats != savedDailyLimitSats
            || streamQuality != savedStreamQuality
            || boostEnabled != savedBoostEnabled
            || boostAmountText != savedBoostAmountText
            || boostMessage != savedBoostMessage
            || boostSenderName != savedBoostSenderName
            || boostAppName != savedBoostAppName
            || boostMinimumPlaySecondsText != savedBoostMinimumPlaySecondsText
    }
}
