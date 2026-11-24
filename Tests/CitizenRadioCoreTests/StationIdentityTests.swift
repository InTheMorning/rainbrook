import Foundation
import XCTest
@testable import CitizenRadioCore

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
}
