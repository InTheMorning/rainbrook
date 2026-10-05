import Foundation
import XCTest
@testable import CitizenRadioCore

final class LRUCacheTests: XCTestCase {
    func testDropsTheLeastRecentEntryAfterAReadKeepsItRecent() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache.insert(1, for: "A")
        cache.insert(2, for: "B")
        XCTAssertEqual(cache.value(for: "A"), 1)
        cache.insert(3, for: "C")

        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.value(for: "A"), 1)
        XCTAssertEqual(cache.value(for: "C"), 3)
        XCTAssertNil(cache.value(for: "B"))
    }

    func testCapacityZeroStoresNothing() {
        var cache = LRUCache<String, Int>(capacity: 0)
        cache.insert(1, for: "A")

        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.value(for: "A"))
    }

    func testNegativeCapacityStoresNothing() {
        var cache = LRUCache<String, Int>(capacity: -1)
        cache.insert(1, for: "A")

        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.value(for: "A"))
    }
}
