import XCTest
@testable import CitizenRadioCore

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
        XCTAssertEqual(model.status, "Add a stream in Settings")
    }

    func testFailedStateShowsErrorMessage() {
        let model = PlayerScreenModel(state: .failed("The stream ended."), hasSavedStream: true)
        XCTAssertEqual(model.status, "The stream ended.")
        XCTAssertTrue(model.isControlEnabled)
    }

    func testSavedStreamShowsStateTitle() {
        XCTAssertEqual(PlayerScreenModel(state: .playing, hasSavedStream: true).status, "Playing live")
        XCTAssertEqual(PlayerScreenModel(state: .stopped, hasSavedStream: true).status, "Ready to play")
    }
}
