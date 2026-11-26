import XCTest
@testable import RainbrookCore

/// ADR 0022 §The artwork retry: the retry intervals and their end.
final class ArtworkRetryTests: XCTestCase {
    func testRetriesOneToFourGiveTheDelays() {
        XCTAssertEqual(ArtworkRetry.delay(beforeRetry: 1), 2)
        XCTAssertEqual(ArtworkRetry.delay(beforeRetry: 2), 5)
        XCTAssertEqual(ArtworkRetry.delay(beforeRetry: 3), 10)
        XCTAssertEqual(ArtworkRetry.delay(beforeRetry: 4), 30)
    }

    func testRetryFiveGivesNil() {
        XCTAssertNil(ArtworkRetry.delay(beforeRetry: 5))
    }
}
