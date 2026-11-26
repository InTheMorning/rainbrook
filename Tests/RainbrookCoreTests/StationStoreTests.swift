import Foundation
import XCTest
@testable import RainbrookCore

/// ADR 0017 §The station. ADR 0029 Decision 5: no list gives an empty list.
final class StationStoreTests: XCTestCase {
    private let streamText = "https://bastone.heycitizen.xyz/stream"
    private let otherStreamText = "https://other.example.org/stream"

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

    // MARK: - No stored list

    func testNoStoredListGivesAnEmptyListAndNoSelection() {
        let store = StationStore(defaults: defaults)

        XCTAssertTrue(store.stations.isEmpty)
        XCTAssertNil(store.selectedID)
    }

    func testAStoredListThatDoesNotDecodeGivesAnEmptyList() {
        defaults.set(Data([0x01, 0x02, 0x03]), forKey: "rainbrook.stations")

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
