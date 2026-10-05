import XCTest
@testable import CitizenRadioCore

final class StreamSettingsDraftTests: XCTestCase {
    private let saved = "https://radio.example.org/live"
    private let savedRelay = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"

    func testUnchangedDraftCannotSave() {
        XCTAssertFalse(
            StreamSettingsDraft(
                savedURL: saved, chimeEnabled: true, dailyLimitSats: 1000, relayText: ""
            ).canSave
        )
    }

    func testEmptyDraftCannotSave() {
        var draft = StreamSettingsDraft(
            savedURL: saved, chimeEnabled: true, dailyLimitSats: 1000, relayText: ""
        )
        draft.text = "  "
        draft.chimeEnabled = false
        XCTAssertFalse(draft.canSave)
    }

    func testChangedDraftCanSave() {
        var draft = StreamSettingsDraft(
            savedURL: "", chimeEnabled: true, dailyLimitSats: 1000, relayText: ""
        )
        draft.text = saved
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeAloneCanSave() {
        var draft = StreamSettingsDraft(
            savedURL: saved, chimeEnabled: true, dailyLimitSats: 1000, relayText: ""
        )
        draft.chimeEnabled = false
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeWithoutSavedURLCanSave() {
        var draft = StreamSettingsDraft(
            savedURL: "", chimeEnabled: false, dailyLimitSats: 1000, relayText: ""
        )
        draft.chimeEnabled = true
        XCTAssertTrue(draft.canSave)
    }


    func testDailyLimitChangeAloneCanSave() {
        var draft = StreamSettingsDraft(
            savedURL: saved, chimeEnabled: true, dailyLimitSats: 1000, relayText: ""
        )
        draft.dailyLimitSats = 2500
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testRelayTextChangeAloneCanSave() {
        var draft = StreamSettingsDraft(
            savedURL: saved, chimeEnabled: true, dailyLimitSats: 1000, relayText: ""
        )
        draft.relayText = savedRelay
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testRelayTextChangeToEmptyCanSave() {
        var draft = StreamSettingsDraft(
            savedURL: saved, chimeEnabled: true, dailyLimitSats: 1000, relayText: savedRelay
        )
        draft.relayText = ""
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }
}
