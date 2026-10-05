import Foundation
import XCTest
@testable import CitizenRadioCore

final class IcySyncTests: XCTestCase {
    // MARK: - Before the first ICY text

    func testBeforeFirstIcyTextRelayTrackIsNilEvenWithStates() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Artist", title: "Title", artwork: nil)
        sync.receive(track)

        XCTAssertFalse(sync.hasIcy)
        XCTAssertNil(sync.relayTrack)
        XCTAssertNil(sync.icyTrack)
    }

    // MARK: - A state before its ICY text waits

    func testStateBeforeIcyTextIsNotRelayTrackUntilNamed() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)

        XCTAssertNil(sync.relayTrack)

        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertEqual(sync.relayTrack, track)
    }

    // MARK: - A state after its ICY text shows at once

    func testStateAfterIcyTextIsRelayTrackImmediately() {
        var sync = IcySync()
        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertNil(sync.relayTrack)

        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)

        XCTAssertEqual(sync.relayTrack, track)
    }

    // MARK: - An empty ICY text clears the selection

    func testEmptyIcyTextGivesNilSelectionWithStateInList() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)

        sync.receiveIcyText("")

        XCTAssertTrue(sync.hasIcy)
        XCTAssertNil(sync.relayTrack)
        XCTAssertNil(sync.icyTrack)
    }

    func testWhitespaceOnlyIcyTextGivesNilSelection() {
        var sync = IcySync()
        sync.receiveIcyText("   ")

        XCTAssertTrue(sync.hasIcy)
        XCTAssertNil(sync.relayTrack)
        XCTAssertNil(sync.icyTrack)
    }

    // MARK: - receive(nil) does not clear a named relay track

    func testReceiveNilDoesNotClearRelayTrackWhileIcyTextNamesIt() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)
        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertEqual(sync.relayTrack, track)

        sync.receive(nil)

        XCTAssertEqual(sync.relayTrack, track)
    }

    // MARK: - No matching state

    func testNoMatchingStateGivesNilRelayTrackAndParsedIcyTrack() {
        var sync = IcySync()
        sync.receiveIcyText("Some Unknown - Text")

        XCTAssertNil(sync.relayTrack)
        XCTAssertEqual(sync.icyTrack, IcyTrack(artist: "Some Unknown", title: "Text"))
    }

    // MARK: - Case, white space and NFC differences match

    func testCaseWhitespaceAndNFCDifferencesMatch() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Caf\u{e9}", title: "Trio", artwork: nil)
        sync.receive(track)

        // "CAFE" plus a combining acute accent forms the same letter as "\u{e9}" after NFC.
        sync.receiveIcyText("  CAFE\u{301}   -   TRIO  ")

        XCTAssertEqual(sync.relayTrack, track)
    }

    // MARK: - Prefix match

    func testPrefixMatchWithEnoughCharactersAndTextAfterSeparator() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "Pharaoh's Dance", artwork: nil)
        sync.receive(track)

        sync.receiveIcyText("Miles Davis - Pharaoh")

        XCTAssertEqual(sync.relayTrack, track)
    }

    func testEightCharacterIcyTextMatchesByPrefix() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Mile", title: "Pharaoh's Dance", artwork: nil)
        sync.receive(track)

        // "mile - p" has 8 characters, the minimum for a prefix match.
        sync.receiveIcyText("Mile - P")

        XCTAssertEqual(sync.relayTrack, track)
    }

    func testSevenCharacterIcyTextDoesNotMatchByPrefix() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Abc", title: "Defg", artwork: nil)
        sync.receive(track)

        sync.receiveIcyText("Abc - d")

        XCTAssertNil(sync.relayTrack)
    }

    func testHeyCitizenWithTrailingSeparatorDoesNotMatch() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "HeyCitizen", title: "How Bout You?", artwork: nil)
        sync.receive(track)

        sync.receiveIcyText("HeyCitizen - ")

        XCTAssertNil(sync.relayTrack)
    }

    func testHeyCitizenWithNoSeparatorDoesNotMatch() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "HeyCitizen", title: "How Bout You?", artwork: nil)
        sync.receive(track)

        sync.receiveIcyText("HeyCitizen")

        XCTAssertNil(sync.relayTrack)
    }

    // MARK: - An exact match wins over a prefix match

    func testExactMatchWinsOverPrefixMatch() {
        var sync = IcySync()
        let older = TrackDisplay(artist: "Abc", title: "Def", artwork: nil)
        sync.receive(older)
        let newer = TrackDisplay(artist: "Abc", title: "Defg", artwork: nil)
        sync.receive(newer)

        sync.receiveIcyText("Abc - Def")

        XCTAssertEqual(sync.relayTrack, older)
    }

    // MARK: - The list keeps 4 states

    func testListKeepsFourStatesAndEvictsTheOldest() {
        var sync = IcySync()
        let track1 = TrackDisplay(artist: "Artist1", title: "Title1", artwork: nil)
        let track2 = TrackDisplay(artist: "Artist2", title: "Title2", artwork: nil)
        let track3 = TrackDisplay(artist: "Artist3", title: "Title3", artwork: nil)
        let track4 = TrackDisplay(artist: "Artist4", title: "Title4", artwork: nil)
        let track5 = TrackDisplay(artist: "Artist5", title: "Title5", artwork: nil)

        sync.receive(track1)
        sync.receive(track2)
        sync.receive(track3)
        sync.receive(track4)
        sync.receive(track5)

        sync.receiveIcyText("Artist1 - Title1")
        XCTAssertNil(sync.relayTrack)

        sync.receiveIcyText("Artist5 - Title5")
        XCTAssertEqual(sync.relayTrack, track5)
    }

    // MARK: - A newer state with an equal key replaces the older state

    func testNewerStateWithEqualKeyReplacesOlderState() {
        var sync = IcySync()
        let older = TrackDisplay(
            artist: "Miles Davis",
            title: "So What",
            artwork: .relay(sha256: String(repeating: "a", count: 64), mime: "image/jpeg")
        )
        let newer = TrackDisplay(
            artist: "Miles Davis",
            title: "So What",
            artwork: .relay(sha256: String(repeating: "b", count: 64), mime: "image/jpeg")
        )

        sync.receive(older)
        sync.receive(newer)
        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertEqual(sync.relayTrack, newer)
        XCTAssertEqual(sync.relayTrack?.artwork, newer.artwork)
    }

    // MARK: - clearStates keeps the ICY text

    func testClearStatesGivesNilRelayTrackAndKeepsIcyTrack() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)
        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertEqual(sync.relayTrack, track)

        sync.clearStates()

        XCTAssertNil(sync.relayTrack)
        XCTAssertEqual(sync.icyTrack, IcyTrack(artist: "Miles Davis", title: "So What"))
    }

    // MARK: - lines

    func testLinesMatchesTrackLinesSelectOfTheCurrentSelection() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)
        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertEqual(sync.lines, TrackLines(title: "So What", artist: "Miles Davis", artwork: nil))
    }

    // MARK: - normalize and key(of:), with literal expected strings

    func testNormalizeTrimsCollapsesWhitespaceAppliesNFCAndLowercases() {
        XCTAssertEqual(IcySync.normalize("  Miles   Davis  "), "miles davis")
        // "CAFE" plus a combining acute accent forms the same letter as "\u{e9}" after NFC.
        XCTAssertEqual(IcySync.normalize("CAFE\u{301}"), "caf\u{e9}")
    }

    func testKeyOfTrackJoinsArtistAndTitle() {
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        XCTAssertEqual(IcySync.key(of: track), "miles davis - so what")
    }
}
