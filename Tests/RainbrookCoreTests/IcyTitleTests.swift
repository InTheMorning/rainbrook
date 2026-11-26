import Foundation
import XCTest
@testable import RainbrookCore

final class IcyTitleTests: XCTestCase {
    func testParsesWithArtistAndTitle() {
        let track = IcyTitle.parse("Miles Davis - Pharaoh's Dance")
        XCTAssertEqual(track?.artist, "Miles Davis")
        XCTAssertEqual(track?.title, "Pharaoh's Dance")
    }

    func testParsesWithoutSeparator() {
        let track = IcyTitle.parse("Pharaoh's Dance")
        XCTAssertNil(track?.artist)
        XCTAssertEqual(track?.title, "Pharaoh's Dance")
    }

    func testParsesMultipleSeparators() {
        let track = IcyTitle.parse("A - B - C")
        XCTAssertEqual(track?.artist, "A")
        XCTAssertEqual(track?.title, "B - C")
    }

    func testParsesEmptyArtist() {
        let track = IcyTitle.parse(" - Title")
        XCTAssertNil(track?.artist)
        XCTAssertEqual(track?.title, "Title")
    }

    func testParsesEmptyTitle() {
        let track = IcyTitle.parse("Artist - ")
        XCTAssertNil(track?.artist)
        XCTAssertEqual(track?.title, "Artist -")
    }

    func testReturnsNilForEmptyText() {
        let track = IcyTitle.parse("   ")
        XCTAssertNil(track)
    }

    func testReturnsNilForEmptyString() {
        let track = IcyTitle.parse("")
        XCTAssertNil(track)
    }

    func testTrimsWhitespaceFromParts() {
        let track = IcyTitle.parse("  Artist  -  Title  ")
        XCTAssertEqual(track?.artist, "Artist")
        XCTAssertEqual(track?.title, "Title")
    }

    func testTrimsWhitespaceWhenNoSeparator() {
        let track = IcyTitle.parse("  Title with spaces  ")
        XCTAssertNil(track?.artist)
        XCTAssertEqual(track?.title, "Title with spaces")
    }

    // MARK: - ADR 0025: the ICY text of one metadata group

    func testTextStreamTitleWinsOverID3() {
        let text = IcyTitle.text(streamTitle: "12 Rods - Red", artist: "Other", title: "Song")
        XCTAssertEqual(text, "12 Rods - Red")
    }

    func testTextEmptyStreamTitleIsAnEmptyIcyText() {
        XCTAssertEqual(IcyTitle.text(streamTitle: "", artist: "12 Rods", title: "Red"), "")
    }

    func testTextJoinsArtistAndTitle() {
        XCTAssertEqual(IcyTitle.text(streamTitle: nil, artist: "12 Rods", title: "Red"), "12 Rods - Red")
    }

    func testTextJoinGivesTheSongLineOfAChapterState() {
        // The orchestrator capture of 2026-11-24 02:00 UTC: TPE1 and TIT2 during a chapter, and the relay songLine.
        let text = IcyTitle.text(
            streamTitle: nil, artist: "DuhLaurien and MaryKate-Ultra", title: "Homegrown Hits - Episode 157"
        )
        XCTAssertEqual(text, "DuhLaurien and MaryKate-Ultra - Homegrown Hits - Episode 157")
    }

    func testTextJoinMatchesTheSongLineKey() throws {
        let json = #"{"track":{"artist":"Rock'n'Roll Breakheart","title":"Games","artwork":null,"songLine":"Rock'n'Roll Breakheart - Games"}}"#
        let track = try XCTUnwrap(TrackDisplay.decode(Data(json.utf8)))
        var sync = IcySync()
        sync.receive(track)
        let text = try XCTUnwrap(IcyTitle.text(streamTitle: nil, artist: "Rock'n'Roll Breakheart", title: "Games"))
        sync.receiveIcyText(text)
        XCTAssertEqual(sync.relayTrack, track)
    }

    func testTextTrimsTheItems() {
        XCTAssertEqual(IcyTitle.text(streamTitle: nil, artist: " 12 Rods ", title: " Red\n"), "12 Rods - Red")
    }

    func testTextTitleAloneWhenNoArtist() {
        XCTAssertEqual(IcyTitle.text(streamTitle: nil, artist: nil, title: "12 Rods - Red"), "12 Rods - Red")
    }

    func testTextTitleAloneWhenArtistIsEmpty() {
        XCTAssertEqual(IcyTitle.text(streamTitle: nil, artist: "  ", title: "Red"), "Red")
    }

    func testTextNilWhenTitleIsEmpty() {
        XCTAssertNil(IcyTitle.text(streamTitle: nil, artist: "12 Rods", title: " "))
    }

    func testTextNilWhenNoItems() {
        XCTAssertNil(IcyTitle.text(streamTitle: nil, artist: nil, title: nil))
    }

    func testTextNilWhenArtistOnly() {
        XCTAssertNil(IcyTitle.text(streamTitle: nil, artist: "12 Rods", title: nil))
    }
}
