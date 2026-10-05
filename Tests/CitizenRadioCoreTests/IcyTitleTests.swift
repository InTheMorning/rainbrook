import Foundation
import XCTest
@testable import CitizenRadioCore

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
}
