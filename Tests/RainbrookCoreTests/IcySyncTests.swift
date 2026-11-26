import Foundation
import XCTest
@testable import RainbrookCore

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

    func testListKeepsEightStatesAndEvictsTheOldest() {
        var sync = IcySync()
        XCTAssertEqual(IcySync.capacity, 8)
        let tracks = (1...9).map { TrackDisplay(artist: "Artist\($0)", title: "Title\($0)", artwork: nil) }
        for track in tracks {
            sync.receive(track)
        }

        sync.receiveIcyText("Artist1 - Title1")
        XCTAssertNil(sync.relayTrack)

        sync.receiveIcyText("Artist2 - Title2")
        XCTAssertEqual(sync.relayTrack, tracks[1])

        sync.receiveIcyText("Artist9 - Title9")
        XCTAssertEqual(sync.relayTrack, tracks[8])
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

    // MARK: - resetIcy (ADR 0017 §The fallback)

    func testResetIcyClearsHasIcyAndTheRelayTrack() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)
        sync.receiveIcyText("Miles Davis - So What")
        XCTAssertEqual(sync.relayTrack, track)

        sync.resetIcy()

        XCTAssertFalse(sync.hasIcy)
        XCTAssertNil(sync.relayTrack)
        XCTAssertNil(sync.icyTrack)
    }

    func testResetIcyThenAMatchingIcyTextSelectsTheKeptState() {
        var sync = IcySync()
        let track = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(track)
        sync.receiveIcyText("Miles Davis - So What")

        sync.resetIcy()
        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertTrue(sync.hasIcy)
        XCTAssertEqual(sync.relayTrack, track)
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

    // MARK: - The song line (ADR 0024)

    /// Three chapter states of one episode file. Each has its own artist and title, and the same song line.
    private func chapterState(_ index: Int) -> TrackDisplay {
        TrackDisplay(
            artist: "Chapter Artist \(index)", title: "Chapter Song \(index)", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event", blockGuid: "block-\(index)"),
            songLine: "Show Host - Episode 12"
        )
    }

    func testThreeChapterStatesWithOneSongLineSelectTheNewest() {
        var sync = IcySync()
        sync.receiveIcyText("Show Host - Episode 12")

        sync.receive(chapterState(1))
        XCTAssertEqual(sync.relayTrack, chapterState(1))
        sync.receive(chapterState(2))
        XCTAssertEqual(sync.relayTrack, chapterState(2))
        sync.receive(chapterState(3))

        XCTAssertEqual(sync.relayTrack, chapterState(3))
        XCTAssertEqual(sync.lines.title, "Chapter Song 3")
        XCTAssertEqual(sync.lines.artist, "Chapter Artist 3")
    }

    func testChapterStatesBeforeTheIcyTextWaitAndTheNewestShows() {
        var sync = IcySync()
        sync.receive(chapterState(1))
        sync.receive(chapterState(2))
        sync.receive(chapterState(3))
        XCTAssertNil(sync.relayTrack)

        sync.receiveIcyText("show host - episode 12")

        XCTAssertEqual(sync.relayTrack, chapterState(3))
    }

    func testStateWithSongLineDoesNotMatchByArtistAndTitle() {
        var sync = IcySync()
        sync.receive(chapterState(1))

        sync.receiveIcyText("Chapter Artist 1 - Chapter Song 1")

        XCTAssertNil(sync.relayTrack)
    }

    func testStateWithoutSongLineStillMatchesByArtistAndTitle() {
        var sync = IcySync()
        let plain = TrackDisplay(artist: "Miles Davis", title: "So What", artwork: nil)
        sync.receive(plain)
        sync.receive(chapterState(1))

        sync.receiveIcyText("Miles Davis - So What")

        XCTAssertEqual(sync.relayTrack, plain)
    }

    func testKeyOfTrackWithSongLineIsTheNormalizedSongLine() {
        XCTAssertEqual(IcySync.key(of: chapterState(1)), "show host - episode 12")
    }
}
