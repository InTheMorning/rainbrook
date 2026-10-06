import Foundation
import XCTest
@testable import CitizenRadioCore

final class BoostPairingTests: XCTestCase {
    /// Decodes a payload fixture with one payable, or no, destination.
    private func payload(title: String, blockGuid: String, payable: Bool = true) -> LiveValuePayload {
        let destinations = payable
            ? #"[{ "type": "lnaddress", "address": "name@merchant.io", "split": 100 }]"#
            : "[]"
        let json = """
        {
            "title": "\(title)",
            "eventGuid": "event-guid",
            "blockGuid": "\(blockGuid)",
            "value": { "destinations": \(destinations) }
        }
        """
        return try! LiveValuePayload.decode(Data(json.utf8))!
    }

    func testCapacityConstantIsEight() {
        XCTAssertEqual(BoostPairing.capacity, 8)
    }

    func testPairsByNormalizedTitleWithNewestWinning() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "older-block"))
        pairing.receive(payload(title: "PHARAOH'S DANCE", blockGuid: "newer-block"))

        let track = TrackDisplay(artist: "Miles Davis", title: "pharaoh's dance", artwork: nil)
        let matched = pairing.payload(for: track)

        XCTAssertEqual(matched?.blockGuid, "newer-block")
    }

    func testPairingByTitleGivesNilForDifferentTitle() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "block-1"))

        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        XCTAssertNil(pairing.payload(for: track))
    }

    func testPairingByTitleGivesNilForNonPayablePayload() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "block-1", payable: false))

        let track = TrackDisplay(artist: "Miles Davis", title: "Pharaoh's Dance", artwork: nil)
        XCTAssertNil(pairing.payload(for: track))
    }

    func testPairsByBlockGuidEvenWhenNewerPayloadSharesTitle() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "block-old"))
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "block-new"))

        let track = TrackDisplay(
            artist: "Miles Davis", title: "Pharaoh's Dance", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "block-old")
        )
        let matched = pairing.payload(for: track)

        XCTAssertEqual(matched?.blockGuid, "block-old")
    }

    func testPairingByBlockGuidGivesNilWhenMissing() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "block-1"))

        let track = TrackDisplay(
            artist: "Miles Davis", title: "Pharaoh's Dance", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "block-missing")
        )
        XCTAssertNil(pairing.payload(for: track))
    }

    func testListKeepsEightPayloadsNewestFirst() {
        var pairing = BoostPairing()
        for index in 1...9 {
            pairing.receive(payload(title: "Track \(index)", blockGuid: "block-\(index)"))
        }

        let newest = TrackDisplay(
            artist: "Artist", title: "ignored", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "block-9")
        )
        XCTAssertNotNil(pairing.payload(for: newest))

        let oldest = TrackDisplay(
            artist: "Artist", title: "ignored", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "block-1")
        )
        XCTAssertNil(pairing.payload(for: oldest))
    }

    func testEqualBlockGuidReplacesOlderPayload() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "First Title", blockGuid: "block-1"))
        pairing.receive(payload(title: "Second Title", blockGuid: "block-1"))

        let track = TrackDisplay(
            artist: "Artist", title: "ignored", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "block-1")
        )
        let matched = pairing.payload(for: track)

        XCTAssertEqual(matched?.title, "Second Title")
    }

    func testClearRemovesAllPayloads() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Pharaoh's Dance", blockGuid: "block-1"))
        pairing.clear()

        let track = TrackDisplay(artist: "Artist", title: "Pharaoh's Dance", artwork: nil)
        XCTAssertNil(pairing.payload(for: track))
    }
}
