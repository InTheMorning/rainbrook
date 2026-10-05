import Foundation

/// Stores the relay event address, in UserDefaults.
public struct RelayEventStore {
    private let defaults: UserDefaults
    private let key = "citizenRadio.relayEventURI"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved text, or an empty text.
    public var savedText: String {
        defaults.string(forKey: key) ?? ""
    }

    /// The saved event, or nil when the text is empty or does not parse.
    public var event: RelayEvent? {
        try? RelayEvent(uri: savedText)
    }

    /// Empty text (after trim) clears the setting and gives nil.
    /// Other text must parse with RelayEvent. Else it throws RelayEvent.ParseError, and the setting does not change.
    @discardableResult
    public func save(_ text: String) throws -> RelayEvent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            defaults.removeObject(forKey: key)
            return nil
        }
        let event = try RelayEvent(uri: trimmed)
        defaults.set(trimmed, forKey: key)
        return event
    }
}
