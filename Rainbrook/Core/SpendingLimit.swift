import Foundation

/// A daily sats limit, the quantity spent, and the day it applies to.
public struct SpendingLimit: Equatable, Sendable {
    /// The daily limit, in sats, that applies when UserDefaults holds no value.
    public static let defaultDailySats = 1000
    /// The daily limit choices a user can pick, in sats.
    public static let choices = [100, 500, 1000, 2500, 5000, 10000]

    public let dailySats: Int
    public let spentSats: Int
    /// The day that the spent quantity applies to, as "yyyy-MM-dd", in the local time zone.
    public let day: String

    public init(dailySats: Int, spentSats: Int, day: String) {
        self.dailySats = dailySats
        self.spentSats = spentSats
        self.day = day
    }

    /// The sats left to spend on the given day.
    /// The spent quantity is 0 when the given day differs from the stored day.
    public func remaining(on day: String) -> Int {
        let spent = day == self.day ? spentSats : 0
        return max(0, dailySats - spent)
    }

    /// This check permits the quantity only when it is positive and it fits in the remaining sats for the day.
    public func permits(_ amount: Int, on day: String) -> Bool {
        amount > 0 && amount <= remaining(on: day)
    }

    /// A copy with the quantity added to the spent sats for the given day.
    /// On a new day, the spent quantity starts from the quantity.
    public func recording(_ amount: Int, on day: String) -> SpendingLimit {
        let spent = day == self.day ? spentSats + amount : amount
        return SpendingLimit(dailySats: dailySats, spentSats: spent, day: day)
    }

    /// The day key for the given date, as "yyyy-MM-dd", in the calendar time zone.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Stores the daily spending limit and the spent sats, in UserDefaults.
public struct SpendingLimitStore {
    private let defaults: UserDefaults
    private let dailySatsKey = "rainbrook.dailyLimitSats"
    private let spentSatsKey = "rainbrook.spentSats"
    private let spentDayKey = "rainbrook.spentDay"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The current spending limit, as read from UserDefaults.
    /// A stored daily value that is not in `choices` gives `defaultDailySats`.
    public var limit: SpendingLimit {
        let dailySats: Int
        if let stored = defaults.object(forKey: dailySatsKey) as? Int, SpendingLimit.choices.contains(stored) {
            dailySats = stored
        } else {
            dailySats = SpendingLimit.defaultDailySats
        }
        let spentSats = defaults.object(forKey: spentSatsKey) as? Int ?? 0
        let day = defaults.string(forKey: spentDayKey) ?? SpendingLimit.dayKey(for: Date())
        return SpendingLimit(dailySats: dailySats, spentSats: spentSats, day: day)
    }

    /// Sets the daily limit, in sats.
    public func setDailySats(_ sats: Int) {
        defaults.set(sats, forKey: dailySatsKey)
    }

    /// Records a spend of the quantity on the given day, and stores the result.
    public func record(_ amount: Int, on day: String) {
        let updated = limit.recording(amount, on: day)
        defaults.set(updated.spentSats, forKey: spentSatsKey)
        defaults.set(updated.day, forKey: spentDayKey)
    }
}
