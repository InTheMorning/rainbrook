import Foundation
import XCTest
@testable import RainbrookCore

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

    /// A sender with no message and no sender name.
    private let plainSender = BoostSender(message: nil, senderName: nil, appName: "Rainbrook")

    /// A fixed boost UUID. The record has it in lowercase.
    private let fixedUUID = UUID(uuidString: "6F1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D")!

    /// A manual boost with the fixed UUID and no station name.
    private var context: BoostContext {
        BoostContext(action: .boost, uuid: fixedUUID, stationName: nil)
    }

    func testConstants() {
        XCTAssertEqual(BoostRecord.recordType, 7_629_169)
    }

    // MARK: - BoostSender

    func testSenderKeepsItsTexts() {
        let sender = BoostSender(message: "Great set", senderName: "Maik", appName: "MyApp")

        XCTAssertEqual(sender.message, "Great set")
        XCTAssertEqual(sender.senderName, "Maik")
        XCTAssertEqual(sender.appName, "MyApp")
    }

    func testSenderEmptyTextsGiveNilAndTheDefaultAppName() {
        let sender = BoostSender(message: "", senderName: "", appName: "")

        XCTAssertNil(sender.message)
        XCTAssertNil(sender.senderName)
        XCTAssertEqual(sender.appName, "Rainbrook")
    }

    func testSenderWhiteSpaceTextsGiveNilAndTheDefaultAppName() {
        let sender = BoostSender(message: "  ", senderName: "\n", appName: " ")

        XCTAssertNil(sender.message)
        XCTAssertNil(sender.senderName)
        XCTAssertEqual(sender.appName, "Rainbrook")
    }

    func testSenderReadsTheSettings() throws {
        let suite = "BoostRecordTests.sender"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = BoostSettings(defaults: defaults)

        XCTAssertEqual(
            BoostSender(settings: settings),
            BoostSender(message: nil, senderName: nil, appName: "Rainbrook")
        )

        settings.message = "Great set"
        settings.senderName = "Maik"
        settings.appName = "MyApp"

        let sender = BoostSender(settings: settings)
        XCTAssertEqual(sender.message, "Great set")
        XCTAssertEqual(sender.senderName, "Maik")
        XCTAssertEqual(sender.appName, "MyApp")
    }

    // MARK: - JSON

    func testJSONWithAllOptionalKeys() {
        let data = BoostRecord.json(
            part: part(name: "Miles", sats: 85), payload: payload(fullPayloadJSON), totalSats: 100,
            sender: plainSender, context: context
        )

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"action":"boost","app_name":"Rainbrook","block_guid":"block-1","episode":"Pharaoh's Dance","#
                + #""episode_guid":"item-1","event_guid":"event-1","guid":"feed-1","name":"Miles","#
                + #""uuid":"6f1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d","value_msat":85000,"value_msat_total":100000}"#
        )
    }

    func testJSONWithoutOptionalKeys() {
        let data = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100,
            sender: plainSender, context: context
        )

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"action":"boost","app_name":"Rainbrook","block_guid":"b","episode":"T","event_guid":"e","#
                + #""uuid":"6f1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d","value_msat":5000,"value_msat_total":100000}"#
        )
    }

    func testJSONWithMessageAndSenderName() {
        let data = BoostRecord.json(
            part: part(name: "Miles", sats: 85), payload: payload(fullPayloadJSON), totalSats: 100,
            sender: BoostSender(message: "Great set!", senderName: "Maik", appName: "MyApp"), context: context
        )

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"action":"boost","app_name":"MyApp","block_guid":"block-1","episode":"Pharaoh's Dance","#
                + #""episode_guid":"item-1","event_guid":"event-1","guid":"feed-1","message":"Great set!","#
                + #""name":"Miles","sender_name":"Maik","uuid":"6f1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d","#
                + #""value_msat":85000,"value_msat_total":100000}"#
        )
    }

    func testJSONWithoutMessageAndSenderNameUsesTheSenderAppName() {
        let data = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100,
            sender: BoostSender(message: "", senderName: nil, appName: "MyApp"), context: context
        )

        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"action":"boost","app_name":"MyApp","block_guid":"b","episode":"T","event_guid":"e","#
                + #""uuid":"6f1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d","value_msat":5000,"value_msat_total":100000}"#
        )
    }

    func testBoostRecordHexOfShortJSON() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100,
            sender: plainSender, context: context
        )

        XCTAssertEqual(records, [
            TLVRecord(
                type: 7_629_169,
                value: "7b22616374696f6e223a22626f6f7374222c226170705f6e616d65223a225261696e62726f6f6b222c"
                    + "22626c6f636b5f67756964223a2262222c22657069736f6465223a2254222c226576656e745f67756964223a"
                    + "2265222c2275756964223a2236663162326333642d346535662d346136622d386337642d3965306631613262"
                    + "33633464222c2276616c75655f6d736174223a353030302c2276616c75655f6d7361745f746f74616c223a31"
                    + "30303030307d"
            )
        ])
    }

    func testCustomRecordFollowsTheBoostRecord() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5, customKey: "696969", customValue: "abc"),
            payload: payload(shortPayloadJSON), totalSats: 100, sender: plainSender, context: context
        )

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.type, 7_629_169)
        XCTAssertEqual(records.last, TLVRecord(type: 696_969, value: "616263"))
    }

    func testNonNumericCustomKeyGivesNoCustomRecord() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5, customKey: "x", customValue: "abc"),
            payload: payload(shortPayloadJSON), totalSats: 100, sender: plainSender, context: context
        )

        XCTAssertEqual(records.map(\.type), [7_629_169])
    }

    func testCustomKeyWithoutValueGivesNoCustomRecord() {
        let records = BoostRecord.tlvRecords(
            part: part(name: nil, sats: 5, customKey: "696969", customValue: nil),
            payload: payload(shortPayloadJSON), totalSats: 100, sender: plainSender, context: context
        )

        XCTAssertEqual(records.map(\.type), [7_629_169])
    }

    // MARK: - ADR 0023 keys

    /// The JSON object of a record. A test uses it to examine one key.
    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let podcastPayloadJSON = """
    { "title": "T", "eventGuid": "e", "blockGuid": "b", "podcastName": "Jazz Hour",
      "value": { "destinations": [] } }
    """

    func testPodcastIsThePodcastNameOfThePayload() throws {
        let data = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: payload(podcastPayloadJSON), totalSats: 100, sender: plainSender,
            context: BoostContext(action: .boost, uuid: fixedUUID, stationName: "Radio One")
        )

        XCTAssertEqual(try object(data)["podcast"] as? String, "Jazz Hour")
    }

    func testPodcastIsTheStationNameWhenThePayloadHasNoPodcastName() throws {
        let data = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100, sender: plainSender,
            context: BoostContext(action: .boost, uuid: fixedUUID, stationName: "Radio One")
        )

        XCTAssertEqual(try object(data)["podcast"] as? String, "Radio One")
    }

    func testNoPodcastNameAndNoStationNameGiveNoPodcastKey() throws {
        let emptyName = payload("""
        { "title": "T", "eventGuid": "e", "blockGuid": "b", "podcastName": "", "value": { "destinations": [] } }
        """)
        let data = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: emptyName, totalSats: 100, sender: plainSender,
            context: BoostContext(action: .boost, uuid: fixedUUID, stationName: nil)
        )

        XCTAssertNil(try object(data)["podcast"])
    }

    func testOneUUIDGivesTheSameLowercaseUUIDInTwoSplits() throws {
        let first = BoostRecord.json(
            part: part(name: "Miles", sats: 85), payload: payload(fullPayloadJSON), totalSats: 100,
            sender: plainSender, context: context
        )
        let second = BoostRecord.json(
            part: part(name: "Bill", sats: 15), payload: payload(fullPayloadJSON), totalSats: 100,
            sender: plainSender, context: context
        )

        XCTAssertEqual(try object(first)["uuid"] as? String, "6f1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")
        XCTAssertEqual(try object(second)["uuid"] as? String, "6f1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")
    }

    func testActionIsAutoForAnAutoBoostAndBoostForAManualBoost() throws {
        let auto = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100, sender: plainSender,
            context: BoostContext(action: .auto, uuid: fixedUUID, stationName: nil)
        )
        let manual = BoostRecord.json(
            part: part(name: nil, sats: 5), payload: payload(shortPayloadJSON), totalSats: 100, sender: plainSender,
            context: BoostContext(action: .boost, uuid: fixedUUID, stationName: nil)
        )

        XCTAssertEqual(try object(auto)["action"] as? String, "auto")
        XCTAssertEqual(try object(manual)["action"] as? String, "boost")
    }
}
