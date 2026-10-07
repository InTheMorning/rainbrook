import Foundation
import XCTest
@testable import CitizenRadioCore

final class BoostStatusTextTests: XCTestCase {
    // MARK: - Results

    func testAllPartsPaid() {
        let result = BoostResult(parts: [part(50, .confirmed), part(30, .confirmed), part(20, .confirmed)])
        XCTAssertEqual(BoostStatusText.text(for: result), "Boosted 100 sats.")
    }

    func testSomePartsPaid() {
        let result = BoostResult(parts: [part(40, .confirmed), part(30, .confirmed), part(30, .failed)])
        XCTAssertEqual(BoostStatusText.text(for: result), "Boosted 70 sats. 1 of 3 payments failed.")
    }

    func testPartWithAnUnknownResult() {
        let result = BoostResult(parts: [part(50, .confirmed), part(30, .unknown), part(20, .failed)])
        XCTAssertEqual(
            BoostStatusText.text(for: result),
            "Boosted 50 sats. 1 of 3 payments failed. The result of 1 payments is not known."
        )
    }

    func testUnknownResultAndNoFailedPart() {
        let result = BoostResult(parts: [part(50, .confirmed), part(50, .unknown)])
        XCTAssertEqual(
            BoostStatusText.text(for: result),
            "Boosted 50 sats. The result of 1 payments is not known."
        )
    }

    func testOnlyUnknownResultsDoNotSayBoosted() {
        let result = BoostResult(parts: [part(30, .unknown), part(30, .unknown), part(40, .failed)])
        XCTAssertEqual(
            BoostStatusText.text(for: result),
            "1 of 3 payments failed. The result of 2 payments is not known."
        )
    }

    func testNoPartPaid() {
        let result = BoostResult(parts: [part(50, .failed), part(50, .failed)])
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

    private func part(_ sats: Int, _ result: BoostPaymentResult) -> BoostPartResult {
        BoostPartResult(name: nil, kind: .keysend, sats: sats, result: result)
    }

}
