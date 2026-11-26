import Foundation
import XCTest
@testable import RainbrookCore

/// ADR 0030: on HLS, a segment frame with a play ID releases the held display state with the same play ID.
final class IcySyncSegmentFrameTests: XCTestCase {
    private let songLine = "Show Host - Episode 12"
    private let episodeText = "Show Host - Episode 12"

    private func chapter(_ title: String, playId: String?, block: String? = nil) -> TrackDisplay {
        TrackDisplay(
            artist: "Artist \(title)",
            title: title,
            artwork: nil,
            value: block.map { TrackDisplay.ValueIdentity(eventGuid: "event", blockGuid: $0) },
            songLine: songLine,
            playId: playId
        )
    }

    private func frame(_ playId: String?) -> SegmentFrame {
        SegmentFrame(playId: playId)
    }

    // MARK: - The list

    func testStatesWithDifferentPlayIdsAndOneSongLineStayInTheList() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(first)
        sync.receive(second)

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))
        XCTAssertEqual(sync.relayTrack, first)

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3-30665"))
        XCTAssertEqual(sync.relayTrack, second)
    }

    func testAStateWithAnEqualPlayIdReplacesTheOlderState() {
        var sync = IcySync()
        let withoutValue = chapter("One", playId: "ls-1-3")
        let withValue = chapter("One", playId: "ls-1-3", block: "block-1")
        sync.receive(withoutValue)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))
        XCTAssertEqual(sync.relayTrack, withoutValue)

        sync.receive(withValue)

        XCTAssertEqual(sync.relayTrack, withValue)
    }

    func testAStateWithAPlayIdDoesNotReplaceAStateWithNoPlayIdAndTheSameKey() {
        XCTAssertNotEqual(
            IcySync.identity(of: chapter("One", playId: nil)),
            IcySync.identity(of: chapter("One", playId: "ls-1-3"))
        )
        XCTAssertEqual(
            IcySync.identity(of: chapter("One", playId: nil)),
            IcySync.identity(of: chapter("Two", playId: nil))
        )
    }

    // MARK: - The release

    func testAnEarlyChapterStateWaitsForItsFrame() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        sync.receive(first)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))
        XCTAssertEqual(sync.relayTrack, first)

        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(second)
        XCTAssertEqual(sync.relayTrack, first)

        // Each segment repeats the frame until the next boundary.
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))
        XCTAssertEqual(sync.relayTrack, first)

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3-30665"))
        XCTAssertEqual(sync.relayTrack, second)
    }

    func testAFrameThatNamesNoHeldStateKeepsTheReleasedState() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        sync.receive(first)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3-30665"))

        XCTAssertEqual(sync.relayTrack, first)
    }

    func testAStateThatArrivesAfterItsFrameIsReleasedWhenItArrives() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        sync.receive(first)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3-30665"))

        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(second)

        XCTAssertEqual(sync.relayTrack, second)
    }

    func testAFrameOfANewTrackWithNoHeldStateGivesNoRelayTrack() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        sync.receive(first)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        // The next file. Its state is late, and its ICY text does not name the released state.
        sync.receiveIcyText("Other Artist - Other Song", segmentFrame: frame("ls-2-4"))

        XCTAssertNil(sync.relayTrack)
        XCTAssertEqual(sync.icyTrack, IcyTrack(artist: "Other Artist", title: "Other Song"))
    }

    func testAFrameWithNoHeldStateDoesNotSelectAStateWithADifferentPlayId() {
        var sync = IcySync()
        sync.receive(chapter("Two", playId: "ls-1-3-30665"))

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        XCTAssertNil(sync.relayTrack)
    }

    func testAFrameWithNoHeldStateUsesTheIcyRuleForStatesWithNoPlayId() {
        var sync = IcySync()
        let older = chapter("One", playId: nil)
        let newer = chapter("Two", playId: nil)
        sync.receive(older)
        sync.receive(newer)

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        XCTAssertEqual(sync.relayTrack, newer)
    }

    // MARK: - The ICY rule

    func testAFrameWithANullPlayIdUsesTheIcyRule() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(first)
        sync.receive(second)

        sync.receiveIcyText(episodeText, segmentFrame: frame(nil))

        XCTAssertEqual(sync.relayTrack, second)
    }

    func testAGroupWithNoFrameBeforeTheFirstFrameUsesTheIcyRule() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(first)
        sync.receive(second)

        sync.receiveIcyText(episodeText)

        XCTAssertEqual(sync.relayTrack, second)
    }

    func testAGroupWithNoFrameAfterAFrameKeepsTheReleasedState() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(first)
        sync.receive(second)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))
        XCTAssertEqual(sync.relayTrack, first)

        sync.receiveIcyText(episodeText)

        XCTAssertEqual(sync.relayTrack, first)
    }

    /// The short segment at a track start has the track tags and no frame. A later chapter state must not show.
    func testTheShortSegmentAtATrackStartSelectsNoLaterChapterState() {
        var sync = IcySync()
        let song = TrackDisplay(artist: "A", title: "Song", artwork: nil, songLine: "A - Song", playId: "ls-1-2")
        sync.receive(song)
        sync.receiveIcyText("A - Song", segmentFrame: frame("ls-1-2"))
        XCTAssertEqual(sync.relayTrack, song)

        let first = chapter("One", playId: "ls-5-3", block: "block-1")
        let second = chapter("Two", playId: "ls-5-3-30665", block: "block-2")
        sync.receive(first)
        sync.receive(second)

        sync.receiveIcyText(episodeText)
        XCTAssertNil(sync.relayTrack)

        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-5-3"))
        XCTAssertEqual(sync.relayTrack, first)
    }

    // MARK: - The value end (ADR 0028)

    func testAStateWithNoValueSentAgainDoesNotHoldTheValueEndAgain() {
        var sync = IcySync()
        let valued = chapter("One", playId: "ls-1-3", block: "block-1")
        let jingle = chapter("One", playId: nil)
        sync.receive(valued)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        let held = sync.receive(jingle, holdValueEnd: true)
        XCTAssertNotNil(held)

        XCTAssertNil(sync.receive(jingle, holdValueEnd: true))
        XCTAssertTrue(sync.releaseValueEnd(held!))
    }

    func testAFrameUsesTheTitleAloneMatchForTheReleasedState() {
        var sync = IcySync()
        let track = TrackDisplay(
            artist: "Malachi", title: "Working Man", artwork: nil, songLine: "Malachi - Working Man", playId: "ls-1-3"
        )
        sync.receive(track)
        sync.receiveIcyText(
            "Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man",
            segmentFrame: frame("ls-1-3")
        )
        XCTAssertEqual(sync.relayTrack, track)

        sync.receiveIcyText(
            "Behind The Sch3m3s - Malachi - Working Man", titleAlone: "Malachi - Working Man",
            segmentFrame: frame("ls-1-3-5000")
        )

        XCTAssertEqual(sync.relayTrack, track)
    }

    // MARK: - The session

    func testClearStatesGivesNoRelayTrackWithAFrame() {
        var sync = IcySync()
        sync.receive(chapter("One", playId: "ls-1-3"))
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        sync.clearStates()

        XCTAssertNil(sync.relayTrack)
    }

    func testResetIcyClearsTheFrame() {
        var sync = IcySync()
        let first = chapter("One", playId: "ls-1-3")
        let second = chapter("Two", playId: "ls-1-3-30665")
        sync.receive(first)
        sync.receive(second)
        sync.receiveIcyText(episodeText, segmentFrame: frame("ls-1-3"))

        sync.resetIcy()
        sync.receiveIcyText(episodeText)

        XCTAssertEqual(sync.relayTrack, second)
    }
}

/// ADR 0030: the parse of the `musicindex.hls/2` frame.
final class SegmentFrameTests: XCTestCase {
    func testAFrameWithAPlayIdGivesThePlayId() {
        let value = #"{"schema":"musicindex.hls/2","playId":"ls-1795667992160-3-30665"}"#
        XCTAssertEqual(SegmentFrame.parse(value), SegmentFrame(playId: "ls-1795667992160-3-30665"))
    }

    func testANullMissingOrEmptyPlayIdGivesAFrameWithNoPlayId() {
        for value in [
            #"{"schema":"musicindex.hls/2","playId":null}"#,
            #"{"schema":"musicindex.hls/2"}"#,
            #"{"schema":"musicindex.hls/2","playId":""}"#,
        ] {
            XCTAssertEqual(SegmentFrame.parse(value), SegmentFrame(playId: nil), value)
        }
    }

    func testAnotherSchemaOrAnInvalidValueGivesNoFrame() {
        for value in [
            #"{"schema":"musicindex.hls/1","playId":"ls-1-3"}"#,
            #"{"playId":"ls-1-3"}"#,
            #"{"schema":"musicindex.hls/2","playId":12}"#,
            #"["musicindex.hls/2"]"#,
            "not json",
            "",
        ] {
            XCTAssertNil(SegmentFrame.parse(value), value)
        }
    }

    func testWithSegmentFrameKeepsTheTextAndTheTitleAlone() {
        let text = IcyText(text: "A - B", titleAlone: "B").with(segmentFrame: SegmentFrame(playId: "ls-1-3"))
        XCTAssertEqual(text, IcyText(text: "A - B", titleAlone: "B", segmentFrame: SegmentFrame(playId: "ls-1-3")))
    }
}
