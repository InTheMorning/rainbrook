import Foundation
import XCTest
@testable import CitizenRadioCore

/// Task stations-task-003: the relay clients when the app reads the event of the selected station again.
final class RelayEventChangeTests: XCTestCase {
    private let eventA = try! RelayEvent(uri: "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w")
    private let eventB = try! RelayEvent(uri: "https://api.musicindex.org/v1/liveitems/AAnUwDM1mzcljaF4pI9Q6w")

    func testChangeFromAnEventToNilStartsNoClientAndClearsTheRelayTrack() {
        let change = RelayEventChange.decide(current: eventA, new: nil, playbackActive: true, clientExists: true)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: true, startsClient: false))
    }

    func testEqualEventAfterTheStartStartsNoSecondClient() {
        let change = RelayEventChange.decide(current: eventA, new: eventA, playbackActive: true, clientExists: true)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: false, startsClient: false))
    }

    func testDifferentEventRestartsTheClient() {
        let change = RelayEventChange.decide(current: eventA, new: eventB, playbackActive: true, clientExists: true)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: true, startsClient: true))
    }

    func testEventOfANewStationStartsAClient() {
        let change = RelayEventChange.decide(current: nil, new: eventA, playbackActive: true, clientExists: false)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: true, startsClient: true))
    }

    func testEqualEventWithNoClientStartsAClient() {
        let change = RelayEventChange.decide(current: eventA, new: eventA, playbackActive: true, clientExists: false)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: false, startsClient: true))
    }

    func testNoClientStartsWhilePlaybackIsNotActive() {
        let change = RelayEventChange.decide(current: eventA, new: eventB, playbackActive: false, clientExists: false)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: true, startsClient: false))
    }

    func testNilToNilChangesNothing() {
        let change = RelayEventChange.decide(current: nil, new: nil, playbackActive: true, clientExists: false)
        XCTAssertEqual(change, RelayEventChange(clearsRelay: false, startsClient: false))
    }
}
