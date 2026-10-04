import XCTest
@testable import CitizenRadioCore

final class StreamSettingsDraftTests: XCTestCase {
    private let saved = "https://radio.example.org/live"

    func testUnchangedDraftCannotSave() {
        XCTAssertFalse(StreamSettingsDraft(savedURL: saved, chimeEnabled: true).canSave)
    }

    func testEmptyDraftCannotSave() {
        var draft = StreamSettingsDraft(savedURL: saved, chimeEnabled: true)
        draft.text = "  "
        draft.chimeEnabled = false
        XCTAssertFalse(draft.canSave)
    }

    func testChangedDraftCanSave() {
        var draft = StreamSettingsDraft(savedURL: "", chimeEnabled: true)
        draft.text = saved
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeAloneCanSave() {
        var draft = StreamSettingsDraft(savedURL: saved, chimeEnabled: true)
        draft.chimeEnabled = false
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeWithoutSavedURLCanSave() {
        var draft = StreamSettingsDraft(savedURL: "", chimeEnabled: false)
        draft.chimeEnabled = true
        XCTAssertTrue(draft.canSave)
    }
}
