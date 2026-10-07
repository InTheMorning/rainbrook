import XCTest
@testable import CitizenRadioCore

final class ArtworkFramesTests: XCTestCase {
    // MARK: - delay(unclamped:clamped:)

    func testUnclampedDelayIsUsed() {
        XCTAssertEqual(ArtworkFrames.delay(unclamped: 0.05, clamped: 0.1), 0.05)
    }

    func testClampedDelayIsUsedWithNoUnclampedDelay() {
        XCTAssertEqual(ArtworkFrames.delay(unclamped: nil, clamped: 0.07), 0.07)
    }

    func testZeroDelayGivesReplacement() {
        XCTAssertEqual(ArtworkFrames.delay(unclamped: 0.0, clamped: nil), 0.1)
    }

    func testShortDelayGivesReplacement() {
        XCTAssertEqual(ArtworkFrames.delay(unclamped: 0.01, clamped: nil), 0.1)
    }

    func testNoDelayGivesReplacement() {
        XCTAssertEqual(ArtworkFrames.delay(unclamped: nil, clamped: nil), 0.1)
    }

    // MARK: - plan(delays:framePixels:)

    func testAllFramesThatFitAreKept() {
        let delays = Array(repeating: 0.1, count: 10)
        // 400 × 400 pixels: 640,000 bytes for each frame. 10 frames fit.
        let plan = ArtworkFrames.plan(delays: delays, framePixels: 160_000)
        XCTAssertEqual(plan.map(\.index), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(plan.map(\.delay), Array(repeating: 0.1, count: 10))
    }

    func testBudgetOfFourKeepsRegularSteps() {
        let delays = Array(repeating: 0.1, count: 10)
        // 3,000,000 pixels: 12,000,000 bytes for each frame. 4 frames fit in 50,331,648 bytes.
        let plan = ArtworkFrames.plan(delays: delays, framePixels: 3_000_000)
        XCTAssertEqual(plan.map(\.index), [0, 3, 6, 9])
        let expected = [0.3, 0.3, 0.3, 0.1]
        XCTAssertEqual(plan.count, expected.count)
        for (kept, delay) in zip(plan, expected) {
            XCTAssertEqual(kept.delay, delay, accuracy: 0.000_001)
        }
    }

    func testEmptyInputGivesEmptyResult() {
        XCTAssertTrue(ArtworkFrames.plan(delays: [], framePixels: 160_000).isEmpty)
    }

    func testFrameLargerThanTheLimitKeepsOneFrameWithTheTotalDelay() {
        let delays = [0.1, 0.2, 0.3]
        // 20,000,000 pixels: 80,000,000 bytes for one frame.
        let plan = ArtworkFrames.plan(delays: delays, framePixels: 20_000_000)
        XCTAssertEqual(plan.map(\.index), [0])
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].delay, 0.6, accuracy: 0.000_001)
    }
}
