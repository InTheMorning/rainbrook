import Foundation
import XCTest
@testable import CitizenRadioCore

final class NetworkPathSummaryTests: XCTestCase {
    func testShouldReconnectGivesFalseFromNilToSatisfied() {
        let new = NetworkPathSummary(isSatisfied: true, interfaces: ["en0"])
        XCTAssertFalse(NetworkPathSummary.shouldReconnect(from: nil, to: new))
    }

    func testShouldReconnectGivesTrueFromUnsatisfiedToSatisfied() {
        let old = NetworkPathSummary(isSatisfied: false, interfaces: [])
        let new = NetworkPathSummary(isSatisfied: true, interfaces: ["en0"])
        XCTAssertTrue(NetworkPathSummary.shouldReconnect(from: old, to: new))
    }

    func testShouldReconnectGivesFalseFromSatisfiedToSatisfiedWithSameInterfaces() {
        let old = NetworkPathSummary(isSatisfied: true, interfaces: ["en0"])
        let new = NetworkPathSummary(isSatisfied: true, interfaces: ["en0"])
        XCTAssertFalse(NetworkPathSummary.shouldReconnect(from: old, to: new))
    }

    func testShouldReconnectGivesTrueFromSatisfiedToSatisfiedWithDifferentInterfaces() {
        let old = NetworkPathSummary(isSatisfied: true, interfaces: ["en0"])
        let new = NetworkPathSummary(isSatisfied: true, interfaces: ["pdp_ip0"])
        XCTAssertTrue(NetworkPathSummary.shouldReconnect(from: old, to: new))
    }

    func testShouldReconnectGivesFalseForAnyChangeToUnsatisfied() {
        let old = NetworkPathSummary(isSatisfied: true, interfaces: ["en0"])
        let new = NetworkPathSummary(isSatisfied: false, interfaces: ["pdp_ip0"])
        XCTAssertFalse(NetworkPathSummary.shouldReconnect(from: old, to: new))
    }
}
