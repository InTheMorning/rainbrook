import Foundation
import XCTest
@testable import RainbrookCore

final class LiveValueTests: XCTestCase {
    // 66 hex characters each, for the node address rules.
    private static let nodeAddressA = "02" + String(repeating: "a", count: 64)
    private static let nodeAddressB = "03" + String(repeating: "b", count: 64)

    func testDecodesPublisherShapeWithNodeDestinationsSplitsFeeAndCustomKeyValue() throws {
        let json = """
        {
            "title": "Pharaoh's Dance",
            "eventGuid": "event-guid-1",
            "blockGuid": "block-guid-1",
            "feedGuid": "feed-guid-1",
            "itemGuid": "item-guid-1",
            "duration": 180,
            "value": {
                "model": { "type": "lightning", "method": "keysend" },
                "destinations": [
                    {
                        "name": "Artist",
                        "type": "node",
                        "address": "\(Self.nodeAddressA)",
                        "split": 95
                    },
                    {
                        "name": "Producer",
                        "type": "node",
                        "address": "\(Self.nodeAddressB)",
                        "split": "5",
                        "fee": true,
                        "customKey": "696969",
                        "customValue": "boost-note"
                    }
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let payload = try LiveValuePayload.decode(data)

        XCTAssertEqual(payload?.title, "Pharaoh's Dance")
        XCTAssertEqual(payload?.eventGuid, "event-guid-1")
        XCTAssertEqual(payload?.blockGuid, "block-guid-1")
        XCTAssertEqual(payload?.feedGuid, "feed-guid-1")
        XCTAssertEqual(payload?.itemGuid, "item-guid-1")
        XCTAssertEqual(payload?.destinations.count, 2)

        XCTAssertEqual(payload?.destinations[0].kind, .node(pubkey: Self.nodeAddressA))
        XCTAssertEqual(payload?.destinations[0].name, "Artist")
        XCTAssertEqual(payload?.destinations[0].split, 95)
        XCTAssertEqual(payload?.destinations[0].fee, false)
        XCTAssertNil(payload?.destinations[0].customKey)
        XCTAssertNil(payload?.destinations[0].customValue)

        XCTAssertEqual(payload?.destinations[1].kind, .node(pubkey: Self.nodeAddressB))
        XCTAssertEqual(payload?.destinations[1].name, "Producer")
        XCTAssertEqual(payload?.destinations[1].split, 5)
        XCTAssertEqual(payload?.destinations[1].fee, true)
        XCTAssertEqual(payload?.destinations[1].customKey, "696969")
        XCTAssertEqual(payload?.destinations[1].customValue, "boost-note")

        XCTAssertEqual(payload?.isPayable, true)
    }

    func testPlaceholderPayloadIsNotPayable() throws {
        let json = """
        {
            "title": "No V4V track playing",
            "eventGuid": "event-guid-2",
            "blockGuid": "block-guid-2",
            "value": {
                "destinations": [
                    { "type": "lnaddress", "address": "no-v4v-track@example.invalid", "split": 100 }
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let payload = try LiveValuePayload.decode(data)

        XCTAssertEqual(payload?.title, LiveValuePayload.placeholderTitle)
        XCTAssertEqual(payload?.destinations.count, 0)
        XCTAssertEqual(payload?.isPayable, false)
    }

    // ADR 0026: the reserved host excludes a dead block with a title that the station sets (publisher ADR 0029).
    func testDeadBlockWithAStationTitleIsNotPayable() throws {
        let json = """
        {
            "title": "HeyCitizen Test Stream",
            "eventGuid": "event-guid-2",
            "blockGuid": "block-guid-2",
            "value": {
                "model": { "type": "lightning", "method": "lnaddress" },
                "destinations": [
                    { "name": "No V4V payment route", "type": "lnaddress",
                      "address": "no-v4v-track@example.invalid", "split": "100" }
                ]
            }
        }
        """
        let payload = try LiveValuePayload.decode(Data(json.utf8))

        XCTAssertNotEqual(payload?.title, LiveValuePayload.placeholderTitle)
        XCTAssertEqual(payload?.destinations.count, 0)
        XCTAssertEqual(payload?.isPayable, false)
    }

    func testPayableLightningAddressAndReservedHostsAreDropped() throws {
        let json = """
        {
            "title": "A Track",
            "eventGuid": "event-guid-3",
            "blockGuid": "block-guid-3",
            "value": {
                "destinations": [
                    { "type": "lnaddress", "address": "Creator@Merchant.io", "split": 100 },
                    { "type": "lnaddress", "address": "a@b.invalid", "split": 1 },
                    { "type": "lnaddress", "address": "a@b.example", "split": 1 },
                    { "type": "lnaddress", "address": "a@b.test", "split": 1 },
                    { "type": "lnaddress", "address": "a@b.localhost", "split": 1 },
                    { "type": "lnaddress", "address": "a@example.com", "split": 1 },
                    { "type": "lnaddress", "address": "a@example.net", "split": 1 },
                    { "type": "lnaddress", "address": "a@example.org", "split": 1 }
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let payload = try LiveValuePayload.decode(data)

        XCTAssertEqual(payload?.destinations.count, 1)
        XCTAssertEqual(payload?.destinations.first?.kind, .lightningAddress(name: "creator", host: "merchant.io"))
        XCTAssertEqual(payload?.isPayable, true)
    }

    func testInvalidNodeAddressAndInvalidSplitAreDropped() throws {
        let short = "02" + String(repeating: "a", count: 62) // 64 characters total
        let long = "02" + String(repeating: "a", count: 65) // 67 characters total
        let nonHex = "02" + String(repeating: "g", count: 64) // 66 characters, one is not hex
        let valid = Self.nodeAddressA

        let json = """
        {
            "title": "A Track",
            "eventGuid": "event-guid-4",
            "blockGuid": "block-guid-4",
            "value": {
                "destinations": [
                    { "type": "node", "address": "\(short)", "split": 10 },
                    { "type": "node", "address": "\(long)", "split": 10 },
                    { "type": "node", "address": "\(nonHex)", "split": 10 },
                    { "type": "node", "address": "\(valid)", "split": "0" },
                    { "type": "node", "address": "\(valid)", "split": "-5" },
                    { "type": "node", "address": "\(valid)", "split": "abc" },
                    { "type": "node", "address": "\(valid)" },
                    { "type": "node", "address": "\(valid)", "split": 10 }
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let payload = try LiveValuePayload.decode(data)

        XCTAssertEqual(payload?.destinations.count, 1)
        XCTAssertEqual(payload?.destinations.first?.kind, .node(pubkey: valid))
        XCTAssertEqual(payload?.destinations.first?.split, 10)
    }

    func testNumericSplitOfOneIsKeptAndBooleanSplitAndNumericFeeAreNotBooleans() throws {
        let valid = Self.nodeAddressA
        let json = """
        {
            "title": "A Track",
            "eventGuid": "event-guid-5",
            "blockGuid": "block-guid-5",
            "value": {
                "destinations": [
                    { "type": "node", "address": "\(valid)", "split": 1, "fee": 1 },
                    { "type": "node", "address": "\(valid)", "split": true },
                    { "type": "node", "address": "\(valid)", "split": 2, "fee": true }
                ]
            }
        }
        """
        let payload = try LiveValuePayload.decode(Data(json.utf8))

        XCTAssertEqual(payload?.destinations.count, 2, "The split true is dropped. The split 1 is kept.")
        XCTAssertEqual(payload?.destinations.first?.split, 1)
        XCTAssertEqual(payload?.destinations.first?.fee, false, "A fee of the number 1 is not the boolean true.")
        XCTAssertEqual(payload?.destinations.last?.fee, true)
    }

    func testPodcastNameIsReadAndAnEmptyOrMissingPodcastNameGivesNil() throws {
        let named = try LiveValuePayload.decode(Data("""
        { "title": "T", "eventGuid": "e", "blockGuid": "b", "podcastName": "Jazz Hour" }
        """.utf8))
        let empty = try LiveValuePayload.decode(Data("""
        { "title": "T", "eventGuid": "e", "blockGuid": "b", "podcastName": "" }
        """.utf8))
        let number = try LiveValuePayload.decode(Data("""
        { "title": "T", "eventGuid": "e", "blockGuid": "b", "podcastName": 7 }
        """.utf8))
        let missing = try LiveValuePayload.decode(Data("""
        { "title": "T", "eventGuid": "e", "blockGuid": "b" }
        """.utf8))

        XCTAssertEqual(named?.podcastName, "Jazz Hour")
        XCTAssertNil(empty?.podcastName)
        XCTAssertNil(number?.podcastName)
        XCTAssertNil(missing?.podcastName)
    }

    func testEmptyObjectGivesNil() throws {
        let data = Data("{}".utf8)
        let payload = try LiveValuePayload.decode(data)
        XCTAssertNil(payload)
    }

    func testMissingBlockGuidThrows() {
        let json = """
        {
            "title": "A Track",
            "eventGuid": "event-guid-5"
        }
        """
        let data = Data(json.utf8)
        XCTAssertThrowsError(try LiveValuePayload.decode(data)) { error in
            XCTAssertEqual(error as? LiveValuePayload.DecodeError, .invalid)
        }
    }

    func testNonObjectJSONThrows() {
        let data = Data("[]".utf8)
        XCTAssertThrowsError(try LiveValuePayload.decode(data)) { error in
            XCTAssertEqual(error as? LiveValuePayload.DecodeError, .invalid)
        }
    }

    // MARK: - GET /metadata snapshot (ADR 0018)

    func testMetadataSnapshotWithPayloadGivesThePayload() throws {
        let json = """
        {
            "event_id": "DFnUwDM1mzcljaF4pI9Q6w",
            "seq": 45,
            "updated_at": "2026-10-06T12:00:00Z",
            "renewed_at": "2026-10-06T12:00:00Z",
            "lease_expires_at": "2026-10-06T12:10:00Z",
            "metadata": {
                "title": "Snapshot Track",
                "eventGuid": "event-guid-7",
                "blockGuid": "block-guid-7",
                "value": {
                    "destinations": [
                        { "type": "lnaddress", "address": "artist@merchant.io", "split": 100 }
                    ]
                }
            }
        }
        """
        let payload = try LiveValuePayload.decodeMetadataSnapshot(Data(json.utf8))

        XCTAssertEqual(payload?.title, "Snapshot Track")
        XCTAssertEqual(payload?.eventGuid, "event-guid-7")
        XCTAssertEqual(payload?.blockGuid, "block-guid-7")
        XCTAssertEqual(payload?.destinations.first?.kind, .lightningAddress(name: "artist", host: "merchant.io"))
    }

    func testMetadataSnapshotWithEmptyMetadataGivesNil() throws {
        let json = #"{"event_id":"DFnUwDM1mzcljaF4pI9Q6w","seq":3,"metadata":{}}"#
        let payload = try LiveValuePayload.decodeMetadataSnapshot(Data(json.utf8))
        XCTAssertNil(payload)
    }

    func testMetadataSnapshotWithNoMetadataObjectThrows() {
        let bodies = [
            #"{"event_id":"DFnUwDM1mzcljaF4pI9Q6w","seq":3}"#,
            #"{"event_id":"DFnUwDM1mzcljaF4pI9Q6w","metadata":"text"}"#,
            "[]",
        ]
        for body in bodies {
            XCTAssertThrowsError(try LiveValuePayload.decodeMetadataSnapshot(Data(body.utf8)), body) { error in
                XCTAssertEqual(error as? LiveValuePayload.DecodeError, .invalid)
            }
        }
    }
}
