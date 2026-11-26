import Foundation
import XCTest
@testable import RainbrookCore

final class BoostSplitTests: XCTestCase {
    private func destination(_ name: String, split: Double, fee: Bool = false) -> LiveValueDestination {
        LiveValueDestination(
            kind: .lightningAddress(name: name, host: "merchant.io"), name: name,
            split: split, fee: fee, customKey: nil, customValue: nil
        )
    }

    func testFeeComesFirstAndTheRestIsSharedInDestinationOrder() {
        let a = destination("a", split: 90)
        let b = destination("b", split: 10)
        let c = destination("c", split: 5, fee: true)

        let parts = BoostSplit.parts(amountSats: 100, destinations: [a, b, c])

        XCTAssertEqual(parts, [
            BoostPart(destination: a, sats: 85),
            BoostPart(destination: b, sats: 9),
            BoostPart(destination: c, sats: 5)
        ])
    }

    func testPartUnderOneSatIsLeftOut() {
        let a = destination("a", split: 999)
        let b = destination("b", split: 1)

        let parts = BoostSplit.parts(amountSats: 100, destinations: [a, b])

        XCTAssertEqual(parts, [BoostPart(destination: a, sats: 99)])
    }

    func testFeeSplitsOverOneHundredPercentGiveNoParts() {
        let a = destination("a", split: 100)
        let fee1 = destination("fee1", split: 60, fee: true)
        let fee2 = destination("fee2", split: 50, fee: true)

        XCTAssertEqual(BoostSplit.parts(amountSats: 100, destinations: [a, fee1, fee2]), [])
    }

    func testSumIsNotMoreThanTheAmountForThreeEqualSplits() {
        let a = destination("a", split: 1)
        let b = destination("b", split: 1)
        let c = destination("c", split: 1)

        let parts = BoostSplit.parts(amountSats: 100, destinations: [a, b, c])

        XCTAssertEqual(parts.map(\.sats), [33, 33, 33])
    }

    func testSumIsNotMoreThanTheAmountWithFeeAndRoundedShares() {
        let a = destination("a", split: 33.4)
        let b = destination("b", split: 66.6)
        let fee = destination("fee", split: 2.5, fee: true)

        let parts = BoostSplit.parts(amountSats: 21, destinations: [a, b, fee])

        // 21 sats: the fee gets 525 msat (0 sats). The remaining 20,475 msat gives 6,838 and 13,636 msat.
        XCTAssertEqual(parts.map(\.sats), [6, 13])
    }

    func testFeeOnlyLeavesTheRestUnpaid() {
        let fee = destination("fee", split: 10, fee: true)

        XCTAssertEqual(BoostSplit.parts(amountSats: 100, destinations: [fee]), [BoostPart(destination: fee, sats: 10)])
    }

    func testZeroAmountGivesNoParts() {
        XCTAssertEqual(BoostSplit.parts(amountSats: 0, destinations: [destination("a", split: 100)]), [])
    }

    func testNoDestinationsGivesNoParts() {
        XCTAssertEqual(BoostSplit.parts(amountSats: 100, destinations: []), [])
    }

    /// The boost sheet on 2026-11-25: Phil Owen 97 and four recipients of 1 each, 100 sats.
    /// Each 1 % part is 990 msat. The app pays 0 sats for it, but the share stays in the list.
    func testSharesKeepARecipientUnderOneSat() {
        let phil = destination("phil", split: 97)
        let small = (1...4).map { destination("small\($0)", split: 1) }

        let shares = BoostSplit.shares(amountSats: 100, destinations: [phil] + small)

        XCTAssertEqual(shares.map(\.sats), [96, 0, 0, 0, 0])
        XCTAssertEqual(shares[0].percent, 9700.0 / 101, accuracy: 1e-9)
        XCTAssertEqual(shares[1].percent, 100.0 / 101, accuracy: 1e-9)
        XCTAssertEqual(BoostSplit.parts(amountSats: 100, destinations: [phil] + small).map(\.sats), [96])
    }

    func testSharePercentUsesTheFeeSplitAndTheRest() {
        let a = destination("a", split: 90)
        let b = destination("b", split: 10)
        let fee = destination("fee", split: 5, fee: true)

        let shares = BoostSplit.shares(amountSats: 100, destinations: [a, b, fee])

        XCTAssertEqual(shares.map(\.percent), [85.5, 9.5, 5])
        XCTAssertEqual(shares.map(\.sats), [85, 9, 5])
    }

    func testFeeSplitsOverOneHundredPercentGiveNoShares() {
        let a = destination("a", split: 100)
        let fee1 = destination("fee1", split: 60, fee: true)
        let fee2 = destination("fee2", split: 50, fee: true)

        XCTAssertEqual(BoostSplit.shares(amountSats: 100, destinations: [a, fee1, fee2]), [])
    }
}
