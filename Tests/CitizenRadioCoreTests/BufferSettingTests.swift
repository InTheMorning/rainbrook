import Foundation
import XCTest
@testable import CitizenRadioCore

final class BufferSettingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "BufferSettingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultIsThreeSeconds() {
        XCTAssertEqual(BufferSetting(defaults: defaults).seconds, 3)
    }

    func testSavedChoiceIsKept() {
        BufferSetting(defaults: defaults).seconds = 10
        XCTAssertEqual(BufferSetting(defaults: defaults).seconds, 10)
    }

    func testUnknownStoredValueUsesDefault() {
        defaults.set(7, forKey: "citizenRadio.bufferSeconds")
        XCTAssertEqual(BufferSetting(defaults: defaults).seconds, 3)
    }

    func testBufferedAheadCountsFromCurrentTime() {
        let ranges: [ClosedRange<Double>] = [0...2, 5...12]
        XCTAssertEqual(BufferSetting.bufferedAhead(currentTime: 6, loadedRanges: ranges), 6)
        XCTAssertEqual(BufferSetting.bufferedAhead(currentTime: 3, loadedRanges: ranges), 7)
        XCTAssertEqual(BufferSetting.bufferedAhead(currentTime: 13, loadedRanges: ranges), 0)
        XCTAssertEqual(BufferSetting.bufferedAhead(currentTime: 0, loadedRanges: []), 0)
    }

    func testRangeStartingAfterZeroCounts() {
        XCTAssertEqual(BufferSetting.bufferedAhead(currentTime: 0, loadedRanges: [0.03...4.03]), 4, accuracy: 0.0001)
    }

    func testExpiredWaitStartsWithoutBuffer() {
        XCTAssertEqual(BufferSetting.maxWaitSeconds(target: 3), 8)
        XCTAssertFalse(BufferSetting.shouldStart(bufferedAhead: 0, target: 3, waitExpired: false))
        XCTAssertTrue(BufferSetting.shouldStart(bufferedAhead: 0, target: 3, waitExpired: true))
        XCTAssertLessThan(BufferSetting.maxWaitSeconds(target: 30), BufferSetting.timeoutSeconds(target: 30))
    }

    func testReadyOnlyWhenTargetIsLoaded() {
        XCTAssertFalse(BufferSetting.isReady(bufferedAhead: 2.9, target: 3))
        XCTAssertTrue(BufferSetting.isReady(bufferedAhead: 3, target: 3))
        XCTAssertTrue(BufferSetting.isReady(bufferedAhead: 0, target: 0))
    }

    func testTimeoutIncludesBuffer() {
        XCTAssertEqual(BufferSetting.timeoutSeconds(target: 0), 20)
        XCTAssertEqual(BufferSetting.timeoutSeconds(target: 30), 50)
    }
}
