import Foundation
import XCTest
@testable import CitizenRadioCore

/// ADR 0017 §The station and §The first start after the update.
final class StationStoreTests: XCTestCase {
    private let oldStreamKey = "citizenRadio.streamURL"
    private let oldRelayKey = "citizenRadio.relayEventURI"
    private let streamText = "https://bastone.heycitizen.xyz/stream"
    private let otherStreamText = "https://other.example.org/stream"
    private let trackInfoText = "https://api.musicindex.org/v1/liveitems/DFnUwDM1mzcljaF4pI9Q6w"

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "StationStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeStation(streamText: String) throws -> Station {
        try Station(name: "", streamText: streamText, alternateStreamText: "", trackInfoText: "")
    }

    // MARK: - First start

    func testFirstStartWithOldStreamAndRelayGivesOneSelectedStationWithBoth() {
        defaults.set(streamText, forKey: oldStreamKey)
        defaults.set(trackInfoText, forKey: oldRelayKey)

        let store = StationStore(defaults: defaults)

        XCTAssertEqual(store.stations.count, 1)
        let station = store.stations[0]
        XCTAssertEqual(station.stream.absoluteString, streamText)
        XCTAssertEqual(station.trackInfo, trackInfoText)
        XCTAssertEqual(store.selectedID, station.id)
        XCTAssertNil(defaults.string(forKey: oldStreamKey))
        XCTAssertNil(defaults.string(forKey: oldRelayKey))
    }

    func testFirstStartWithOldStreamAndBadRelayGivesOneStationWithNoTrackInfo() {
        defaults.set(streamText, forKey: oldStreamKey)
        defaults.set("not a relay uri", forKey: oldRelayKey)

        let store = StationStore(defaults: defaults)

        XCTAssertEqual(store.stations.count, 1)
        XCTAssertNil(store.stations[0].trackInfo)
        XCTAssertNil(defaults.string(forKey: oldRelayKey))
    }

    func testFirstStartWithNoOldKeysGivesAnEmptyListAndNoSelection() {
        let store = StationStore(defaults: defaults)

        XCTAssertTrue(store.stations.isEmpty)
        XCTAssertNil(store.selectedID)
    }

    func testFirstStartWithAnInvalidOldStreamGivesAnEmptyList() {
        defaults.set("not a url", forKey: oldStreamKey)

        let store = StationStore(defaults: defaults)

        XCTAssertTrue(store.stations.isEmpty)
        XCTAssertNil(defaults.string(forKey: oldStreamKey))
    }

    func testASecondInitDoesNotRunTheFirstStartRuleAgain() {
        defaults.set(streamText, forKey: oldStreamKey)
        let first = StationStore(defaults: defaults)
        XCTAssertEqual(first.stations.count, 1)

        // A leftover old key must not start the rule a second time.
        defaults.set(otherStreamText, forKey: oldStreamKey)
        let second = StationStore(defaults: defaults)

        XCTAssertEqual(second.stations, first.stations)
    }

    func testAStoredListThatDoesNotDecodeGivesAnEmptyList() {
        defaults.set(Data([0x01, 0x02, 0x03]), forKey: "citizenRadio.stations")

        let store = StationStore(defaults: defaults)

        XCTAssertTrue(store.stations.isEmpty)
    }

    // MARK: - add

    func testAddOfA21stStationThrowsListFull() throws {
        let store = StationStore(defaults: defaults)
        for index in 0..<StationStore.maximumCount {
            try store.add(try makeStation(streamText: "https://example.org/stream\(index)"))
        }
        XCTAssertEqual(store.stations.count, StationStore.maximumCount)

        XCTAssertThrowsError(try store.add(try makeStation(streamText: "https://example.org/extra"))) { error in
            XCTAssertEqual(error as? StationError, .listFull)
        }
        XCTAssertEqual(store.stations.count, StationStore.maximumCount)
    }

    // MARK: - delete

    func testDeleteOfTheSelectedStationClearsTheSelection() throws {
        let store = StationStore(defaults: defaults)
        let station = try makeStation(streamText: streamText)
        try store.add(station)
        store.select(id: station.id)
        XCTAssertEqual(store.selectedID, station.id)

        store.delete(id: station.id)

        XCTAssertNil(store.selectedID)
        XCTAssertTrue(store.stations.isEmpty)
    }

    func testDeleteOfAnotherStationKeepsTheSelection() throws {
        let store = StationStore(defaults: defaults)
        let kept = try makeStation(streamText: streamText)
        let other = try makeStation(streamText: otherStreamText)
        try store.add(kept)
        try store.add(other)
        store.select(id: kept.id)

        store.delete(id: other.id)

        XCTAssertEqual(store.selectedID, kept.id)
        XCTAssertEqual(store.stations.map(\.id), [kept.id])
    }

    // MARK: - update

    func testUpdateReplacesByIdAndKeepsPosition() throws {
        let store = StationStore(defaults: defaults)
        let first = try makeStation(streamText: streamText)
        let second = try makeStation(streamText: otherStreamText)
        try store.add(first)
        try store.add(second)

        let changedSecond = try Station(
            id: second.id,
            name: "Changed",
            streamText: otherStreamText,
            alternateStreamText: "",
            trackInfoText: ""
        )
        store.update(changedSecond)

        XCTAssertEqual(store.stations.map(\.id), [first.id, second.id])
        XCTAssertEqual(store.stations[1].name, "Changed")
    }

    func testUpdateOfAnUnknownIdChangesNothing() throws {
        let store = StationStore(defaults: defaults)
        let station = try makeStation(streamText: streamText)
        try store.add(station)

        let unknown = try makeStation(streamText: otherStreamText)
        store.update(unknown)

        XCTAssertEqual(store.stations.map(\.id), [station.id])
    }

    // MARK: - select

    func testSelectOfAnUnknownIdChangesNothing() throws {
        let store = StationStore(defaults: defaults)
        let station = try makeStation(streamText: streamText)
        try store.add(station)
        store.select(id: station.id)

        store.select(id: UUID())

        XCTAssertEqual(store.selectedID, station.id)
    }
}
