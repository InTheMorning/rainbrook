import Foundation
import XCTest
@testable import RainbrookCore

/// Task boost-pairing-task-002: before the first ICY text, the boost model gets the relay track of the screen.
/// `TrackInfoModel.updateLines` gives `IcySync.track(withoutIcy:)` to `BoostModel.selectedTrack`.
/// `BoostModel` sets the manual target when `BoostPairing.payload(for:)` gives a payload.
final class BoostBeforeIcyTests: XCTestCase {
    private let payableJSON = """
    {
        "title": "Anni Powell - Beyond the Hills",
        "eventGuid": "event-guid",
        "blockGuid": "song-block",
        "value": { "destinations": [{ "type": "lnaddress", "address": "anni@getalby.com", "split": 100 }] }
    }
    """

    private let deadJSON = """
    {
        "title": "HeyCitizen Test Stream",
        "eventGuid": "event-guid",
        "blockGuid": "dead-block",
        "value": {
            "model": { "type": "lightning", "method": "lnaddress" },
            "destinations": [{ "type": "lnaddress", "address": "no-v4v-track@example.invalid", "split": "100" }]
        }
    }
    """

    private func pairing(_ jsons: String...) throws -> BoostPairing {
        var pairing = BoostPairing()
        for json in jsons {
            pairing.receive(try XCTUnwrap(LiveValuePayload.decode(Data(json.utf8))))
        }
        return pairing
    }

    private func track(block: String) -> TrackDisplay {
        TrackDisplay(
            artist: "Anni Powell", title: "Beyond the Hills", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: block)
        )
    }

    func testWithoutIcyThePayableRelayTrackIsTheBoostTarget() throws {
        var sync = IcySync()
        let relay = track(block: "song-block")
        sync.receive(relay)

        let selected = sync.track(withoutIcy: relay)
        XCTAssertFalse(sync.hasIcy)
        XCTAssertEqual(selected, relay)
        XCTAssertEqual(try pairing(payableJSON).payload(for: try XCTUnwrap(selected))?.blockGuid, "song-block")
    }

    func testWithoutIcyTheDeadBlockIsNoBoostTarget() throws {
        var sync = IcySync()
        let relay = TrackDisplay(
            artist: "HeyCitizen", title: "Station Jingle", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "dead-block")
        )
        sync.receive(relay)

        let selected = try XCTUnwrap(sync.track(withoutIcy: relay))
        XCTAssertNil(try pairing(payableJSON, deadJSON).payload(for: selected))
    }

    func testWithIcyTheTrackThatTheIcyTextSelectsWins() {
        var sync = IcySync()
        let relay = track(block: "song-block")
        sync.receive(relay)
        sync.receiveIcyText("Other Artist - Other Song")

        XCTAssertNil(sync.track(withoutIcy: relay))
        sync.receiveIcyText("Anni Powell - Beyond the Hills")
        XCTAssertEqual(sync.track(withoutIcy: nil), relay)
    }

    func testRelayTracksBeforeTheFirstIcyTextStartNoAutoBoost() {
        var trigger = BoostTrigger()
        XCTAssertNil(trigger.selectedTrack(track(block: "song-block"), at: 0))
        XCTAssertNil(trigger.selectedTrack(track(block: "next-block"), at: 200))
        // The first ICY text starts no candidate (ADR 0013 trigger rule 1), so no boost follows.
        XCTAssertNil(trigger.receiveIcyText("Anni Powell - Beyond the Hills", track: track(block: "next-block"), at: 210))
        XCTAssertNil(trigger.selectedTrack(track(block: "third-block"), at: 400))
    }
}
