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

    /// ADR 0018: after a connect, the /metadata snapshot gives the payload of the block that plays.
    func testMetadataSnapshotPayloadPairsWithRelayTrackByBlockGuid() throws {
        let body = """
        {
            "event_id": "DFnUwDM1mzcljaF4pI9Q6w",
            "seq": 45,
            "metadata": {
                "title": "Pharaoh's Dance",
                "eventGuid": "event-guid",
                "blockGuid": "block-b",
                "value": {
                    "destinations": [{ "type": "lnaddress", "address": "name@merchant.io", "split": 100 }]
                }
            }
        }
        """
        let snapshot = try XCTUnwrap(LiveValuePayload.decodeMetadataSnapshot(Data(body.utf8)))
        var pairing = BoostPairing()
        pairing.receive(snapshot)

        let track = TrackDisplay(
            artist: "Miles Davis", title: "Pharaoh's Dance", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "block-b")
        )
        XCTAssertEqual(pairing.payload(for: track), snapshot)
        XCTAssertEqual(pairing.payload(for: track)?.blockGuid, "block-b")
    }

    // MARK: - Chapter states (ADR 0024)

    func testEachChapterStatePairsWithItsOwnBlock() {
        var pairing = BoostPairing()
        for index in 1...3 {
            pairing.receive(payload(title: "Chapter Song \(index)", blockGuid: "block-\(index)"))
        }

        for index in 1...3 {
            let state = TrackDisplay(
                artist: "Chapter Artist \(index)", title: "Chapter Song \(index)", artwork: nil,
                value: TrackDisplay.ValueIdentity(eventGuid: "event", blockGuid: "block-\(index)"),
                songLine: "Show Host - Episode 12"
            )
            XCTAssertEqual(pairing.payload(for: state)?.blockGuid, "block-\(index)")
        }
    }

    // ADR 0026: the payload title of a payable block is "artist - title" (publisher ADR 0029).
    func testTitlePairingMatchesArtistAndTitleOfTheTrack() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Anni Powell - Beyond the Hills", blockGuid: "block-1"))

        let track = TrackDisplay(artist: "Anni Powell", title: "Beyond the Hills", artwork: nil)
        XCTAssertEqual(pairing.payload(for: track)?.blockGuid, "block-1")
    }

    func testTitlePairingMatchesTheSongLineOfTheTrack() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Anni Powell - Beyond the Hills", blockGuid: "block-1"))

        let track = TrackDisplay(
            artist: "Other", title: "Other", artwork: nil, songLine: "anni powell -  Beyond the Hills"
        )
        XCTAssertEqual(pairing.payload(for: track)?.blockGuid, "block-1")
    }

    func testTitlePairingPrefersTheKeyOverTheTitle() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Anni Powell - Beyond the Hills", blockGuid: "key-block"))
        pairing.receive(payload(title: "Beyond the Hills", blockGuid: "title-block"))

        let track = TrackDisplay(artist: "Anni Powell", title: "Beyond the Hills", artwork: nil)
        XCTAssertEqual(pairing.payload(for: track)?.blockGuid, "key-block")
    }

    func testTitlePairingGivesNilForANonPayableKeyMatch() {
        var pairing = BoostPairing()
        pairing.receive(payload(title: "Anni Powell - Beyond the Hills", blockGuid: "block-1", payable: false))

        let track = TrackDisplay(artist: "Anni Powell", title: "Beyond the Hills", artwork: nil)
        XCTAssertNil(pairing.payload(for: track))
    }

    func testDeadBlockWithAStationTitleNeverPairs() throws {
        let json = """
        {
            "title": "HeyCitizen Test Stream",
            "eventGuid": "event-guid",
            "blockGuid": "dead-block",
            "value": {
                "model": { "type": "lightning", "method": "lnaddress" },
                "destinations": [
                    { "name": "No V4V payment route", "type": "lnaddress",
                      "address": "no-v4v-track@example.invalid", "split": "100" }
                ]
            }
        }
        """
        var pairing = BoostPairing()
        pairing.receive(try XCTUnwrap(LiveValuePayload.decode(Data(json.utf8))))

        let byTitle = TrackDisplay(artist: "HeyCitizen", title: "HeyCitizen Test Stream", artwork: nil)
        XCTAssertNil(pairing.payload(for: byTitle))
        let byKey = TrackDisplay(artist: "Other", title: "Other", artwork: nil, songLine: "HeyCitizen Test Stream")
        XCTAssertNil(pairing.payload(for: byKey))
        let byGuid = TrackDisplay(
            artist: "HeyCitizen", title: "Jingle", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "dead-block")
        )
        XCTAssertNil(pairing.payload(for: byGuid))
    }
}
