import Foundation
import XCTest
@testable import RainbrookCore

final class RadioURLActionTests: XCTestCase {
    func testPlaybackLinks() throws {
        XCTAssertEqual(RadioURLAction(try XCTUnwrap(URL(string: "rainbrook://play"))), .play)
        XCTAssertEqual(RadioURLAction(try XCTUnwrap(URL(string: "rainbrook://stop"))), .stop)
        XCTAssertEqual(RadioURLAction(try XCTUnwrap(URL(string: "RAINBROOK://PLAY/"))), .play)
    }

    func testRejectsUnknownActionsAndSchemes() throws {
        for text in ["https://play", "rainbrook://pause", "rainbrook:///play", "rainbrook://"] {
            XCTAssertNil(RadioURLAction(try XCTUnwrap(URL(string: text))), text)
        }
    }

    func testRejectsSettingsOverridesAndDecoratedActions() throws {
        for text in [
            "rainbrook://play?url=https://example.org/other",
            "rainbrook://play#stop",
            "rainbrook://play/extra",
            "rainbrook://user@play",
            "rainbrook://play:1234"
        ] {
            XCTAssertNil(RadioURLAction(try XCTUnwrap(URL(string: text))), text)
        }
    }
}
