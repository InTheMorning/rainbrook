import Foundation
import XCTest
@testable import RainbrookCore

/// ADR 0013 §Settings.
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

    func testStoredAmountOfZeroGivesOneHundredSats() {
        defaults.set(0, forKey: "rainbrook.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, BoostSettings.defaultAmountSats)
    }

    func testStoredAmountOverTheMaximumGivesOneHundredSats() {
        defaults.set(100_001, forKey: "rainbrook.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, BoostSettings.defaultAmountSats)
    }

    func testStoredAmountOfOneStays() {
        defaults.set(1, forKey: "rainbrook.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, 1)
    }

    func testStoredAmountOfOneHundredThousandStays() {
        defaults.set(100_000, forKey: "rainbrook.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, 100_000)
    }

    func testMessageDefaultIsEmpty() {
        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.message, "")
    }

    func testMessageSetterCutsTwoHundredFiftyCharactersToTwoHundred() {
        let settings = BoostSettings(defaults: defaults)
        settings.message = String(repeating: "a", count: 250)
        XCTAssertEqual(settings.message.count, BoostSettings.maxMessageLength)
    }

    func testSenderNameDefaultIsEmpty() {
        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.senderName, "")
    }

    func testSenderNameSetterCutsSeventyCharactersToSixtyFour() {
        let settings = BoostSettings(defaults: defaults)
        settings.senderName = String(repeating: "a", count: 70)
        XCTAssertEqual(settings.senderName.count, BoostSettings.maxNameLength)
    }

    func testAppNameDefaultIsRainbrook() {
        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.appName, BoostSettings.defaultAppName)
    }

    func testAppNameSetterCutsSeventyCharactersToSixtyFour() {
        let settings = BoostSettings(defaults: defaults)
        settings.appName = String(repeating: "a", count: 70)
        XCTAssertEqual(settings.appName.count, BoostSettings.maxNameLength)
    }

    func testEmptyAppNameGivesRainbrook() {
        let settings = BoostSettings(defaults: defaults)
        settings.appName = ""
        XCTAssertEqual(settings.appName, BoostSettings.defaultAppName)
    }

    func testWhiteSpaceAppNameGivesRainbrook() {
        let settings = BoostSettings(defaults: defaults)
        settings.appName = "   "
        XCTAssertEqual(settings.appName, BoostSettings.defaultAppName)
    }

    func testParseAmountGivesTheWholeNumber() {
        XCTAssertEqual(BoostSettings.parseAmount("1"), 1)
        XCTAssertEqual(BoostSettings.parseAmount(" 250 "), 250)
        XCTAssertEqual(BoostSettings.parseAmount("100000"), 100_000)
    }

    func testParseAmountGivesNilForAnInvalidText() {
        XCTAssertNil(BoostSettings.parseAmount("0"))
        XCTAssertNil(BoostSettings.parseAmount("100001"))
        XCTAssertNil(BoostSettings.parseAmount("-5"))
        XCTAssertNil(BoostSettings.parseAmount("12.5"))
        XCTAssertNil(BoostSettings.parseAmount("1e3"))
        XCTAssertNil(BoostSettings.parseAmount("abc"))
        XCTAssertNil(BoostSettings.parseAmount(""))
    }

    func testAppNameIsStoredWithoutOuterWhiteSpace() {
        let settings = BoostSettings(defaults: defaults)
        settings.appName = "  MyRadio  "
        XCTAssertEqual(settings.appName, "MyRadio")
    }

    // MARK: - Minimum play time (ADR 0016 §The minimum play time)

    func testMinimumPlaySecondsDefaultIsSixty() {
        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.minimumPlaySeconds, 60)
    }

    func testMinimumPlaySecondsStoredValueIsSaved() {
        let settings = BoostSettings(defaults: defaults)
        settings.minimumPlaySeconds = 30

        let read = BoostSettings(defaults: defaults)
        XCTAssertEqual(read.minimumPlaySeconds, 30)
    }

    func testStoredMinimumPlaySecondsOverTheMaximumGivesSixty() {
        defaults.set(601, forKey: "rainbrook.autoBoost.minimumPlaySeconds")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.minimumPlaySeconds, BoostSettings.defaultMinimumPlaySeconds)
    }

    func testParseMinimumPlaySecondsGivesTheWholeNumber() {
        XCTAssertEqual(BoostSettings.parseMinimumPlaySeconds("0"), 0)
        XCTAssertEqual(BoostSettings.parseMinimumPlaySeconds("600"), 600)
        XCTAssertEqual(BoostSettings.parseMinimumPlaySeconds(" 60 "), 60)
    }

    func testParseMinimumPlaySecondsGivesNilForAnInvalidText() {
        XCTAssertNil(BoostSettings.parseMinimumPlaySeconds("601"))
        XCTAssertNil(BoostSettings.parseMinimumPlaySeconds("-1"))
        XCTAssertNil(BoostSettings.parseMinimumPlaySeconds("1.5"))
        XCTAssertNil(BoostSettings.parseMinimumPlaySeconds("abc"))
    }

}
