import Foundation
import XCTest
@testable import CitizenRadioCore

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
        defaults.set(0, forKey: "citizenRadio.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, BoostSettings.defaultAmountSats)
    }

    func testStoredAmountOverTheMaximumGivesOneHundredSats() {
        defaults.set(100_001, forKey: "citizenRadio.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, BoostSettings.defaultAmountSats)
    }

    func testStoredAmountOfOneStays() {
        defaults.set(1, forKey: "citizenRadio.autoBoost.amountSats")

        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.amountSats, 1)
    }

    func testStoredAmountOfOneHundredThousandStays() {
        defaults.set(100_000, forKey: "citizenRadio.autoBoost.amountSats")

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

    func testAppNameDefaultIsCitizenRadio() {
        let settings = BoostSettings(defaults: defaults)
        XCTAssertEqual(settings.appName, BoostSettings.defaultAppName)
    }

    func testAppNameSetterCutsSeventyCharactersToSixtyFour() {
        let settings = BoostSettings(defaults: defaults)
        settings.appName = String(repeating: "a", count: 70)
        XCTAssertEqual(settings.appName.count, BoostSettings.maxNameLength)
    }

    func testEmptyAppNameGivesCitizenRadio() {
        let settings = BoostSettings(defaults: defaults)
        settings.appName = ""
        XCTAssertEqual(settings.appName, BoostSettings.defaultAppName)
    }

    func testWhiteSpaceAppNameGivesCitizenRadio() {
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

}
