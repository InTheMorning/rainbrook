import Foundation
import XCTest
@testable import RainbrookCore

/// ADR 0012 §The trigger and ADR 0016 §The switch back and §The minimum play time.
/// Each test uses fixed ICY texts, fixed blocks and fixed times, and a fixed expected result.
final class BoostTriggerTests: XCTestCase {
    /// A track with the given block, or nil for a track with no block.
    private func track(block: String?, title: String = "Track") -> TrackDisplay? {
        guard let block else { return nil }
        return TrackDisplay(
            artist: "Artist", title: title, artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-1", blockGuid: block)
        )
    }

    // MARK: - The first text starts no candidate

    func testFirstTextStartsNoCandidateAndOnlyMiddleTextCompletes() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))
        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 25),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 15)
        )
    }

    // MARK: - A chain of different texts completes each middle text in turn

    func testFourTextsCompleteSecondThenThird() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))
        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 25),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 15)
        )
        XCTAssertEqual(
            trigger.receiveIcyText("Track D", track: nil, at: 40),
            BoostTrigger.Completed(icyText: "Track C", track: nil, playedSeconds: 15)
        )
    }

    // MARK: - An empty text completes the candidate but starts no new one

    func testEmptyTextCompletesCandidateButDoesNotStartOne() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))
        XCTAssertEqual(
            trigger.receiveIcyText("", track: nil, at: 20),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 10)
        )

        // The empty text repeats. It equals the present text, so nothing changes.
        XCTAssertNil(trigger.receiveIcyText("", track: nil, at: 24))

        XCTAssertNil(trigger.receiveIcyText("Track D", track: nil, at: 30))
        XCTAssertEqual(
            trigger.receiveIcyText("Track E", track: nil, at: 42),
            BoostTrigger.Completed(icyText: "Track D", track: nil, playedSeconds: 12)
        )
    }

    // MARK: - A text equal to the text before the candidate drops it as a repeat

    func testRepeatOfPriorTextDropsCandidate() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))

        // "Track A" is the text before the candidate for "Track B". Neither play has a known
        // block, so this is the reconnect repeat of ADR 0010: it drops the candidate.
        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 15))

        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 20))
        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 35),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 15)
        )
    }

    // MARK: - The end of the session drops the candidate and starts a new session

    func testEndSessionDropsCandidateAndStartsNewSession() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))

        trigger.endSession()

        // "Track C" is the first text of the new session: it starts no candidate.
        XCTAssertNil(trigger.receiveIcyText("Track C", track: nil, at: 20))
        // A new candidate starts only after "Track C", for "Track D".
        XCTAssertNil(trigger.receiveIcyText("Track D", track: nil, at: 30))

        // The dropped candidate for "Track B" never completes.
        XCTAssertEqual(
            trigger.receiveIcyText("Track E", track: nil, at: 45),
            BoostTrigger.Completed(icyText: "Track D", track: nil, playedSeconds: 15)
        )
    }

    // MARK: - The same text, or a text that differs only in case or spacing, changes nothing

    func testSameTextOrCaseOrSpacingDifferenceChangesNothing() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 5))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))

        // Differs from the present text only in case.
        XCTAssertNil(trigger.receiveIcyText("track b", track: nil, at: 15))
        // Differs from the present text only in spacing.
        XCTAssertNil(trigger.receiveIcyText("  Track   B  ", track: nil, at: 18))

        // The candidate is still the one for "Track B", unaffected by the repeats above.
        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 30),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 20)
        )
    }

    // MARK: - The completed track is the newest non-nil track, and nil does not clear it

    func testCompletedTrackIsNewestNonNilAndNilDoesNotClearIt() {
        var trigger = BoostTrigger()
        let olderTrack = TrackDisplay(artist: "Older Artist", title: "Older Title", artwork: nil)
        let newerTrack = TrackDisplay(artist: "Newer Artist", title: "Newer Title", artwork: nil)

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))

        trigger.selectedTrack(olderTrack, at: 15)
        trigger.selectedTrack(nil, at: 15)
        trigger.selectedTrack(newerTrack, at: 15)

        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 22),
            BoostTrigger.Completed(icyText: "Track B", track: newerTrack, playedSeconds: 12)
        )
    }

    // MARK: - A candidate with no given track completes with nil

    func testCandidateWithNoGivenTrackCompletesWithNilTrack() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 10))

        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 25),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 15)
        )
    }

    // MARK: - ADR 0016 §The switch back

    func testSwitchBackWithTwoDifferentKnownBlocksCompletesAndStartsACandidate() {
        var trigger = BoostTrigger()
        let a2 = track(block: "a2")

        XCTAssertNil(trigger.receiveIcyText("Track A", track: track(block: "a1"), at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: track(block: "b1"), at: 10))

        // The second "Track A" has a different, known block: a real switch back.
        // It completes the candidate for "Track B" and starts a candidate for "Track A".
        XCTAssertEqual(
            trigger.receiveIcyText("Track A", track: a2, at: 20),
            BoostTrigger.Completed(icyText: "Track B", track: track(block: "b1"), playedSeconds: 10)
        )

        // "Track C" then completes the candidate for "Track A".
        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: track(block: "c1"), at: 35),
            BoostTrigger.Completed(icyText: "Track A", track: a2, playedSeconds: 15)
        )
    }

    func testSwitchBackWithTheSameBlockDropsTheCandidateAsARepeat() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: track(block: "a1"), at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: track(block: "b1"), at: 10))

        // The second "Track A" has the same block as the first: not a new play.
        // This is the reconnect repeat: it drops the candidate for "Track B".
        XCTAssertNil(trigger.receiveIcyText("Track A", track: track(block: "a1"), at: 20))

        // The dropped candidate for "Track B" never completes.
        XCTAssertNil(trigger.receiveIcyText("Track C", track: nil, at: 30))
    }

    func testSwitchBackWithNoBlockForTheSecondPlayDropsTheCandidateAsARepeat() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: track(block: "a1"), at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: track(block: "b1"), at: 10))

        // The second "Track A" gives no block, so the trigger cannot tell a new play.
        // This is the reconnect repeat: it drops the candidate for "Track B".
        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 20))
    }

    // MARK: - ADR 0016 §The minimum play time

    func testPlayedSecondsIsTheTimeFromTheTextToTheTextThatCompletesIt() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 100))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: nil, at: 130))
        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 300),
            BoostTrigger.Completed(icyText: "Track B", track: nil, playedSeconds: 170)
        )
    }

    // MARK: - ADR 0024 §The chapter change

    /// A chapter state of an episode file: the song line is the ICY line of the file.
    private func chapter(_ block: String, songLine: String? = "Show - Episode 7") -> TrackDisplay {
        TrackDisplay(
            artist: "Chapter Artist \(block)", title: "Chapter Title \(block)", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-1", blockGuid: block),
            songLine: songLine
        )
    }

    func testThreeChapterStatesWithOneSongLineGiveThreeCandidates() {
        var trigger = BoostTrigger()
        let c1 = chapter("c1"), c2 = chapter("c2"), c3 = chapter("c3")

        XCTAssertNil(trigger.receiveIcyText("Song S", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Show - Episode 7", track: c1, at: 100))
        // The same chapter state again changes nothing.
        XCTAssertNil(trigger.selectedTrack(c1, at: 100))

        // Each new chapter state completes the candidate of the chapter before it.
        XCTAssertEqual(
            trigger.selectedTrack(c2, at: 400),
            BoostTrigger.Completed(icyText: "Show - Episode 7", track: c1, playedSeconds: 300)
        )
        XCTAssertEqual(
            trigger.selectedTrack(c3, at: 650),
            BoostTrigger.Completed(icyText: "Show - Episode 7", track: c2, playedSeconds: 250)
        )
        // The next ICY text completes the last chapter.
        XCTAssertEqual(
            trigger.receiveIcyText("Song T", track: nil, at: 900),
            BoostTrigger.Completed(icyText: "Show - Episode 7", track: c3, playedSeconds: 250)
        )
    }

    func testChapterChangeStartsACandidateWhenTheListenerJoinedInTheEpisode() {
        var trigger = BoostTrigger()
        let c2 = chapter("c2"), c3 = chapter("c3")

        // The first ICY text of the session starts no candidate.
        XCTAssertNil(trigger.receiveIcyText("Show - Episode 7", track: chapter("c1"), at: 0))
        // The listener hears chapter 2 from its start: a candidate starts, and none completes.
        XCTAssertNil(trigger.selectedTrack(c2, at: 50))
        XCTAssertEqual(
            trigger.selectedTrack(c3, at: 290),
            BoostTrigger.Completed(icyText: "Show - Episode 7", track: c2, playedSeconds: 240)
        )
    }

    func testNewBlockWithoutTheSameSongLineIsNotAChapterChange() {
        var trigger = BoostTrigger()
        let b2 = TrackDisplay(
            artist: "Artist", title: "Track", artwork: nil,
            value: TrackDisplay.ValueIdentity(eventGuid: "event-1", blockGuid: "b2")
        )

        XCTAssertNil(trigger.receiveIcyText("Track A", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Track B", track: track(block: "b1"), at: 10))
        // A state with no song line and a new block keeps the candidate.
        XCTAssertNil(trigger.selectedTrack(b2, at: 20))
        // A state with a song line that the earlier state did not have keeps the candidate.
        XCTAssertNil(trigger.selectedTrack(chapter("c1", songLine: "Track B"), at: 30))

        XCTAssertEqual(
            trigger.receiveIcyText("Track C", track: nil, at: 40),
            BoostTrigger.Completed(icyText: "Track B", track: chapter("c1", songLine: "Track B"), playedSeconds: 30)
        )
    }

    /// ADR 0024 §Open Points, the switch back: a reconnect repeat back to an episode file. The sync selects the newest
    /// chapter state of the file again, and the trigger kept the block of that state.
    func testReconnectRepeatBackToAnEpisodeDropsTheCandidate() {
        var trigger = BoostTrigger()
        let c2 = chapter("c2")

        XCTAssertNil(trigger.receiveIcyText("Song S", track: nil, at: 0))
        XCTAssertNil(trigger.receiveIcyText("Show - Episode 7", track: chapter("c1"), at: 10))
        XCTAssertNotNil(trigger.selectedTrack(c2, at: 300))
        XCTAssertEqual(
            trigger.receiveIcyText("Song T", track: track(block: "t1"), at: 500),
            BoostTrigger.Completed(icyText: "Show - Episode 7", track: c2, playedSeconds: 200)
        )

        // The reconnect repeat gives the episode text again with the same newest chapter state.
        XCTAssertNil(trigger.receiveIcyText("Show - Episode 7", track: c2, at: 520))
        // The dropped candidate for "Song T" never completes.
        XCTAssertNil(trigger.receiveIcyText("Song U", track: nil, at: 700))
    }
}
