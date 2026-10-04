import Foundation
import XCTest
@testable import CitizenRadioCore

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
            XCTAssertEqual(ChimeSetting.shouldPlay(state: state, enabled: true), state == .connecting)
            XCTAssertFalse(ChimeSetting.shouldPlay(state: state, enabled: false))
        }
    }
}
