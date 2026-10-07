import XCTest
@testable import CitizenRadioCore

final class StreamSettingsDraftTests: XCTestCase {
    private let saved = "https://radio.example.org/live"
    private let savedRelay = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"

    private func makeDraft(
        savedURL: String, chimeEnabled: Bool, dailyLimitSats: Int = 1000, relayText: String,
        boostEnabled: Bool, boostAmountText: String = "100", boostMessage: String = "",
        boostSenderName: String = "", boostAppName: String = "", boostMinimumPlaySecondsText: String = "60"
    ) -> StreamSettingsDraft {
        StreamSettingsDraft(
            savedURL: savedURL, chimeEnabled: chimeEnabled, dailyLimitSats: dailyLimitSats,
            relayText: relayText, boostEnabled: boostEnabled, boostAmountText: boostAmountText,
            boostMessage: boostMessage, boostSenderName: boostSenderName, boostAppName: boostAppName,
            boostMinimumPlaySecondsText: boostMinimumPlaySecondsText
        )
    }

    func testUnchangedDraftCannotSave() {
        XCTAssertFalse(
            makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false).canSave
        )
    }

    func testEmptyDraftCannotSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.text = "  "
        draft.chimeEnabled = false
        XCTAssertFalse(draft.canSave)
    }

    func testChangedDraftCanSave() {
        var draft = makeDraft(savedURL: "", chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.text = saved
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.chimeEnabled = false
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testChimeChangeWithoutSavedURLCanSave() {
        var draft = makeDraft(savedURL: "", chimeEnabled: false, relayText: "", boostEnabled: false)
        draft.chimeEnabled = true
        XCTAssertTrue(draft.canSave)
    }


    func testDailyLimitChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.dailyLimitSats = 2500
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testRelayTextChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.relayText = savedRelay
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testRelayTextChangeToEmptyCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: savedRelay, boostEnabled: false)
        draft.relayText = ""
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testBoostEnabledChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.boostEnabled = true
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testBoostAmountChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: true)
        draft.boostAmountText = "250"
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testBoostMessageChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: true)
        draft.boostMessage = "Thank you for the music."
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testBoostSenderNameChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: true)
        draft.boostSenderName = "A listener"
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testBoostAppNameChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: true)
        draft.boostAppName = "My App"
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testMinimumPlaySecondsChangeAloneCanSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: true)
        draft.boostMinimumPlaySecondsText = "30"
        XCTAssertFalse(draft.urlChanged)
        XCTAssertTrue(draft.canSave)
    }

    func testInvalidMinimumPlaySecondsTextDisablesSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.boostMinimumPlaySecondsText = "601"
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidMinimumPlaySecondsTextDisablesSaveWithOtherChanges() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.boostMinimumPlaySecondsText = "abc"
        draft.chimeEnabled = false
        draft.boostEnabled = true
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidAmountTextDisablesSave() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.boostAmountText = "abc"
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidAmountTextDisablesSaveWithOtherChanges() {
        var draft = makeDraft(savedURL: saved, chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.boostAmountText = "0"
        draft.chimeEnabled = false
        draft.dailyLimitSats = 2500
        draft.boostEnabled = true
        draft.boostMessage = "Thank you"
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidAmountTextDisablesSaveWithChangedURL() {
        var draft = makeDraft(savedURL: "", chimeEnabled: true, relayText: "", boostEnabled: false)
        draft.text = saved
        draft.boostAmountText = "100001"
        XCTAssertFalse(draft.canSave)
    }
}
