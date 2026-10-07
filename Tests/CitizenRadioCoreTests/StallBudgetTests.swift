import XCTest
@testable import CitizenRadioCore

/// ADR 0021 §The stall budget.
final class StallBudgetTests: XCTestCase {
    func testSixtiethSecondWithPathEndsTheBudget() {
        var budget = StallBudget()
        for _ in 0..<59 {
            XCTAssertFalse(budget.tick(pathSatisfied: true))
        }
        XCTAssertTrue(budget.tick(pathSatisfied: true))
        XCTAssertEqual(budget.countedSeconds, 60)
    }

    func testSecondsWithNoPathDoNotCount() {
        var budget = StallBudget()
        for _ in 0..<30 {
            XCTAssertFalse(budget.tick(pathSatisfied: false))
        }
        XCTAssertEqual(budget.countedSeconds, 0)
        for _ in 0..<59 {
            XCTAssertFalse(budget.tick(pathSatisfied: true))
        }
        XCTAssertEqual(budget.countedSeconds, 59)
        XCTAssertTrue(budget.tick(pathSatisfied: true))
    }

    func testCountedSecondsCountOnlyTicksWithPath() {
        var budget = StallBudget()
        let ticks = [true, false, true, false, false, true]
        for pathSatisfied in ticks {
            _ = budget.tick(pathSatisfied: pathSatisfied)
        }
        XCTAssertEqual(budget.countedSeconds, 3)
    }

    func testLimitIsSixtySeconds() {
        XCTAssertEqual(StallBudget.limitSeconds, 60)
        XCTAssertEqual(StallBudget().countedSeconds, 0)
    }
}
