import XCTest
@testable import CitizenRadioCore

final class StreamSettingsDraftTests: XCTestCase {
    private func makeDraft(
        chimeEnabled: Bool, dailyLimitSats: Int = 1000, streamQuality: StreamQuality = .auto,
        boostEnabled: Bool, boostAmountText: String = "100", boostMessage: String = "",
        boostSenderName: String = "", boostAppName: String = "", boostMinimumPlaySecondsText: String = "60"
    ) -> StreamSettingsDraft {
        StreamSettingsDraft(
            chimeEnabled: chimeEnabled, dailyLimitSats: dailyLimitSats, streamQuality: streamQuality,
            boostEnabled: boostEnabled, boostAmountText: boostAmountText,
            boostMessage: boostMessage, boostSenderName: boostSenderName, boostAppName: boostAppName,
            boostMinimumPlaySecondsText: boostMinimumPlaySecondsText
        )
    }

    func testUnchangedDraftCannotSave() {
        XCTAssertFalse(makeDraft(chimeEnabled: true, boostEnabled: false).canSave)
    }

    func testChangeBackToSavedValueCannotSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.chimeEnabled = false
        draft.chimeEnabled = true
        XCTAssertFalse(draft.canSave)
    }

    func testChimeChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.chimeEnabled = false
        XCTAssertTrue(draft.canSave)
    }

    func testDailyLimitChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.dailyLimitSats = 2500
        XCTAssertTrue(draft.canSave)
    }

    func testStreamQualityChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.streamQuality = .low
        XCTAssertTrue(draft.canSave)
    }

    func testStreamQualityChangeBackToSavedValueCannotSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.streamQuality = .low
        draft.streamQuality = .auto
        XCTAssertFalse(draft.canSave)
    }

    func testHLSBufferChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.hlsBuffer = .seconds60
        XCTAssertTrue(draft.canSave)
        draft.hlsBuffer = .seconds30
        XCTAssertFalse(draft.canSave)
    }

    func testBoostEnabledChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.boostEnabled = true
        XCTAssertTrue(draft.canSave)
    }

    func testBoostAmountChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: true)
        draft.boostAmountText = "250"
        XCTAssertTrue(draft.canSave)
    }

    func testBoostMessageChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: true)
        draft.boostMessage = "Thank you for the music."
        XCTAssertTrue(draft.canSave)
    }

    func testBoostSenderNameChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: true)
        draft.boostSenderName = "A listener"
        XCTAssertTrue(draft.canSave)
    }

    func testBoostAppNameChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: true)
        draft.boostAppName = "My App"
        XCTAssertTrue(draft.canSave)
    }

    func testMinimumPlaySecondsChangeAloneCanSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: true)
        draft.boostMinimumPlaySecondsText = "30"
        XCTAssertTrue(draft.canSave)
    }

    func testInvalidMinimumPlaySecondsTextDisablesSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.boostMinimumPlaySecondsText = "601"
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidMinimumPlaySecondsTextDisablesSaveWithOtherChanges() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.boostMinimumPlaySecondsText = "abc"
        draft.chimeEnabled = false
        draft.boostEnabled = true
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidAmountTextDisablesSave() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.boostAmountText = "abc"
        XCTAssertFalse(draft.canSave)
    }

    func testInvalidAmountTextDisablesSaveWithOtherChanges() {
        var draft = makeDraft(chimeEnabled: true, boostEnabled: false)
        draft.boostAmountText = "0"
        draft.chimeEnabled = false
        draft.dailyLimitSats = 2500
        draft.boostEnabled = true
        draft.boostMessage = "Thank you"
        XCTAssertFalse(draft.canSave)
    }
}
