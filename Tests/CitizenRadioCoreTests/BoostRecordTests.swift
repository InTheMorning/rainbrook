import Foundation
import XCTest
@testable import CitizenRadioCore

final class BoostRecordTests: XCTestCase {
    private let fullPayloadJSON = """
    {
        "title": "Pharaoh's Dance",
        "eventGuid": "event-1",
        "blockGuid": "block-1",
        "feedGuid": "feed-1",
        "itemGuid": "item-1",
        "value": { "destinations": [] }
    }
    """

    private let shortPayloadJSON = """
    { "title": "T", "eventGuid": "e", "blockGuid": "b", "value": { "destinations": [] } }
    """

    private func payload(_ json: String) -> LiveValuePayload {
        try! LiveValuePayload.decode(Data(json.utf8))!
    }

    private func part(
        name: String?, sats: Int, customKey: String? = nil, customValue: String? = nil
    ) -> BoostPart {
        let destination = LiveValueDestination(
            kind: .lightningAddress(name: "artist", host: "merchant.io"), name: name,
            split: 100, fee: false, customKey: customKey, customValue: customValue
        )
        return BoostPart(destination: destination, sats: sats)
    }

    func testConstants() {
        XCTAssertEqual(BoostRecord.recordType, 7_629_169)
        XCTAssertEqual(BoostRecord.appName, "CitizenRadio")
    }

    func testJSONWithAllOptionalKeys() {
        let data = BoostRecord.json(
            part: part(name: "Miles", sats: 85), payload: payload(fullPayloadJSON), totalSats: 100
        )

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"action":"boost","app_name":"CitizenRadio","block_guid":"block-1","episode":"Pharaoh's Dance","#
                + #""episode_guid":"item-1","event_guid":"event-1","guid":"feed-1","name":"Miles","#
                + #""value_msat":85000,"value_msat_total":100000}"#
        )
    }

    func testJSONWithoutOptionalKeys() {
        let data = BoostRecord.json(part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100)

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"action":"boost","app_name":"CitizenRadio","block_guid":"b","episode":"T","event_guid":"e","#
                + #""value_msat":5000,"value_msat_total":100000}"#
        )
    }

    func testBoostRecordHexOfShortJSON() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100
        )

        XCTAssertEqual(records, [
            TLVRecord(
                type: 7_629_169,
                value: "7b22616374696f6e223a22626f6f7374222c226170705f6e616d65223a22436974697a656e526164696f222c"
                    + "22626c6f636b5f67756964223a2262222c22657069736f6465223a2254222c226576656e745f67756964223a"
                    + "2265222c2276616c75655f6d736174223a353030302c2276616c75655f6d7361745f746f74616c223a3130"
                    + "303030307d"
            )
        ])
    }

    func testCustomRecordFollowsTheBoostRecord() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5, customKey: "696969", customValue: "abc"),
            payload: payload(shortPayloadJSON), totalSats: 100
        )

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.type, 7_629_169)
        XCTAssertEqual(records.last, TLVRecord(type: 696_969, value: "616263"))
    }

    func testNonNumericCustomKeyGivesNoCustomRecord() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5, customKey: "x", customValue: "abc"),
            payload: payload(shortPayloadJSON), totalSats: 100
        )

        XCTAssertEqual(records.map(\.type), [7_629_169])
    }

    func testCustomKeyWithoutValueGivesNoCustomRecord() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5, customKey: "696969", customValue: nil),
            payload: payload(shortPayloadJSON), totalSats: 100
        )

        XCTAssertEqual(records.map(\.type), [7_629_169])
    }
}
