import Foundation
import XCTest
@testable import RainbrookCore

final class Bolt11Tests: XCTestCase {
    // The data part after the last "1" is a bech32 text. It does not contain "1".
    private let body = "pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4js"

    func testMicroMultiplier() {
        XCTAssertEqual(Bolt11.amountMsat("lnbc2500u1" + body), 250_000_000)
    }

    func testMilliMultiplier() {
        XCTAssertEqual(Bolt11.amountMsat("lnbc20m1" + body), 2_000_000_000)
    }

    func testNanoMultiplierOnTestnet() {
        XCTAssertEqual(Bolt11.amountMsat("lntb10n1" + body), 1_000)
    }

    func testPicoMultiplierThatIsAMultipleOfTen() {
        XCTAssertEqual(Bolt11.amountMsat("lnbc10p1" + body), 1)
    }

    func testPicoMultiplierThatIsNotAMultipleOfTenGivesNil() {
        XCTAssertNil(Bolt11.amountMsat("lnbc15p1" + body))
    }

    func testNoMultiplierIsBitcoin() {
        XCTAssertEqual(Bolt11.amountMsat("lnbc2" + "1" + body), 200_000_000_000)
    }

    func testNoAmountGivesNil() {
        XCTAssertNil(Bolt11.amountMsat("lnbc1" + body))
    }

    func testInvalidPrefixGivesNil() {
        XCTAssertNil(Bolt11.amountMsat("lnxy2500u1" + body))
        XCTAssertNil(Bolt11.amountMsat("bc2500u1" + body))
        XCTAssertNil(Bolt11.amountMsat("lnbc2500u"))
    }

    func testUppercaseInvoice() {
        XCTAssertEqual(Bolt11.amountMsat("LNBC2500U1" + body.uppercased()), 250_000_000)
    }

    func testLongerNetworkNamesComeFirst() {
        XCTAssertEqual(Bolt11.amountMsat("lnbcrt5u1" + body), 500_000)
        XCTAssertEqual(Bolt11.amountMsat("lntbs5u1" + body), 500_000)
        XCTAssertEqual(Bolt11.amountMsat("lnsb5u1" + body), 500_000)
    }

    func testLeadingZeroGivesNil() {
        XCTAssertNil(Bolt11.amountMsat("lnbc0250u1" + body))
    }

    func testOtherCharacterInAmountGivesNil() {
        XCTAssertNil(Bolt11.amountMsat("lnbc25x0u1" + body))
        XCTAssertNil(Bolt11.amountMsat("lnbcu1" + body))
    }

    func testOverflowGivesNil() {
        XCTAssertNil(Bolt11.amountMsat("lnbc100000000000" + "1" + body))
        XCTAssertNil(Bolt11.amountMsat("lnbc99999999999999999999p1" + body))
    }
}
