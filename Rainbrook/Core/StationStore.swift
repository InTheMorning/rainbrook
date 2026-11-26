import Foundation

/// Stores the list of stations and the selected station, in UserDefaults.
/// ADR 0017 §The station. With no stored list, the list is empty and no station is selected (ADR 0029).
public struct StationStore {
    /// The highest number of stations the list keeps.
    public static let maximumCount = 20

    private static let stationsKey = "rainbrook.stations"
    private static let selectedIDKey = "rainbrook.selectedStationID"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The stored stations. A stored list that does not decode gives an empty list.
    public var stations: [Station] {
        guard let data = defaults.data(forKey: Self.stationsKey),
              let list = try? JSONDecoder().decode([Station].self, from: data) else {
            return []
        }
        return list
    }

    /// The identifier of the selected station, or nil.
    public var selectedID: UUID? {
        guard let text = defaults.string(forKey: Self.selectedIDKey) else { return nil }
        return UUID(uuidString: text)
    }

    /// The selected station, or nil.
    public var selected: Station? {
        guard let id = selectedID else { return nil }
        return stations.first { $0.id == id }
    }

    /// Adds the station at the end. Throws StationError.listFull at 20 stations.
    public func add(_ station: Station) throws {
        var list = stations
        guard list.count < Self.maximumCount else {
            throw StationError.listFull
        }
        list.append(station)
        Self.save(list, defaults: defaults)
    }

    /// Replaces the station with the same id. An unknown id changes nothing.
    public func update(_ station: Station) {
        var list = stations
        guard let index = list.firstIndex(where: { $0.id == station.id }) else { return }
        list[index] = station
        Self.save(list, defaults: defaults)
    }

    /// Removes the station. If it is the selected station, no station is selected.
    public func delete(id: UUID) {
        var list = stations
        list.removeAll { $0.id == id }
        Self.save(list, defaults: defaults)
        if selectedID == id {
            defaults.removeObject(forKey: Self.selectedIDKey)
        }
    }

    /// Selects the station. An unknown id changes nothing.
    public func select(id: UUID) {
        guard stations.contains(where: { $0.id == id }) else { return }
        defaults.set(id.uuidString, forKey: Self.selectedIDKey)
    }

    /// Writes the list as JSON.
    private static func save(_ stations: [Station], defaults: UserDefaults) {
        let data = (try? JSONEncoder().encode(stations)) ?? Data()
        defaults.set(data, forKey: stationsKey)
    }
}
