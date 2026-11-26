import Foundation
import XCTest
@testable import RainbrookCore

final class LoadedAudioTests: XCTestCase {
    func testBufferedAheadCountsFromCurrentTime() {
        let ranges: [ClosedRange<Double>] = [0...2, 5...12]
        XCTAssertEqual(LoadedAudio.bufferedAhead(currentTime: 6, loadedRanges: ranges), 6)
        XCTAssertEqual(LoadedAudio.bufferedAhead(currentTime: 3, loadedRanges: ranges), 7)
        XCTAssertEqual(LoadedAudio.bufferedAhead(currentTime: 13, loadedRanges: ranges), 0)
        XCTAssertEqual(LoadedAudio.bufferedAhead(currentTime: 0, loadedRanges: []), 0)
    }

    func testRangeStartingAfterZeroCounts() {
        XCTAssertEqual(LoadedAudio.bufferedAhead(currentTime: 0, loadedRanges: [0.03...4.03]), 4, accuracy: 0.0001)
    }
}
