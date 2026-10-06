import Foundation
import XCTest
@testable import CitizenRadioCore

/// ADR 0012 §Settings.
final class BoostSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "BoostSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsAreOffAndOneHundredSats() {
        let settings = BoostSettings(defaults: defaults)

        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.amountSats, 100)
    }

    func testStoredValuesAreSaved() {
        let settings = BoostSettings(defaults: defaults)
        settings.isEnabled = true
        settings.amountSats = 500

        let read = BoostSettings(defaults: defaults)
        XCTAssertTrue(read.isEnabled)
        XCTAssertEqual(read.amountSats, 500)
    }

    func testStoredAmountNotAChoiceGivesOneHundredSats() {
        defaults.set(999, forKey: "citizenRadio.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, BoostSettings.defaultAmountSats)
    }
}
