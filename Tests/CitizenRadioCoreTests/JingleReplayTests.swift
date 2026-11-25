import Foundation
import XCTest
@testable import CitizenRadioCore

/// ADR 0028 rules 6 and 7 with the real input of the HeyCitizen test station.
/// The JSON is the relay display stream, the relay value stream and the Icecast ICY text of 2026-11-25
/// from 16:29:19 to 16:34:21 UTC. The jingle with no title starts at 16:33:56.
final class JingleReplayTests: XCTestCase {
    private let event = "Nx7Pcae5FVqzwZtMDZiXFw"
    private let stationImage = "https://music.cancelbandcamp.com/TestAlbum/test/Gigachad-Transparent-small.png"
    private let mattArtwork =
        "https://phafe.com/wp-content/uploads/rssfeed/music/matt_finlay/kulture_collection/06_Copenhagen_Time.png"
    private let denimArtwork =
        "https://music.behindthesch3m3s.com/wp-content/uploads/Denim%20Cobra/Leather_Diamond/Cobra_Diamond_Leather%20Diamond.jpg"

    /// The two forms of the dead block payload. The relay sent `emptyDestinations` from 2026-11-24 to 2026-11-25
    /// 18:05 UTC. Since then it sends `reservedHost` (publisher ADR 0033).
    private enum DeadBlockForm: CaseIterable {
        case emptyDestinations
        case reservedHost
    }

    private func deadBlock(_ block: String, _ form: DeadBlockForm) -> String {
        switch form {
        case .emptyDestinations:
            return """
            {"blockGuid":"\(block)","description":"","eventGuid":"\(event)","image":"\(stationImage)",\
            "startTime":0,"title":"HeyCitizen Test Stream","type":"music",\
            "value":{"destinations":[],"model":{"method":"lnaddress","type":"lightning"}}}
            """
        case .reservedHost:
            // The form of the relay value stream at 18:36:42 UTC on 2026-11-25.
            return """
            {"blockGuid":"\(block)","description":"","eventGuid":"\(event)","image":"\(stationImage)",\
            "startTime":0,"title":"HeyCitizen Test Stream","type":"music",\
            "value":{"destinations":[{"address":"no-v4v-track@example.invalid","name":"No V4V payment route",\
            "split":"100","type":"lnaddress"}],"model":{"method":"lnaddress","type":"lightning"}}}
            """
        }
    }

    private var mattPayload: String {
        """
        {"author":"Matt Finlay","blockGuid":"c0ba21f0-2e8a-4f60-b568-7a15b46ecf9d","description":"",\
        "eventGuid":"\(event)","feedGuid":"e88a4a67-877c-5e03-b8fd-a70cebc821af","image":"\(mattArtwork)",\
        "itemGuid":"9f515f93-eda1-4146-8637-7def160879b5","line":["Kulture Collection","Matt Finlay"],\
        "podcastName":"Kulture Collection","startTime":0,"title":"Matt Finlay - Copenhagen Time","type":"music",\
        "value":{"destinations":[\
        {"address":"mattfinlay@phafe.com","fee":false,"name":"Matt Finlay","split":"94","type":"lnaddress"},\
        {"address":"chadf@getalby.com","fee":false,"name":"MSP 2.0","split":"5","type":"lnaddress"},\
        {"address":"podcastindex@getalby.com","fee":false,"name":"Podcastindex.org","split":"1","type":"lnaddress"}],\
        "model":{"method":"keysend","type":"lightning"}}}
        """
    }

    private var denimPayload: String {
        """
        {"author":"Denim Cobra","blockGuid":"931e065a-718d-4e67-82d8-52e4ffda5fa5","description":"",\
        "eventGuid":"\(event)","feedGuid":"0d5a8efb-e132-5f1b-9ab4-3fd0644dbb30","image":"\(denimArtwork)",\
        "itemGuid":"eccb8000-2b1f-4f1c-9cd8-0327da121e48","line":["Leather Diamond","Denim Cobra"],\
        "podcastName":"Leather Diamond","startTime":0,"title":"Denim Cobra - Hermetic Drifter","type":"music",\
        "value":{"destinations":[\
        {"address":"03b6f613e88bd874177c28c6ad83b3baba43c4c656f56be1f8df84669556054b79","customKey":"906608",\
        "customValue":"01y6f5CJxIL0XblNWAKdFZ","fee":false,"name":"denimcobra@fountain.fm","split":"97","type":"node"},\
        {"address":"035ad2c954e264004986da2d9499e1732e5175e1dcef2453c921c6cdcc3536e9d8","fee":false,\
        "name":"StevenB","split":"3","type":"node"}],\
        "model":{"method":"keysend","type":"lightning"}}}
        """
    }

    private func mattDisplay(block: String?) -> String {
        let value = block.map { ",\"value\":{\"blockGuid\":\"\($0)\",\"eventGuid\":\"\(event)\"}" } ?? ""
        return """
        {"track":{"album":"Kulture Collection","artist":"Matt Finlay","artwork":{"url":"\(mattArtwork)"},\
        "songLine":"Matt Finlay - Copenhagen Time","title":"Copenhagen Time"\(value)}}
        """
    }

    private func denimDisplay(block: String?) -> String {
        let value = block.map { ",\"value\":{\"blockGuid\":\"\($0)\",\"eventGuid\":\"\(event)\"}" } ?? ""
        return """
        {"track":{"album":"Leather Diamond","artist":"Denim Cobra","artwork":{"url":"\(denimArtwork)"},\
        "songLine":"Denim Cobra - Hermetic Drifter","title":"Hermetic Drifter"\(value)}}
        """
    }

    /// The state of `TrackInfoModel` that the rules use, with the order of its handlers.
    private struct Model {
        var sync = IcySync()
        var pairing = BoostPairing()
        var station: StationIdentity?
        /// ADR 0028 rule 13: true for a stream state of the event stream after the first ICY text, as in the app.
        var holdValueEnds = false
        var held: [IcySync.HeldValueEnd] = []

        mutating func icy(_ text: String) {
            sync.receiveIcyText(text)
        }

        mutating func display(_ json: String) throws {
            if let hold = sync.receive(try TrackDisplay.decode(Data(json.utf8)), holdValueEnd: holdValueEnds) {
                held.append(hold)
            }
        }

        /// The display delay ends: the audio of the held states plays. Gives the count of value ends that applied.
        @discardableResult
        mutating func play() -> Int {
            defer { held.removeAll() }
            return held.filter { sync.releaseValueEnd($0) }.count
        }

        mutating func value(_ json: String) throws {
            let payload = try XCTUnwrap(LiveValuePayload.decode(Data(json.utf8)))
            if let identity = StationIdentity(payload) {
                station = identity
            }
            pairing.receive(payload)
        }

        var valueEnded: Bool { sync.valueEnded(sync.relayTrack) }
        var lines: TrackLines { sync.lines.withStation(station, valueEnded: valueEnded) }
        var manualBlock: String? {
            sync.relayTrack.flatMap { pairing.manualPayload(for: $0, valueEnded: valueEnded)?.blockGuid }
        }
    }

    /// `displayFirst` is the order of 16:49:15, where the display state came before the dead block payload.
    private func replay(displayFirst: Bool, form: DeadBlockForm) throws {
        var model = Model()

        // 16:29:19 to 16:29:21: the song starts.
        model.icy("Matt Finlay - Copenhagen Time")
        try model.value(deadBlock("95d94d7c-184a-4b0b-9598-36de14f4fcab", form))
        try model.display(mattDisplay(block: nil))
        XCTAssertFalse(model.valueEnded, "A song that starts with no value block keeps its lines (rule 8).")
        XCTAssertEqual(model.lines.title, "Copenhagen Time")
        try model.value(mattPayload)
        try model.display(mattDisplay(block: "c0ba21f0-2e8a-4f60-b568-7a15b46ecf9d"))
        XCTAssertEqual(model.lines.title, "Copenhagen Time")
        XCTAssertEqual(model.manualBlock, "c0ba21f0-2e8a-4f60-b568-7a15b46ecf9d")

        // 16:33:56: the jingle with no title. The ICY text of the song comes again.
        model.icy("Matt Finlay - Copenhagen Time")
        if displayFirst {
            try model.display(mattDisplay(block: nil))
            try model.value(deadBlock("c796dff4-eb8b-465a-8b39-f737a7b27ed2", form))
        } else {
            try model.value(deadBlock("c796dff4-eb8b-465a-8b39-f737a7b27ed2", form))
            try model.display(mattDisplay(block: nil))
        }
        XCTAssertTrue(model.valueEnded)
        XCTAssertEqual(model.station, StationIdentity(title: "HeyCitizen Test Stream", image: URL(string: stationImage)))
        XCTAssertEqual(model.lines, TrackLines(title: "HeyCitizen Test Stream", artist: nil, artwork: nil))
        XCTAssertNil(model.manualBlock)

        // 16:34:20: the next song.
        model.icy("Denim Cobra - Hermetic Drifter")
        try model.value(deadBlock("acec83fb-522a-4ccf-bb48-485237b70ffa", form))
        try model.display(denimDisplay(block: nil))
        XCTAssertFalse(model.valueEnded)
        XCTAssertEqual(model.lines.title, "Hermetic Drifter")
        XCTAssertNil(model.manualBlock)
        try model.value(denimPayload)
        try model.display(denimDisplay(block: "931e065a-718d-4e67-82d8-52e4ffda5fa5"))
        XCTAssertEqual(model.lines.title, "Hermetic Drifter")
        XCTAssertEqual(model.manualBlock, "931e065a-718d-4e67-82d8-52e4ffda5fa5")
    }

    func testTheJingleOf20261125ShowsTheStationLinesAndNoManualTarget() throws {
        try replay(displayFirst: false, form: .emptyDestinations)
    }

    func testTheDisplayStateBeforeTheDeadBlockGivesTheSameResult() throws {
        try replay(displayFirst: true, form: .emptyDestinations)
    }

    /// Publisher ADR 0033: the dead block has one destination with a reserved host.
    func testTheDeadBlockWithAReservedHostGivesTheSameResult() throws {
        try replay(displayFirst: false, form: .reservedHost)
        try replay(displayFirst: true, form: .reservedHost)
    }

    /// ADR 0028 rule 13, operator report of 2026-11-25 on HLS: the station lines showed 10 s or more before the
    /// jingle played. The relay states arrive at live time, and the stream title of the song stays during the jingle.
    /// So the song lines stay until the display delay ends.
    func testOnHlsTheStationLinesWaitForThePlayTime() throws {
        var model = try songWithValue()

        // Live time of the jingle. The audio of the song still plays, with the same stream title.
        try model.value(deadBlock("c796dff4-eb8b-465a-8b39-f737a7b27ed2", .reservedHost))
        try model.display(mattDisplay(block: nil))
        model.icy("Matt Finlay - Copenhagen Time")
        XCTAssertFalse(model.valueEnded)
        XCTAssertEqual(model.lines.title, "Copenhagen Time")
        XCTAssertEqual(model.lines.artwork, .url(try XCTUnwrap(URL(string: mattArtwork))))

        // The display delay ends: the jingle plays.
        XCTAssertEqual(model.play(), 1)
        XCTAssertTrue(model.valueEnded)
        XCTAssertEqual(model.lines, TrackLines(title: "HeyCitizen Test Stream", artist: nil, artwork: nil))
        XCTAssertNil(model.manualBlock)

        // The next song: its stream title clears the value end.
        model.icy("Denim Cobra - Hermetic Drifter")
        try model.display(denimDisplay(block: "931e065a-718d-4e67-82d8-52e4ffda5fa5"))
        XCTAssertFalse(model.valueEnded)
        XCTAssertEqual(model.lines.title, "Hermetic Drifter")
    }

    /// ADR 0028 rule 13: a different stream title before the end of the delay cancels the held value end.
    func testANewStreamTitleCancelsTheHeldValueEnd() throws {
        var model = try songWithValue()
        try model.display(mattDisplay(block: nil))
        try model.display(denimDisplay(block: "931e065a-718d-4e67-82d8-52e4ffda5fa5"))
        model.icy("Denim Cobra - Hermetic Drifter")
        XCTAssertEqual(model.play(), 0)
        model.icy("Matt Finlay - Copenhagen Time")
        XCTAssertFalse(model.valueEnded)
    }

    /// ADR 0028 rule 13: a newer state of the key with a value block cancels the held value end.
    func testANewValueBlockCancelsTheHeldValueEnd() throws {
        var model = try songWithValue()
        try model.display(mattDisplay(block: nil))
        try model.display(mattDisplay(block: "c0ba21f0-2e8a-4f60-b568-7a15b46ecf9d"))
        XCTAssertEqual(model.play(), 0)
        XCTAssertFalse(model.valueEnded)
    }

    /// The song of 16:29 with its value block, after the first ICY text. Later states are held.
    private func songWithValue() throws -> Model {
        var model = Model()
        model.icy("Matt Finlay - Copenhagen Time")
        try model.value(mattPayload)
        try model.display(mattDisplay(block: "c0ba21f0-2e8a-4f60-b568-7a15b46ecf9d"))
        model.holdValueEnds = true
        return model
    }
}
