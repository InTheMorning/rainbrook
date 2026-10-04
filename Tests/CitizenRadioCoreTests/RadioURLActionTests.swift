import Foundation
import XCTest
@testable import CitizenRadioCore

final class RadioURLActionTests: XCTestCase {
    func testPlaybackLinks() throws {
        XCTAssertEqual(RadioURLAction(try XCTUnwrap(URL(string: "citizenradio://play"))), .play)
        XCTAssertEqual(RadioURLAction(try XCTUnwrap(URL(string: "citizenradio://stop"))), .stop)
        XCTAssertEqual(RadioURLAction(try XCTUnwrap(URL(string: "CITIZENRADIO://PLAY/"))), .play)
    }

    func testRejectsUnknownActionsAndSchemes() throws {
        for text in ["https://play", "citizenradio://pause", "citizenradio:///play", "citizenradio://"] {
            XCTAssertNil(RadioURLAction(try XCTUnwrap(URL(string: text))), text)
        }
    }

    func testRejectsSettingsOverridesAndDecoratedActions() throws {
        for text in [
            "citizenradio://play?url=https://example.org/other",
            "citizenradio://play#stop",
            "citizenradio://play/extra",
            "citizenradio://user@play",
            "citizenradio://play:1234"
        ] {
            XCTAssertNil(RadioURLAction(try XCTUnwrap(URL(string: text))), text)
        }
    }
}
