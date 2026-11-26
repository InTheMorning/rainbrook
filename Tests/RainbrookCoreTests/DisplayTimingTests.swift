import Foundation
import XCTest
@testable import RainbrookCore

final class DisplayTimingTests: XCTestCase {
    func testDelayGivesZeroForNegativeValue() {
        XCTAssertEqual(DisplayTiming.delay(bufferedAhead: -1), .zero)
    }

    func testDelayGivesZeroForZeroValue() {
        XCTAssertEqual(DisplayTiming.delay(bufferedAhead: 0), .zero)
    }

    func testDelayGivesZeroForNaN() {
        XCTAssertEqual(DisplayTiming.delay(bufferedAhead: .nan), .zero)
    }

    func testDelayGivesZeroForInfinity() {
        XCTAssertEqual(DisplayTiming.delay(bufferedAhead: .infinity), .zero)
    }

    func testDelayGivesTheValueInSeconds() {
        // 3.5 seconds should give exactly 3.5 seconds
        let delay = DisplayTiming.delay(bufferedAhead: 3.5)
        XCTAssertEqual(delay, .milliseconds(3500))
        XCTAssertEqual(delay, .seconds(3.5))
    }

    func testDelayClampToMaximum() {
        // 90 seconds should clamp to 60 seconds
        let delay = DisplayTiming.delay(bufferedAhead: 90)
        let expected = Duration(secondsComponent: 60, attosecondsComponent: 0)
        XCTAssertEqual(delay, expected)
    }
}
