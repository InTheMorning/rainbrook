import Foundation
import XCTest
@testable import RainbrookCore

/// ADR 0028: the station title and image from the dead block payload.
/// The payloads copy the relay event of the HeyCitizen test station on 2026-11-24.
final class StationIdentityTests: XCTestCase {
    private let stationImage = "https://music.cancelbandcamp.com/TestAlbum/test/Gigachad-Transparent-small.png"

    private func deadJSON(title: String, image: String?) -> String {
        let imageField = image.map { "\"image\": \"\($0)\"," } ?? ""
        return """
        {
            "title": "\(title)", \(imageField)
            "eventGuid": "event-guid",
            "blockGuid": "dead-block",
            "value": {
                "model": { "type": "lightning", "method": "lnaddress" },
                "destinations": [{ "type": "lnaddress", "address": "no-v4v-track@example.invalid", "split": "100" }]
            }
        }
        """
    }

    private let songJSON = """
    {
        "title": "Empath Eyes - Apathy",
        "image": "https://music.behindthesch3m3s.com/wp-content/uploads/Empath%20Eyes/Echo%20Chamber/Empath%20Eyes%20Echo%20Chamber.jpg",
        "eventGuid": "event-guid",
        "blockGuid": "song-block",
        "value": { "destinations": [{ "type": "lnaddress", "address": "anni@getalby.com", "split": 100 }] }
    }
    """

    private func payload(_ json: String) throws -> LiveValuePayload {
        try XCTUnwrap(LiveValuePayload.decode(Data(json.utf8)))
    }

    func testTheDeadBlockGivesTheStationTitleAndImage() throws {
        let dead = try payload(deadJSON(title: "HeyCitizen Test Stream", image: stationImage))
        XCTAssertTrue(dead.isDeadBlock)
        XCTAssertFalse(dead.isPayable)
        XCTAssertEqual(
            StationIdentity(dead),
            StationIdentity(title: "HeyCitizen Test Stream", image: URL(string: stationImage))
        )
        XCTAssertEqual(StationIdentity(dead)?.artwork, .url(try XCTUnwrap(URL(string: stationImage))))
    }

    /// The dead block of the operator decision of 2026-11-24: zero destinations, and no feedGuid or itemGuid.
    func testADeadBlockWithNoDestinationsGivesTheStationAndIsNotPayable() throws {
        let json = """
        {
            "title": "HeyCitizen Test Stream",
            "image": "\(stationImage)",
            "eventGuid": "event-guid",
            "blockGuid": "dead-block",
            "value": { "model": { "type": "lightning", "method": "lnaddress" }, "destinations": [] }
        }
        """
        let dead = try payload(json)
        XCTAssertTrue(dead.isDeadBlock)
        XCTAssertFalse(dead.isPayable)
        XCTAssertEqual(
            StationIdentity(dead),
            StationIdentity(title: "HeyCitizen Test Stream", image: URL(string: stationImage))
        )
        var pairing = BoostPairing()
        pairing.receive(dead)
        let track = TrackDisplay(
            artist: "", title: "HeyCitizen Test Stream", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "dead-block")
        )
        XCTAssertNil(pairing.payload(for: track))
    }

    func testTheDefaultDeadBlockTitleGivesNoStationTitle() throws {
        let dead = try payload(deadJSON(title: LiveValuePayload.placeholderTitle, image: nil))
        XCTAssertTrue(dead.isDeadBlock)
        XCTAssertEqual(StationIdentity(dead), StationIdentity(title: nil, image: nil))
    }

    func testAPayableBlockIsNoStationButKeepsItsImage() throws {
        let song = try payload(songJSON)
        XCTAssertFalse(song.isDeadBlock)
        XCTAssertNil(StationIdentity(song))
        XCTAssertEqual(song.image?.host, "music.behindthesch3m3s.com")
    }

    func testABlockWithNoPayableDestinationAndNoReservedHostIsNoDeadBlock() throws {
        let json = """
        {
            "title": "Some Artist - Some Song",
            "eventGuid": "event-guid",
            "blockGuid": "song-block",
            "value": { "destinations": [{ "type": "lnaddress", "address": "nohost", "split": 100 }] }
        }
        """
        let song = try payload(json)
        XCTAssertFalse(song.isPayable)
        XCTAssertFalse(song.isDeadBlock)
        XCTAssertNil(StationIdentity(song))
    }

    func testOnlyAWebImageIsKept() throws {
        XCTAssertNil(try payload(deadJSON(title: "Station", image: "file:///etc/passwd")).image)
        XCTAssertNil(try payload(deadJSON(title: "Station", image: "not a url")).image)
        XCTAssertNil(try payload(deadJSON(title: "Station", image: nil)).image)
        XCTAssertNotNil(try payload(deadJSON(title: "Station", image: "http://example.org/a.png")).image)
    }

    func testTheDefaultLinesTakeTheStationTitle() {
        let station = StationIdentity(title: "HeyCitizen Test Stream", image: nil)
        let lines = TrackLines.select(relay: nil, icy: nil).withStation(station)
        XCTAssertEqual(lines.title, "HeyCitizen Test Stream")
        XCTAssertNil(lines.artist)
        XCTAssertNil(lines.artwork)
        XCTAssertEqual(lines.nowPlayingArtist, TrackLines.defaultNowPlayingArtist)
    }

    func testTrackLinesDoNotChange() {
        let station = StationIdentity(title: "HeyCitizen Test Stream", image: nil)
        let relay = TrackDisplay(artist: "AzuraCast.com", title: "AzuraCast is Live!", artwork: nil, value: nil)
        let relayLines = TrackLines.select(relay: relay, icy: nil)
        XCTAssertEqual(relayLines.withStation(station), relayLines)
        let icyLines = TrackLines.select(relay: nil, icy: IcyTitle.parse("Empath Eyes - Apathy"))
        XCTAssertEqual(icyLines.withStation(station), icyLines)
    }

    func testNoStationTitleKeepsTheDefaultLines() {
        let lines = TrackLines.select(relay: nil, icy: nil)
        XCTAssertEqual(lines.withStation(nil), lines)
        XCTAssertEqual(lines.withStation(StationIdentity(title: nil, image: nil)), lines)
    }

    /// The jingle at 05:22 on 2026-11-24: an empty ICY text, then `{"track": null}`, then the dead block.
    func testAnEmptyIcyTextDuringAJingleShowsTheStationTitle() throws {
        var sync = IcySync()
        sync.receive(TrackDisplay(artist: "Skatenigs", title: "PTSTD", artwork: nil, value: nil))
        sync.receiveIcyText("Skatenigs - PTSTD")
        sync.receiveIcyText("")
        sync.receive(nil)
        let station = StationIdentity(try payload(deadJSON(title: "HeyCitizen Test Stream", image: stationImage)))
        XCTAssertEqual(sync.lines.withStation(station).title, "HeyCitizen Test Stream")
    }

    private func anni(block: String?) -> TrackDisplay {
        TrackDisplay(
            artist: "Anni Powell", title: "Beyond the Hills", artwork: .url(URL(string: "https://example.org/anni.jpg")!),
            value: block.map { TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: $0) },
            songLine: "Anni Powell - Beyond the Hills"
        )
    }

    /// The jingle at 12:27:40 on 2026-11-24: the ICY text stays at the song, and the relay sends the song again
    /// with no value block for 24 s. Then the next song starts.
    func testAJingleWithNoTitleShowsTheStationLines() throws {
        let station = StationIdentity(title: "HeyCitizen Test Stream", image: URL(string: stationImage))
        var sync = IcySync()
        sync.receive(anni(block: nil))
        sync.receiveIcyText("Anni Powell - Beyond the Hills")
        // The new song starts with no value block. Its value block did not end, so the song lines stay.
        XCTAssertFalse(sync.valueEnded(sync.relayTrack))
        sync.receive(anni(block: "anni-block"))
        XCTAssertFalse(sync.valueEnded(sync.relayTrack))
        XCTAssertEqual(sync.lines.withStation(station, valueEnded: false).title, "Beyond the Hills")

        sync.receive(anni(block: nil))
        let valueEnded = sync.valueEnded(sync.relayTrack)
        XCTAssertTrue(valueEnded)
        let lines = sync.lines.withStation(station, valueEnded: valueEnded)
        XCTAssertEqual(lines, TrackLines(title: "HeyCitizen Test Stream", artist: nil, artwork: nil))

        let rods = TrackDisplay(
            artist: "12 Rods", title: "Red", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "rods-block"), songLine: "12 Rods - Red"
        )
        sync.receiveIcyText("12 Rods - Red")
        sync.receive(rods)
        XCTAssertFalse(sync.valueEnded(sync.relayTrack))
        XCTAssertEqual(sync.lines.withStation(station, valueEnded: false).title, "Red")
    }

    func testAValueBlockAgainEndsTheJingleState() {
        var sync = IcySync()
        sync.receive(anni(block: "anni-block"))
        sync.receive(anni(block: nil))
        XCTAssertTrue(sync.valueEnded(anni(block: nil)))
        XCTAssertFalse(sync.valueEnded(anni(block: "anni-block")))
        sync.receive(anni(block: "anni-block-2"))
        XCTAssertFalse(sync.valueEnded(anni(block: nil)))
        sync.receive(anni(block: nil))
        sync.clearStates()
        XCTAssertFalse(sync.valueEnded(anni(block: nil)))
    }

    func testWithNoStationAnEndedValueKeepsTheSongLines() {
        let lines = TrackLines.select(relay: anni(block: nil), icy: nil)
        XCTAssertEqual(lines.withStation(nil, valueEnded: true), lines)
        let imageOnly = StationIdentity(title: nil, image: URL(string: stationImage))
        XCTAssertEqual(
            lines.withStation(imageOnly, valueEnded: true),
            TrackLines(title: TrackLines.defaultTitle, artist: nil, artwork: nil)
        )
    }

    /// ADR 0026 and ADR 0028: the title pairing finds the payload of the song that ended, so the manual target
    /// needs the value ended test. `BoostModel.updateManualTarget` applies it.
    func testTheTitlePairingStillFindsTheSongThatEnded() throws {
        let json = """
        {
            "title": "Anni Powell - Beyond the Hills",
            "eventGuid": "event-guid",
            "blockGuid": "anni-block",
            "value": { "destinations": [{ "type": "lnaddress", "address": "anni@getalby.com", "split": 100 }] }
        }
        """
        var pairing = BoostPairing()
        pairing.receive(try payload(json))
        pairing.receive(try payload(deadJSON(title: "HeyCitizen Test Stream", image: stationImage)))
        XCTAssertEqual(pairing.payload(for: anni(block: nil))?.blockGuid, "anni-block")
    }

    private let anniPayloadJSON = """
    {
        "title": "Anni Powell - Beyond the Hills",
        "eventGuid": "event-guid",
        "blockGuid": "anni-block",
        "value": { "destinations": [{ "type": "lnaddress", "address": "anni@getalby.com", "split": 100 }] }
    }
    """

    /// Review of 713753d, item 1: the dead block payload arrives, and no display state with no value block follows.
    /// The current track is the song with its value block. No manual target exists.
    func testTheDeadBlockPayloadAloneGivesNoManualTarget() throws {
        var pairing = BoostPairing()
        pairing.receive(try payload(anniPayloadJSON))
        let song = anni(block: "anni-block")
        XCTAssertEqual(pairing.manualPayload(for: song, valueEnded: false)?.blockGuid, "anni-block")

        pairing.receive(try payload(deadJSON(title: "HeyCitizen Test Stream", image: stationImage)))
        XCTAssertTrue(pairing.deadBlockIsNewest)
        XCTAssertNil(pairing.manualPayload(for: song, valueEnded: false))
        XCTAssertNil(pairing.manualPayload(for: anni(block: nil), valueEnded: false))
        // The auto-boost path keeps the payload of the song that ended.
        XCTAssertEqual(pairing.payload(for: song)?.blockGuid, "anni-block")
    }

    func testTheDeadBlockPayloadWithNoDestinationsGivesNoManualTarget() throws {
        let json = """
        {
            "title": "HeyCitizen Test Stream", "eventGuid": "event-guid", "blockGuid": "dead-block",
            "value": { "model": { "type": "lightning", "method": "lnaddress" }, "destinations": [] }
        }
        """
        var pairing = BoostPairing()
        pairing.receive(try payload(anniPayloadJSON))
        pairing.receive(try payload(json))
        XCTAssertNil(pairing.manualPayload(for: anni(block: "anni-block"), valueEnded: false))
    }

    func testTheNextSongPayloadGivesTheManualTargetAgain() throws {
        let rodsJSON = """
        {
            "title": "12 Rods - Red", "eventGuid": "event-guid", "blockGuid": "rods-block",
            "value": { "destinations": [{ "type": "lnaddress", "address": "rods@getalby.com", "split": 100 }] }
        }
        """
        var pairing = BoostPairing()
        pairing.receive(try payload(anniPayloadJSON))
        pairing.receive(try payload(deadJSON(title: "HeyCitizen Test Stream", image: stationImage)))
        pairing.receive(try payload(rodsJSON))
        let rods = TrackDisplay(
            artist: "12 Rods", title: "Red", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-guid", blockGuid: "rods-block")
        )
        XCTAssertEqual(pairing.manualPayload(for: rods, valueEnded: false)?.blockGuid, "rods-block")
    }

    /// Review of 713753d, item 1 with the display state: the value block ended, so no manual target exists,
    /// also while the payload of the song is the newest.
    func testAnEndedValueGivesNoManualTarget() throws {
        var pairing = BoostPairing()
        pairing.receive(try payload(anniPayloadJSON))
        XCTAssertNil(pairing.manualPayload(for: anni(block: nil), valueEnded: true))
    }

    /// Review of 713753d, item 4: a different ICY text clears the ended value blocks of earlier songs.
    func testADifferentIcyTextClearsTheEndedValueBlocks() {
        var sync = IcySync()
        sync.receiveIcyText("Anni Powell - Beyond the Hills")
        sync.receive(anni(block: "anni-block"))
        sync.receive(anni(block: nil))
        XCTAssertTrue(sync.valueEnded(sync.relayTrack))
        // The same text again, as in each HLS segment, keeps the condition.
        sync.receiveIcyText("Anni Powell - Beyond the Hills")
        XCTAssertTrue(sync.valueEnded(sync.relayTrack))
        sync.receiveIcyText("12 Rods - Red")
        sync.receiveIcyText("Anni Powell - Beyond the Hills")
        XCTAssertFalse(sync.valueEnded(sync.relayTrack))
    }
}
