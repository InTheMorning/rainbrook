import Foundation
import XCTest
@testable import CitizenRadioCore

final class BoostStatusTextTests: XCTestCase {
    // MARK: - Results

    func testAllPartsPaid() {
        let result = BoostResult(paidSats: 100, unknownSats: 0, paidParts: 3, unknownParts: 0, totalParts: 3)
        XCTAssertEqual(BoostStatusText.text(for: result), "Boosted 100 sats.")
    }

    func testSomePartsPaid() {
        let result = BoostResult(paidSats: 70, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 3)
        XCTAssertEqual(BoostStatusText.text(for: result), "Boosted 70 sats. 1 of 3 payments failed.")
    }

    func testPartWithAnUnknownResult() {
        let result = BoostResult(paidSats: 50, unknownSats: 30, paidParts: 1, unknownParts: 1, totalParts: 3)
        XCTAssertEqual(
            BoostStatusText.text(for: result),
            "Boosted 50 sats. 1 of 3 payments failed. The result of 1 payments is not known."
        )
    }

    func testUnknownResultAndNoFailedPart() {
        let result = BoostResult(paidSats: 50, unknownSats: 50, paidParts: 1, unknownParts: 1, totalParts: 2)
        XCTAssertEqual(
            BoostStatusText.text(for: result),
            "Boosted 50 sats. The result of 1 payments is not known."
        )
    }

    func testOnlyUnknownResultsDoNotSayBoosted() {
        let result = BoostResult(paidSats: 0, unknownSats: 60, paidParts: 0, unknownParts: 2, totalParts: 3)
        XCTAssertEqual(
            BoostStatusText.text(for: result),
            "1 of 3 payments failed. The result of 2 payments is not known."
        )
    }

    func testNoPartPaid() {
        let result = BoostResult(paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: 2)
        XCTAssertEqual(BoostStatusText.text(for: result), "The boost failed. No payment was sent.")
    }

    // MARK: - Skip reasons

    func testOverDailyLimit() {
        XCTAssertEqual(
            BoostStatusText.text(for: .overDailyLimit(remainingSats: 40)),
            "No boost. Only 40 sats of the daily limit remain."
        )
    }

    func testNothingToPay() {
        XCTAssertEqual(
            BoostStatusText.text(for: .nothingToPay),
            "No boost. The track has no payment destination."
        )
    }

    func testReasonsWithNoMessage() {
        XCTAssertNil(BoostStatusText.text(for: .disabled))
        XCTAssertNil(BoostStatusText.text(for: .noTrack))
        XCTAssertNil(BoostStatusText.text(for: .noPayload))
        XCTAssertNil(BoostStatusText.text(for: .alreadyPaid))
    }

    func testNoWallet() {
        XCTAssertEqual(BoostStatusText.noWallet, "No boost. Connect a wallet.")
    }
}
