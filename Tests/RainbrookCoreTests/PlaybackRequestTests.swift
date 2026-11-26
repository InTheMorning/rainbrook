import XCTest
@testable import RainbrookCore

final class PlaybackRequestTests: XCTestCase {
    func testRepeatedPlayDoesNotTogglePlayback() {
        var request = PlaybackRequest()
        request.play()
        request.play()
        XCTAssertTrue(request.wantsPlayback)
    }

    func testCallResumesOnlyOnTheSameOutputWithSystemPermission() {
        for shouldResume in [false, true] {
            for sameOutput in [false, true] {
                var request = PlaybackRequest()
                request.play()
                request.interruptionBegan()
                XCTAssertFalse(request.wantsPlayback)
                XCTAssertEqual(
                    request.interruptionEnded(shouldResume: shouldResume, sameOutput: sameOutput),
                    shouldResume && sameOutput
                )
                XCTAssertEqual(request.wantsPlayback, shouldResume && sameOutput)
            }
        }
    }

    func testStopDuringCallPreventsResume() {
        var request = PlaybackRequest()
        request.play()
        request.interruptionBegan()
        request.stop()
        XCTAssertFalse(request.interruptionEnded(shouldResume: true, sameOutput: true))
        XCTAssertFalse(request.wantsPlayback)
    }

    func testIdleInterruptionDoesNotStartRadio() {
        var request = PlaybackRequest()
        request.interruptionBegan()
        XCTAssertFalse(request.interruptionEnded(shouldResume: true, sameOutput: true))
    }

    func testRepeatedInterruptionNotificationsPreserveResumeRequest() {
        var request = PlaybackRequest()
        request.play()
        request.interruptionBegan()
        request.interruptionBegan()
        XCTAssertTrue(request.interruptionEnded(shouldResume: true, sameOutput: true))
        XCTAssertFalse(request.interruptionEnded(shouldResume: true, sameOutput: true))
    }
}

