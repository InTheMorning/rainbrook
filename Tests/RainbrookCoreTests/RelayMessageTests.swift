import Foundation
import XCTest
@testable import RainbrookCore

final class RelayMessageTests: XCTestCase {
    /// A secret key known to be a correct secp256k1 scalar (BIP-340 vector 0).
    private let sampleSecretKey = "0000000000000000000000000000000000000000000000000000000000000003"

    private func sampleEventJSON() throws -> String {
        let event = try NostrEvent.signed(
            kind: 1, tags: [["p", "abc"]], content: "hello", createdAt: 1_700_000_000, secretKey: sampleSecretKey
        )
        let data = try JSONEncoder().encode(event)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - NostrFilter and ClientMessage

    func testRequestEncodesEventReferencesUnderTheHashEKey() {
        let filter = NostrFilter(authors: ["abc"], eventReferences: ["deadbeef"])
        let text = ClientMessage.request(subscriptionID: "sub1", filter: filter)
        XCTAssertTrue(text.contains("\"#e\":[\"deadbeef\"]"))
        XCTAssertTrue(text.hasPrefix("[\"REQ\",\"sub1\","))
        XCTAssertTrue(text.hasSuffix("]"))
    }

    func testRequestOmitsFilterFieldsThatAreNil() {
        let filter = NostrFilter(authors: ["abc"])
        let text = ClientMessage.request(subscriptionID: "sub1", filter: filter)
        XCTAssertFalse(text.contains("kinds"))
        XCTAssertFalse(text.contains("#e"))
        XCTAssertFalse(text.contains("limit"))
        XCTAssertTrue(text.contains("\"authors\":[\"abc\"]"))
    }

    func testCloseEncodesTheSubscriptionID() {
        XCTAssertEqual(ClientMessage.close(subscriptionID: "sub1"), "[\"CLOSE\",\"sub1\"]")
    }

    func testEventWrapsTheEventJSON() throws {
        let event = try NostrEvent.signed(
            kind: 1, tags: [], content: "hello", createdAt: 1_700_000_000, secretKey: sampleSecretKey
        )
        let text = ClientMessage.event(event)
        XCTAssertTrue(text.hasPrefix("[\"EVENT\","))
        XCTAssertTrue(text.contains("\"kind\":1"))
    }

    // MARK: - RelayMessage decoding

    func testDecodesEvent() throws {
        let text = "[\"EVENT\",\"sub1\",\(try sampleEventJSON())]"
        guard case .event(let subscriptionID, let event) = try RelayMessage(text: text) else {
            return XCTFail("Expected an event message.")
        }
        XCTAssertEqual(subscriptionID, "sub1")
        XCTAssertTrue(event.isValid())
    }

    func testDecodesOK() throws {
        let message = try RelayMessage(text: "[\"OK\",\"eventid1\",true,\"accepted\"]")
        XCTAssertEqual(message, .ok(eventID: "eventid1", accepted: true, message: "accepted"))
    }

    func testDecodesEndOfStoredEvents() throws {
        let message = try RelayMessage(text: "[\"EOSE\",\"sub1\"]")
        XCTAssertEqual(message, .endOfStoredEvents(subscriptionID: "sub1"))
    }

    func testDecodesNotice() throws {
        let message = try RelayMessage(text: "[\"NOTICE\",\"rate limited\"]")
        XCTAssertEqual(message, .notice("rate limited"))
    }

    func testDecodesClosed() throws {
        let message = try RelayMessage(text: "[\"CLOSED\",\"sub1\",\"shutting down\"]")
        XCTAssertEqual(message, .closed(subscriptionID: "sub1", message: "shutting down"))
    }

    // MARK: - RelayMessage decoding failures

    func testThrowsForTextThatIsNotJSON() {
        XCTAssertThrowsError(try RelayMessage(text: "not json")) { error in
            XCTAssertEqual(error as? RelayMessage.Error, .malformed)
        }
    }

    func testThrowsForAnEmptyArray() {
        XCTAssertThrowsError(try RelayMessage(text: "[]")) { error in
            XCTAssertEqual(error as? RelayMessage.Error, .malformed)
        }
    }

    func testThrowsForAKnownTypeWithTheWrongShape() {
        XCTAssertThrowsError(try RelayMessage(text: "[\"EVENT\",\"sub1\"]")) { error in
            XCTAssertEqual(error as? RelayMessage.Error, .malformed)
        }
    }

    func testThrowsForAnUnknownType() {
        XCTAssertThrowsError(try RelayMessage(text: "[\"AUTH\",\"challenge\"]")) { error in
            XCTAssertEqual(error as? RelayMessage.Error, .unknownType("AUTH"))
        }
    }
}
