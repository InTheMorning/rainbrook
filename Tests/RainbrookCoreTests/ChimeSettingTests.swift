import Foundation
import XCTest
@testable import RainbrookCore

final class ChimeSettingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "ChimeSettingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testChimeIsEnabledByDefault() {
        XCTAssertTrue(ChimeSetting(defaults: defaults).isEnabled)
    }

    func testDisabledChimeIsSaved() {
        ChimeSetting(defaults: defaults).isEnabled = false
        XCTAssertFalse(ChimeSetting(defaults: defaults).isEnabled)
    }

    func testChimePlaysOnlyWhileConnecting() {
        let states: [PlaybackState] = [.stopped, .connecting, .playing, .interrupted, .failed("Error")]
        for state in states {
            XCTAssertEqual(ChimeSetting.shouldPlay(state: state, enabled: true, dropSeconds: nil), state == .connecting)
            XCTAssertFalse(ChimeSetting.shouldPlay(state: state, enabled: false, dropSeconds: nil))
        }
    }

    /// ADR 0021 §The chime: the start phase has no delay.
    func testStartPhaseChimePlaysAtOnce() {
        XCTAssertTrue(ChimeSetting.shouldPlay(state: .connecting, enabled: true, dropSeconds: nil))
    }

    /// ADR 0021 §The chime: in the played phase, the chime waits 3 seconds.
    func testPlayedPhaseChimeWaitsThreeSeconds() {
        XCTAssertEqual(ChimeSetting.playedPhaseDelaySeconds, 3)
        XCTAssertFalse(ChimeSetting.shouldPlay(state: .connecting, enabled: true, dropSeconds: 0))
        XCTAssertFalse(ChimeSetting.shouldPlay(state: .connecting, enabled: true, dropSeconds: 2))
        XCTAssertTrue(ChimeSetting.shouldPlay(state: .connecting, enabled: true, dropSeconds: 3))
        XCTAssertTrue(ChimeSetting.shouldPlay(state: .connecting, enabled: true, dropSeconds: 10))
    }

    func testPlayingStateNeverChimes() {
        for dropSeconds in [nil, 0, 2, 3, 10] as [Int?] {
            XCTAssertFalse(ChimeSetting.shouldPlay(state: .playing, enabled: true, dropSeconds: dropSeconds))
        }
    }

    func testDisabledChimeNeverPlays() {
        for dropSeconds in [nil, 0, 2, 3, 10] as [Int?] {
            XCTAssertFalse(ChimeSetting.shouldPlay(state: .connecting, enabled: false, dropSeconds: dropSeconds))
        }
    }
}
