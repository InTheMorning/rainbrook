import Foundation
import XCTest
@testable import CitizenRadioCore

final class RelayEventStoreTests: XCTestCase {
    private let stationURI = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "RelayEventStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSaveWithTheStationURLStoresItAndGivesItsEventID() throws {
        let store = RelayEventStore(defaults: defaults)
        let event = try store.save(stationURI)
        XCTAssertEqual(event?.eventID, "DFnUwDM1mzcljaF4pI9Q6w")
        XCTAssertEqual(store.savedText, stationURI)
        XCTAssertEqual(store.event?.eventID, "DFnUwDM1mzcljaF4pI9Q6w")
    }

    func testSaveWithSpacesClearsTheSettingAndGivesNil() throws {
        let store = RelayEventStore(defaults: defaults)
        try store.save(stationURI)
        let event = try store.save("   ")
        XCTAssertNil(event)
        XCTAssertEqual(store.savedText, "")
        XCTAssertNil(store.event)
    }

    func testSaveWithHttpThrowsSchemeAndTheSavedTextDoesNotChange() throws {
        let store = RelayEventStore(defaults: defaults)
        try store.save(stationURI)
        XCTAssertThrowsError(try store.save("http://api.musicindex.org/v1/liveitems/abc")) { error in
            XCTAssertEqual(error as? RelayEvent.ParseError, .scheme)
        }
        XCTAssertEqual(store.savedText, stationURI)
    }
}
