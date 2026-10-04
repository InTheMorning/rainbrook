import Foundation
import XCTest

final class AppIntentsLinkTests: XCTestCase {
    func testAppEntryKeepsIntentsInStaticArchive() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../CitizenRadio/CitizenRadioApp.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        XCTAssertTrue(
            text.contains("RadioShortcuts.updateAppShortcutParameters()"),
            """
            ADR 0003 §Invariants: the app entry must refer to RadioShortcuts. \
            Without that reference, the linker drops RadioIntents.o from the xtool binary \
            and Shortcuts reports an internal error. \
            Call RadioShortcuts.updateAppShortcutParameters() in CitizenRadioApp.init().
            """
        )
    }
}
