import XCTest
@testable import CitizenRadioCore

final class StreamSettingsDraftTests: XCTestCase {
    private let saved = "https://radio.example.org/live"

    func testUnchangedDraftCannotSave() {
        XCTAssertFalse(StreamSettingsDraft(savedURL: saved, chimeEnabled: true, bufferSeconds: 3).canSave)
    }

    func testEmptyDraftCannotSave() {
        var draft = StreamSettingsDraft(savedURL: saved, chimeEnabled: true, bufferSeconds: 3)
        draft.text = "  "
        draft.chimeEnabled = false
        XCTAssertFalse(draft.canSave)
    }

    func testChangedDraftCanSave() {
        var draft = StreamSettingsDraft(savedURL: "", chimeEnabled: true, bufferSeconds: 3)
        draft.text = saved
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeAloneCanSave() {
        var draft = StreamSettingsDraft(savedURL: saved, chimeEnabled: true, bufferSeconds: 3)
        draft.chimeEnabled = false
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeWithoutSavedURLCanSave() {
        var draft = StreamSettingsDraft(savedURL: "", chimeEnabled: false, bufferSeconds: 3)
        draft.chimeEnabled = true
        XCTAssertTrue(draft.canSave)
    }

    func testBufferChangeAloneCanSave() {
        var draft = StreamSettingsDraft(savedURL: saved, chimeEnabled: true, bufferSeconds: 3)
        draft.bufferSeconds = 10
        XCTAssertTrue(draft.canSave)
    }
}
