import XCTest
@testable import RainbrookCore

final class PlayerScreenModelTests: XCTestCase {
    func testStoppedAndFailedStatesShowPlay() {
        for state in [PlaybackState.stopped, .failed("Error")] {
            XCTAssertEqual(PlayerScreenModel(state: state, hasSavedStream: true).control, .play)
        }
    }

    func testActiveStatesShowStop() {
        for state in [PlaybackState.connecting, .playing, .interrupted] {
            let model = PlayerScreenModel(state: state, hasSavedStream: true)
            XCTAssertEqual(model.control, .stop)
            XCTAssertTrue(model.isControlEnabled)
        }
    }

    func testPlayIsDisabledWithoutSavedStream() {
        let model = PlayerScreenModel(state: .stopped, hasSavedStream: false)
        XCTAssertEqual(model.control, .play)
        XCTAssertFalse(model.isControlEnabled)
        XCTAssertEqual(model.status, "Add a station in Settings")
    }

    func testFailedStateShowsErrorMessage() {
        let model = PlayerScreenModel(state: .failed("The stream ended."), hasSavedStream: true)
        XCTAssertEqual(model.status, "The stream ended.")
        XCTAssertTrue(model.isControlEnabled)
    }

    func testSavedStreamShowsStateTitle() {
        XCTAssertNil(PlayerScreenModel(state: .playing, hasSavedStream: true).status)
        XCTAssertEqual(PlayerScreenModel(state: .stopped, hasSavedStream: true).status, "Ready to play")
    }

    /// ADR 0021 §The status.
    func testDropWithNoPathShowsWaitingForNetwork() {
        let model = PlayerScreenModel(state: .connecting, hasSavedStream: true, waitingForNetwork: true)
        XCTAssertEqual(model.status, "Waiting for the network")
        XCTAssertEqual(model.control, .stop)
    }

    func testDropWithPathShowsConnecting() {
        let model = PlayerScreenModel(state: .connecting, hasSavedStream: true, waitingForNetwork: false)
        XCTAssertEqual(model.status, "Connecting")
    }

    func testPlayingIgnoresWaitingForNetwork() {
        let model = PlayerScreenModel(state: .playing, hasSavedStream: true, waitingForNetwork: true)
        XCTAssertNil(model.status)
    }
}
