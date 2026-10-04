import Foundation
import XCTest
@testable import CitizenRadioCore

final class SpendingLimitTests: XCTestCase {
    private let today = "2026-10-04"
    private let yesterday = "2026-10-03"
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "SpendingLimitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultDailySatsIsOneThousand() {
        XCTAssertEqual(SpendingLimit.defaultDailySats, 1000)
    }

    func testPermitsAnAmountThatFits() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 0, day: today)
        XCTAssertTrue(limit.permits(1000, on: today))
    }

    func testPermitsRejectsAnAmountThatDoesNotFit() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 800, day: today)
        XCTAssertFalse(limit.permits(201, on: today))
    }

    func testPermitsRejectsZero() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 0, day: today)
        XCTAssertFalse(limit.permits(0, on: today))
    }

    func testRecordingAddsAmountsOnTheSameDay() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 200, day: today)
        let updated = limit.recording(300, on: today)
        XCTAssertEqual(updated.spentSats, 500)
        XCTAssertEqual(updated.day, today)
    }

    func testRemainingOnANewDayIsTheFullDailyLimit() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 900, day: yesterday)
        XCTAssertEqual(limit.remaining(on: today), 1000)
    }

    func testRecordingOnANewDayStartsFromTheAmount() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 900, day: yesterday)
        let updated = limit.recording(300, on: today)
        XCTAssertEqual(updated.spentSats, 300)
        XCTAssertEqual(updated.day, today)
    }

    func testRemainingNeverGoesBelowZero() {
        let limit = SpendingLimit(dailySats: 1000, spentSats: 1500, day: today)
        XCTAssertEqual(limit.remaining(on: today), 0)
    }

    func testDayKeyGivesTheFixedDateInTheFixedTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12))!
        XCTAssertEqual(SpendingLimit.dayKey(for: date, calendar: calendar), "2026-10-04")
    }

    func testStoreDefaultDailyLimitIsOneThousandSats() {
        XCTAssertEqual(SpendingLimitStore(defaults: defaults).limit.dailySats, 1000)
    }

    func testStoreKeepsAStoredChoice() {
        SpendingLimitStore(defaults: defaults).setDailySats(2500)
        XCTAssertEqual(SpendingLimitStore(defaults: defaults).limit.dailySats, 2500)
    }

    func testStoreUnknownStoredValueUsesDefault() {
        defaults.set(777, forKey: "citizenRadio.dailyLimitSats")
        XCTAssertEqual(SpendingLimitStore(defaults: defaults).limit.dailySats, 1000)
    }

    func testStoreRecordPersistsTheSpentAmount() {
        let store = SpendingLimitStore(defaults: defaults)
        store.record(300, on: "2026-10-04")
        store.record(200, on: "2026-10-04")
        XCTAssertEqual(store.limit.spentSats, 500)
        XCTAssertEqual(store.limit.day, "2026-10-04")
    }

    func testStoreRecordOnANewDayResetsTheSpentAmount() {
        let store = SpendingLimitStore(defaults: defaults)
        store.record(900, on: "2026-10-03")
        store.record(100, on: "2026-10-04")
        XCTAssertEqual(store.limit.spentSats, 100)
        XCTAssertEqual(store.limit.day, "2026-10-04")
    }
}
