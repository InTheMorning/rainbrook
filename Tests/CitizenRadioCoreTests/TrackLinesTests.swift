import Foundation
import XCTest
@testable import CitizenRadioCore

final class TrackLinesTests: XCTestCase {
    // MARK: - select with relay and ICY

    func testSelectGivesRelayTrackWhenBothRelayAndICYArePresent() {
        let relay = TrackDisplay(
            artist: "Relay Artist",
            title: "Relay Title",
            artwork: .url(URL(string: "https://example.com/art.jpg")!)
        )
        let icy = IcyTrack(artist: "ICY Artist", title: "ICY Title")

        let result = TrackLines.select(relay: relay, icy: icy)

        XCTAssertEqual(result.title, "Relay Title")
        XCTAssertEqual(result.artist, "Relay Artist")
        XCTAssertNotNil(result.artwork)
    }

    // MARK: - select with only ICY

    func testSelectGivesICYTitleAndArtistWithNoArtworkWhenOnlyICYIsPresent() {
        let icy = IcyTrack(artist: "ICY Artist", title: "ICY Title")

        let result = TrackLines.select(relay: nil, icy: icy)

        XCTAssertEqual(result.title, "ICY Title")
        XCTAssertEqual(result.artist, "ICY Artist")
        XCTAssertNil(result.artwork)
    }

    // MARK: - select with neither

    func testSelectGivesDefaultWhenNeitherRelayNorICYArePresent() {
        let result = TrackLines.select(relay: nil, icy: nil)

        XCTAssertEqual(result.title, TrackLines.defaultTitle)
        XCTAssertNil(result.artist)
        XCTAssertNil(result.artwork)
    }

    // MARK: - empty relay title

    func testEmptyRelayTitleGivesDefaultTitle() {
        let relay = TrackDisplay(artist: "Relay Artist", title: "", artwork: nil)

        let result = TrackLines.select(relay: relay, icy: nil)

        XCTAssertEqual(result.title, TrackLines.defaultTitle)
    }

    // MARK: - empty relay artist

    func testEmptyRelayArtistGivesNil() {
        let relay = TrackDisplay(artist: "", title: "Relay Title", artwork: nil)

        let result = TrackLines.select(relay: relay, icy: nil)

        XCTAssertNil(result.artist)
    }

    // MARK: - nowPlayingArtist

    func testNowPlayingArtistGivesTheArtist() {
        let lines = TrackLines(title: "Title", artist: "Artist", artwork: nil)

        XCTAssertEqual(lines.nowPlayingArtist, "Artist")
    }

    func testNowPlayingArtistGivesDefaultWhenArtistIsNil() {
        let lines = TrackLines(title: "Title", artist: nil, artwork: nil)

        XCTAssertEqual(lines.nowPlayingArtist, TrackLines.defaultNowPlayingArtist)
    }
}
