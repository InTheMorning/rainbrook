import Foundation
import XCTest
@testable import CitizenRadioCore

/// ADR 0012 §The trigger. Each test uses fixed ICY texts and a fixed expected result.
final class BoostTriggerTests: XCTestCase {
    // MARK: - The first text starts no candidate

    func testFirstTextStartsNoCandidateAndOnlyMiddleTextCompletes() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))
        XCTAssertEqual(trigger.receiveIcyText("Track C"), BoostTrigger.Completed(icyText: "Track B", track: nil))
    }

    // MARK: - A chain of different texts completes each middle text in turn

    func testFourTextsCompleteSecondThenThird() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))
        XCTAssertEqual(trigger.receiveIcyText("Track C"), BoostTrigger.Completed(icyText: "Track B", track: nil))
        XCTAssertEqual(trigger.receiveIcyText("Track D"), BoostTrigger.Completed(icyText: "Track C", track: nil))
    }

    // MARK: - An empty text completes the candidate but starts no new one

    func testEmptyTextCompletesCandidateButDoesNotStartOne() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))
        XCTAssertEqual(trigger.receiveIcyText(""), BoostTrigger.Completed(icyText: "Track B", track: nil))

        // The empty text repeats. It equals the present text, so nothing changes.
        XCTAssertNil(trigger.receiveIcyText(""))

        XCTAssertNil(trigger.receiveIcyText("Track D"))
        XCTAssertEqual(trigger.receiveIcyText("Track E"), BoostTrigger.Completed(icyText: "Track D", track: nil))
    }

    // MARK: - A text equal to the text before the candidate drops it as a repeat

    func testRepeatOfPriorTextDropsCandidate() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))

        // "Track A" is the text before the candidate for "Track B". This is the
        // reconnect repeat of ADR 0010: it drops the candidate, not completes it.
        XCTAssertNil(trigger.receiveIcyText("Track A"))

        XCTAssertNil(trigger.receiveIcyText("Track B"))
        XCTAssertEqual(trigger.receiveIcyText("Track C"), BoostTrigger.Completed(icyText: "Track B", track: nil))
    }

    // MARK: - The end of the session drops the candidate and starts a new session

    func testEndSessionDropsCandidateAndStartsNewSession() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))

        trigger.endSession()

        // "Track C" is the first text of the new session: it starts no candidate.
        XCTAssertNil(trigger.receiveIcyText("Track C"))
        // A new candidate starts only after "Track C", for "Track D".
        XCTAssertNil(trigger.receiveIcyText("Track D"))

        // The dropped candidate for "Track B" never completes.
        XCTAssertEqual(trigger.receiveIcyText("Track E"), BoostTrigger.Completed(icyText: "Track D", track: nil))
    }

    // MARK: - The same text, or a text that differs only in case or spacing, changes nothing

    func testSameTextOrCaseOrSpacingDifferenceChangesNothing() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))

        // Differs from the present text only in case.
        XCTAssertNil(trigger.receiveIcyText("track b"))
        // Differs from the present text only in spacing.
        XCTAssertNil(trigger.receiveIcyText("  Track   B  "))

        // The candidate is still the one for "Track B", unaffected by the repeats above.
        XCTAssertEqual(trigger.receiveIcyText("Track C"), BoostTrigger.Completed(icyText: "Track B", track: nil))
    }

    // MARK: - The completed track is the newest non-nil track, and nil does not clear it

    func testCompletedTrackIsNewestNonNilAndNilDoesNotClearIt() {
        var trigger = BoostTrigger()
        let olderTrack = TrackDisplay(artist: "Older Artist", title: "Older Title", artwork: nil)
        let newerTrack = TrackDisplay(artist: "Newer Artist", title: "Newer Title", artwork: nil)

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))

        trigger.selectedTrack(olderTrack)
        trigger.selectedTrack(nil)
        trigger.selectedTrack(newerTrack)

        XCTAssertEqual(
            trigger.receiveIcyText("Track C"),
            BoostTrigger.Completed(icyText: "Track B", track: newerTrack)
        )
    }

    // MARK: - A candidate with no given track completes with nil

    func testCandidateWithNoGivenTrackCompletesWithNilTrack() {
        var trigger = BoostTrigger()

        XCTAssertNil(trigger.receiveIcyText("Track A"))
        XCTAssertNil(trigger.receiveIcyText("Track B"))

        XCTAssertEqual(trigger.receiveIcyText("Track C"), BoostTrigger.Completed(icyText: "Track B", track: nil))
    }
}
