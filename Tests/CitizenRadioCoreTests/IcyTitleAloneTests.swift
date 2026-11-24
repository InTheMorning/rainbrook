import XCTest
@testable import CitizenRadioCore

/// ADR 0027: when the joined ICY text gives no match, the ID3 title alone can give the match.
final class IcyTitleAloneTests: XCTestCase {
    private let malachi = TrackDisplay(artist: "Malachi", title: "Working Man", artwork: nil)

    // MARK: IcyTitle.icyText

    func testJoinedTextCarriesTheTitleAlone() {
        let icy = IcyTitle.icyText(streamTitle: nil, artist: " Behind The Sch3m3s ", title: " Malachi - Working Man ")
        XCTAssertEqual(icy, IcyText(text: "Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man"))
    }

    func testTitleWithNoArtistHasNoTitleAlone() {
        XCTAssertEqual(IcyTitle.icyText(streamTitle: nil, artist: "  ", title: "Red"), IcyText(text: "Red"))
        XCTAssertEqual(IcyTitle.icyText(streamTitle: nil, artist: nil, title: "Red"), IcyText(text: "Red"))
    }

    func testStreamTitleHasNoTitleAlone() {
        let icy = IcyTitle.icyText(streamTitle: "12 Rods - Red", artist: "12 Rods", title: "Red")
        XCTAssertEqual(icy, IcyText(text: "12 Rods - Red"))
    }

    func testGroupWithNoTitleGivesNoIcyText() {
        XCTAssertNil(IcyTitle.icyText(streamTitle: nil, artist: "12 Rods", title: " "))
    }

    // MARK: IcySync

    func testTitleAloneMatchesWhenTheJoinedTextDoesNot() {
        var sync = IcySync()
        sync.receive(malachi)
        sync.receiveIcyText("Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man")
        XCTAssertEqual(sync.relayTrack, malachi)
    }

    func testJoinedMatchWinsWhenBothMatch() {
        var sync = IcySync()
        let joined = TrackDisplay(
            artist: "Behind The Sch3m3s", title: "Working Man", artwork: nil,
            songLine: "Behind The Sch3m3s - Malachi - Working Man"
        )
        sync.receive(joined)
        sync.receive(malachi)
        sync.receiveIcyText("Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man")
        XCTAssertEqual(sync.relayTrack, joined)
    }

    func testNoMatchWhenNeitherMatches() {
        var sync = IcySync()
        sync.receive(TrackDisplay(artist: "12 Rods", title: "Red", artwork: nil))
        sync.receiveIcyText("Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man")
        XCTAssertNil(sync.relayTrack)
        XCTAssertTrue(sync.hasIcy)
    }

    func testANewIcyTextWithNoTitleAloneDropsTheOldTitleAlone() {
        var sync = IcySync()
        sync.receive(malachi)
        sync.receiveIcyText("Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man")
        sync.receiveIcyText("Other Show - Other Song")
        XCTAssertNil(sync.relayTrack)
    }

    func testResetIcyDropsTheTitleAlone() {
        var sync = IcySync()
        sync.receive(malachi)
        sync.receiveIcyText("Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man")
        sync.resetIcy()
        XCTAssertNil(sync.relayTrack)
        sync.receiveIcyText("Behind The Sch3m3s - Malachi - Working Man")
        XCTAssertNil(sync.relayTrack)
    }
}
