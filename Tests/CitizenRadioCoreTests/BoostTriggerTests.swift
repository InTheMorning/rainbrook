import Foundation
import XCTest
@testable import CitizenRadioCore

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

        trigger.selectedTrack(olderTrack)
        trigger.selectedTrack(nil)
        trigger.selectedTrack(newerTrack)

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
}
