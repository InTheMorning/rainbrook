import Foundation
import XCTest
@testable import CitizenRadioCore

final class StationTests: XCTestCase {
    private let streamText = "https://bastone.heycitizen.xyz/stream"
    private let alternateText = "https://bastone.heycitizen.xyz/hls/live.m3u8"
    private let trackInfoText = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"

    // MARK: - Name

    func testEmptyNameGivesTheHostOfTheStream() throws {
        let station = try Station(
            name: "",
            streamText: streamText,
            alternateStreamText: "",
            trackInfoText: ""
        )
        XCTAssertEqual(station.name, "bastone.heycitizen.xyz")
    }

    func testA41CharacterNameKeeps40Characters() throws {
        let longName = String(repeating: "a", count: 41)
        let station = try Station(
            name: longName,
            streamText: streamText,
            alternateStreamText: "",
            trackInfoText: ""
        )
        XCTAssertEqual(station.name.count, Station.maxNameLength)
        XCTAssertEqual(station.name, String(repeating: "a", count: 40))
    }

    // MARK: - Alternate stream

    func testEmptyAlternateGivesNil() throws {
        let station = try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: "   ",
            trackInfoText: ""
        )
        XCTAssertNil(station.alternateStream)
    }

    func testAlternateEqualToTheStreamThrowsSameStreams() {
        XCTAssertThrowsError(try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: streamText,
            trackInfoText: ""
        )) { error in
            XCTAssertEqual(error as? StationError, .sameStreams)
        }
    }

    // MARK: - Bad fields

    func testABadStreamThrowsStreamInvalidURL() {
        XCTAssertThrowsError(try Station(
            name: "Station",
            streamText: "not a url",
            alternateStreamText: "",
            trackInfoText: ""
        )) { error in
            XCTAssertEqual(error as? StationError, .stream(.invalidURL))
        }
    }

    func testABadTrackInfoThrowsTrackInfo() {
        XCTAssertThrowsError(try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: "",
            trackInfoText: "not a relay uri"
        )) { error in
            XCTAssertEqual(error as? StationError, .trackInfo)
        }
    }

    // MARK: - streams

    func testStreamsGivesOneURLWithNoAlternate() throws {
        let station = try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: "",
            trackInfoText: ""
        )
        XCTAssertEqual(station.streams, [station.stream])
    }

    func testStreamsGivesTheStreamThenTheAlternate() throws {
        let station = try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: alternateText,
            trackInfoText: ""
        )
        XCTAssertEqual(station.streams, [station.stream, station.alternateStream])
        XCTAssertEqual(station.streams.map(\.absoluteString), [streamText, alternateText])
    }

    // MARK: - event

    func testEventGivesTheParsedRelayEvent() throws {
        let station = try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: "",
            trackInfoText: trackInfoText
        )
        XCTAssertEqual(station.event?.eventID, "DFnUwDM1mzcljaF4pI9Q6w")
    }

    func testEventGivesNilWithNoTrackInfo() throws {
        let station = try Station(
            name: "Station",
            streamText: streamText,
            alternateStreamText: "",
            trackInfoText: ""
        )
        XCTAssertNil(station.event)
    }
}
