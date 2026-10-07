import Foundation
import XCTest
@testable import CitizenRadioCore

final class BoostPlanTests: XCTestCase {
    private let day = "2026-10-06"
    private let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
    private let otherTrack = TrackDisplay(artist: "Miles Davis", title: "Blue in Green", artwork: nil)

    private func pairing() -> BoostPairing {
        let json = """
        {
            "title": "So What",
            "eventGuid": "event-1",
            "blockGuid": "block-1",
            "value": { "destinations": [
                { "type": "lnaddress", "address": "artist@merchant.io", "split": 100 }
            ] }
        }
        """
        var pairing = BoostPairing()
        pairing.receive(try! LiveValuePayload.decode(Data(json.utf8))!)
        return pairing
    }

    /// A payload with a fee split of more than 100 %. The split gives no parts for it.
    private func feeOverPairing() -> BoostPairing {
        let json = """
        {
            "title": "So What",
            "eventGuid": "event-1",
            "blockGuid": "block-1",
            "value": { "destinations": [
                { "type": "lnaddress", "address": "artist@merchant.io", "split": 100 },
                { "type": "lnaddress", "address": "app@merchant.io", "split": 150, "fee": true }
            ] }
        }
        """
        var pairing = BoostPairing()
        pairing.receive(try! LiveValuePayload.decode(Data(json.utf8))!)
        return pairing
    }

    private var openLimit: SpendingLimit {
        SpendingLimit(dailySats: 1000, spentSats: 0, day: day)
    }

    private var usedLimit: SpendingLimit {
        SpendingLimit(dailySats: 1000, spentSats: 950, day: day)
    }

    private func decide(
        enabled: Bool = true, amountSats: Int = 100, track: TrackDisplay?,
        pairing: BoostPairing, paidBlocks: Set<String> = [], limit: SpendingLimit
    ) -> BoostDecision {
        BoostPlan.decide(
            enabled: enabled, amountSats: amountSats, track: track, pairing: pairing,
            paidBlocks: paidBlocks, limit: limit, day: day
        )
    }

    func testDisabledSkips() {
        XCTAssertEqual(decide(enabled: false, track: track, pairing: pairing(), limit: openLimit), .skip(.disabled))
    }

    func testNoTrackSkips() {
        XCTAssertEqual(decide(track: nil, pairing: pairing(), limit: openLimit), .skip(.noTrack))
    }

    func testNoPayloadSkips() {
        XCTAssertEqual(decide(track: otherTrack, pairing: pairing(), limit: openLimit), .skip(.noPayload))
    }

    func testPaidBlockSkips() {
        XCTAssertEqual(
            decide(track: track, pairing: pairing(), paidBlocks: ["block-1"], limit: openLimit),
            .skip(.alreadyPaid)
        )
    }

    func testOverDailyLimitSkipsWithRemainingSats() {
        XCTAssertEqual(
            decide(track: track, pairing: pairing(), limit: usedLimit),
            .skip(.overDailyLimit(remainingSats: 50))
        )
    }

    func testFeeOverOneHundredPercentGivesNothingToPay() {
        XCTAssertEqual(decide(track: track, pairing: feeOverPairing(), limit: openLimit), .skip(.nothingToPay))
    }

    func testPayGivesThePayloadAndTheParts() {
        let pairing = pairing()
        let payload = pairing.payload(for: track)!

        XCTAssertEqual(
            decide(track: track, pairing: pairing, limit: openLimit),
            .pay(payload: payload, parts: [BoostPart(destination: payload.destinations[0], sats: 100)])
        )
    }

    func testRuleOrder() {
        // In each step, all subsequent rules also stop the boost. The first rule that stops it gives the result.
        XCTAssertEqual(
            decide(enabled: false, track: nil, pairing: BoostPairing(), paidBlocks: ["block-1"], limit: usedLimit),
            .skip(.disabled)
        )
        XCTAssertEqual(
            decide(track: nil, pairing: feeOverPairing(), paidBlocks: ["block-1"], limit: usedLimit),
            .skip(.noTrack)
        )
        XCTAssertEqual(
            decide(track: otherTrack, pairing: feeOverPairing(), paidBlocks: ["block-1"], limit: usedLimit),
            .skip(.noPayload)
        )
        XCTAssertEqual(
            decide(track: track, pairing: feeOverPairing(), paidBlocks: ["block-1"], limit: usedLimit),
            .skip(.alreadyPaid)
        )
        XCTAssertEqual(
            decide(track: track, pairing: feeOverPairing(), limit: usedLimit),
            .skip(.overDailyLimit(remainingSats: 50))
        )
        XCTAssertEqual(
            decide(track: track, pairing: feeOverPairing(), limit: openLimit),
            .skip(.nothingToPay)
        )
    }

    // MARK: - Manual boost

    private func decideManual(track: TrackDisplay?, pairing: BoostPairing) -> BoostDecision {
        BoostPlan.decideManual(amountSats: 100, track: track, pairing: pairing)
    }

    func testManualNoTrackSkips() {
        XCTAssertEqual(decideManual(track: nil, pairing: pairing()), .skip(.noTrack))
    }

    func testManualNoPayloadSkips() {
        XCTAssertEqual(decideManual(track: otherTrack, pairing: pairing()), .skip(.noPayload))
    }

    func testManualNoPartGivesNothingToPay() {
        XCTAssertEqual(decideManual(track: track, pairing: feeOverPairing()), .skip(.nothingToPay))
    }

    func testManualPayGivesThePayloadAndTheParts() {
        let pairing = pairing()
        let payload = pairing.payload(for: track)!

        XCTAssertEqual(
            decideManual(track: track, pairing: pairing),
            .pay(payload: payload, parts: [BoostPart(destination: payload.destinations[0], sats: 100)])
        )
    }

    func testManualPaysWhereAutoBoostStopsForThePaidBlockAndTheDailyLimit() {
        let pairing = pairing()
        let payload = pairing.payload(for: track)!

        // The same inputs stop an auto-boost.
        XCTAssertEqual(
            decide(track: track, pairing: pairing, paidBlocks: ["block-1"], limit: usedLimit),
            .skip(.alreadyPaid)
        )
        XCTAssertEqual(decide(track: track, pairing: pairing, limit: usedLimit), .skip(.overDailyLimit(remainingSats: 50)))

        XCTAssertEqual(
            decideManual(track: track, pairing: pairing),
            .pay(payload: payload, parts: [BoostPart(destination: payload.destinations[0], sats: 100)])
        )
    }

    func testManualRuleOrder() {
        // In each step, all subsequent rules also stop the boost. The first rule that stops it gives the result.
        XCTAssertEqual(decideManual(track: nil, pairing: BoostPairing()), .skip(.noTrack))
        XCTAssertEqual(decideManual(track: nil, pairing: feeOverPairing()), .skip(.noTrack))
        XCTAssertEqual(decideManual(track: otherTrack, pairing: feeOverPairing()), .skip(.noPayload))
    }
}
