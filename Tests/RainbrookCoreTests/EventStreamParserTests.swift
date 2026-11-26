import Foundation
import XCTest
@testable import RainbrookCore

final class EventStreamParserTests: XCTestCase {
    func testParsesCompleteEvent() {
        var parser = EventStreamParser()

        let event1 = parser.feed(line: "event: display")
        XCTAssertNil(event1)

        let event2 = parser.feed(line: "id: 1")
        XCTAssertNil(event2)

        let event3 = parser.feed(line: "data: {\"track\":null}")
        XCTAssertNil(event3)

        let event4 = parser.feed(line: "")
        XCTAssertNotNil(event4)
        XCTAssertEqual(event4?.event, "display")
        XCTAssertEqual(event4?.id, "1")
        XCTAssertEqual(event4?.data, "{\"track\":null}")
    }

    func testJoinsTwoDataLines() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "data: line1")
        _ = parser.feed(line: "data: line2")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.data, "line1\nline2")
    }

    func testIgnoresCommentLine() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "data: content")
        _ = parser.feed(line: ": this is a comment")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.data, "content")
    }

    func testUsesMessageAsDefaultEvent() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "data: content")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.event, "message")
    }

    func testKeepsLastEventIDForNextEvent() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "id: first")
        _ = parser.feed(line: "data: content1")
        _ = parser.feed(line: "")

        _ = parser.feed(line: "data: content2")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.id, "first")
    }

    func testGivesNilForEmptyLine() {
        var parser = EventStreamParser()
        let event = parser.feed(line: "")
        XCTAssertNil(event)
    }

    func testRemovesOneLeadingSpaceFromValue() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "data:  two spaces")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.data, " two spaces")
    }

    func testIgnoresFieldWithNullCharacterInID() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "id: valid\0invalid")
        _ = parser.feed(line: "data: content")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertNil(event?.id)
    }

    func testHandlesFieldWithNoColon() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "event")
        _ = parser.feed(line: "data: content")
        let event = parser.feed(line: "")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.event, "message")
    }

    func testClearsEventNameAndDataButNotLastID() {
        var parser = EventStreamParser()

        _ = parser.feed(line: "event: first")
        _ = parser.feed(line: "id: 1")
        _ = parser.feed(line: "data: d1")
        _ = parser.feed(line: "")

        // After dispatch, event name resets to "message" and data clears
        _ = parser.feed(line: "data: d2")
        let event = parser.feed(line: "")

        XCTAssertEqual(event?.event, "message")
        XCTAssertEqual(event?.data, "d2")
        XCTAssertEqual(event?.id, "1")
    }
}
