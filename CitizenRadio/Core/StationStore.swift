import Foundation

/// Stores the list of stations and the selected station, in UserDefaults.
/// ADR 0017 §The station and §The first start after the update.
public struct StationStore {
    /// The highest number of stations the list keeps.
    public static let maximumCount = 20

    private static let stationsKey = "citizenRadio.stations"
    private static let selectedIDKey = "citizenRadio.selectedStationID"
    private static let oldStreamURLKey = "citizenRadio.streamURL"
    private static let oldRelayEventURIKey = "citizenRadio.relayEventURI"

    private let defaults: UserDefaults

    /// Runs the first-start rule of ADR 0017 one time.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.stationsKey) == nil {
            Self.runFirstStart(defaults: defaults)
        }
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

    /// ADR 0017 §The first start after the update.
    ///
    /// This rule runs one time, only while the stations key is missing. It reads
    /// the old stream URL and the old live value address, makes one station from
    /// them, and removes the two old keys.
    private static func runFirstStart(defaults: UserDefaults) {
        defer {
            defaults.removeObject(forKey: oldStreamURLKey)
            defaults.removeObject(forKey: oldRelayEventURIKey)
        }

        let oldStreamText = defaults.string(forKey: oldStreamURLKey) ?? ""
        let oldRelayText = defaults.string(forKey: oldRelayEventURIKey) ?? ""
        // The old relay text becomes the live value address only when it still parses.
        let trackInfoText = (try? RelayEvent(uri: oldRelayText)) != nil ? oldRelayText : ""

        guard let station = try? Station(
            name: "",
            streamText: oldStreamText,
            alternateStreamText: "",
            trackInfoText: trackInfoText
        ) else {
            save([], defaults: defaults)
            return
        }

        save([station], defaults: defaults)
        defaults.set(station.id.uuidString, forKey: selectedIDKey)
    }
}
