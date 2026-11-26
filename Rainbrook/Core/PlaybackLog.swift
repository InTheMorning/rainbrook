import Foundation

/// The last playback events of the app, oldest first. ADR 0022 §The playback log owns these rules.
///
/// The log keeps a maximum of `capacity` entries. Each entry has a time and one line of text.
/// The text contains no wallet data, no key and no boost message.
public struct PlaybackLog: Equatable, Sendable {
    /// The maximum number of entries.
    public static let capacity = 500

    /// One playback event: the time and one line of text.
    public struct Entry: Codable, Equatable, Sendable {
        public let date: Date
        public let text: String

        public init(date: Date, text: String) {
            self.date = date
            self.text = text
        }
    }

    /// The entries, oldest first.
    public private(set) var entries: [Entry]

    /// Keeps the last `capacity` entries.
    public init(entries: [Entry] = []) {
        self.entries = Array(entries.suffix(Self.capacity))
    }

    /// Adds the entry at the end. When the log has more than `capacity` entries, it removes the oldest.
    public mutating func add(_ entry: Entry) {
        entries.append(entry)
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    /// Removes all entries.
    public mutating func clear() {
        entries.removeAll()
    }

    /// One line for each entry: ISO 8601 time with milliseconds, a space, the text.
    public func text() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return entries
            .map { "\(formatter.string(from: $0.date)) \($0.text)" }
            .joined(separator: "\n")
    }

    /// Encodes the entries as JSON.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(entries)
    }

    /// Decodes a log from the JSON of `encoded()`. The log keeps the last `capacity` entries.
    public static func decode(_ data: Data) throws -> PlaybackLog {
        PlaybackLog(entries: try JSONDecoder().decode([Entry].self, from: data))
    }
}
