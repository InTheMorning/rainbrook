import Foundation
import XCTest
@testable import CitizenRadioCore

/// ADR 0020 §Stream quality: the three choices, their maximum values, the default,
/// and the labels in Settings.
final class StreamQualityTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "StreamQualityTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testAutoHasNoPeakBitRate() {
        XCTAssertEqual(StreamQuality.auto.peakBitRate, 0)
    }

    func testMediumPeakBitRate() {
        XCTAssertEqual(StreamQuality.medium.peakBitRate, 120_000)
    }

    func testLowPeakBitRate() {
        XCTAssertEqual(StreamQuality.low.peakBitRate, 64_000)
    }

    func testLabels() {
        XCTAssertEqual(StreamQuality.auto.label, "Auto")
        XCTAssertEqual(StreamQuality.medium.label, "Medium")
        XCTAssertEqual(StreamQuality.low.label, "Low")
    }

    func testDefaultQualityIsAuto() {
        XCTAssertEqual(StreamQualitySetting(defaults: defaults).quality, .auto)
    }

    func testStoredLowQualityIsRead() {
        StreamQualitySetting(defaults: defaults).quality = .low
        XCTAssertEqual(StreamQualitySetting(defaults: defaults).quality, .low)
    }

    func testStoredBadValueGivesAuto() {
        defaults.set("bad", forKey: "citizenRadio.streamQuality")
        XCTAssertEqual(StreamQualitySetting(defaults: defaults).quality, .auto)
    }

    // ADR 0020 §The HLS live offset.

    func testHLSBufferValuesAndLabels() {
        XCTAssertEqual(HLSBuffer.allCases.map(\.seconds), [10, 30, 60, 90])
        XCTAssertEqual(HLSBuffer.seconds30.label, "30 seconds")
    }

    func testDefaultHLSBufferIs30Seconds() {
        XCTAssertEqual(HLSBufferSetting(defaults: defaults).buffer, .seconds30)
    }

    func testStoredHLSBufferIsRead() {
        HLSBufferSetting(defaults: defaults).buffer = .seconds90
        XCTAssertEqual(HLSBufferSetting(defaults: defaults).buffer, .seconds90)
    }

    func testStoredBadHLSBufferGives30Seconds() {
        defaults.set(45, forKey: "citizenRadio.hlsBufferSeconds")
        XCTAssertEqual(HLSBufferSetting(defaults: defaults).buffer, .seconds30)
    }
}
