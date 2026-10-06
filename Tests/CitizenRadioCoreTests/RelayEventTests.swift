import Foundation
import XCTest
@testable import CitizenRadioCore

final class RelayEventTests: XCTestCase {
    func testParsesFirstFormWithEventID() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        XCTAssertEqual(event.origin, URL(string: "https://api.musicindex.org")!)
        XCTAssertEqual(event.eventID, "DFnUwDM1mzcljaF4pI9Q6w")
    }

    func testParsesFirstFormWithTrailingSlash() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w/"
        let event = try RelayEvent(uri: uri)
        XCTAssertEqual(event.origin, URL(string: "https://api.musicindex.org")!)
        XCTAssertEqual(event.eventID, "DFnUwDM1mzcljaF4pI9Q6w")
    }

    func testParsesSecondFormWithQueryParameter() throws {
        let uri = "https://api.musicindex.org/event?event_id=DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        XCTAssertEqual(event.origin, URL(string: "https://api.musicindex.org")!)
        XCTAssertEqual(event.eventID, "DFnUwDM1mzcljaF4pI9Q6w")
    }

    func testKeepsPort() throws {
        let uri = "https://relay.example.com:8443/v1/liveitems/abc"
        let event = try RelayEvent(uri: uri)
        XCTAssertEqual(event.origin, URL(string: "https://relay.example.com:8443")!)
        XCTAssertEqual(event.eventID, "abc")
    }

    func testRejectsHttpScheme() {
        let uri = "http://api.musicindex.org/v1/liveitems/abc"
        XCTAssertThrowsError(try RelayEvent(uri: uri)) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .scheme)
            let message = (error as? RelayEvent.ParseError)?.errorDescription ?? ""
            XCTAssertEqual(message, "The track info address must start with https.")
        }
    }

    func testRejectsWrongPath() {
        let uri = "https://api.musicindex.org/other/abc"
        XCTAssertThrowsError(try RelayEvent(uri: uri)) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .path)
        }
    }

    func testRejectsEventPathWithoutQueryParam() {
        let uri = "https://api.musicindex.org/event"
        XCTAssertThrowsError(try RelayEvent(uri: uri)) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .path)
        }
    }

    func testRejectsInvalidEventIDWithSlash() {
        let uri = "https://api.musicindex.org/v1/liveitems/abc/def"
        XCTAssertThrowsError(try RelayEvent(uri: uri)) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .eventID)
        }
    }

    func testRejectsInvalidEventIDWithSpace() {
        let uri = "https://api.musicindex.org/v1/liveitems/abc def"
        XCTAssertThrowsError(try RelayEvent(uri: uri)) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .eventID)
        }
    }

    func testDisplayURL() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        let expected = URL(string: "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w/display")!
        XCTAssertEqual(event.displayURL, expected)
    }

    func testDisplayEventsURL() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        let expected = URL(string: "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w/display/events")!
        XCTAssertEqual(event.displayEventsURL, expected)
    }

    func testArtworkURL() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        let sha256 = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        let expected = URL(string: "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w/artwork/\(sha256)")!
        XCTAssertEqual(event.artworkURL(sha256: sha256), expected)
    }

    func testTrimsWhitespace() throws {
        let uri = "  https://api.musicindex.org/v1/liveitems/abc  \n"
        let event = try RelayEvent(uri: uri)
        XCTAssertEqual(event.eventID, "abc")
    }

    func testMissingHostThrowsPath() {
        XCTAssertThrowsError(try RelayEvent(uri: "https:///v1/liveitems/abc")) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .path)
        }
    }

    func testRemoteValueURL() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        let expected = URL(
            string: "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w/remoteValue"
        )!
        XCTAssertEqual(event.remoteValueURL, expected)
    }

    func testValueEventsURL() throws {
        let uri = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
        let event = try RelayEvent(uri: uri)
        let expected = URL(
            string: "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w/events"
        )!
        XCTAssertEqual(event.valueEventsURL, expected)
    }
}
