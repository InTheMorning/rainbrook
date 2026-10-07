import Foundation

/// The result of one payment of a boost part.
///
/// ADR 0013 §The history names the three results.
public enum BoostPaymentResult: String, Codable, Equatable, Sendable {
    case confirmed, failed, unknown

    /// Maps one wallet outcome to its result.
    /// A `.paid` outcome gives confirmed. A `.timeout` outcome gives unknown.
    /// Each other outcome gives failed.
    public init(_ outcome: NWCPaymentOutcome) {
        switch outcome {
        case .paid:
            self = .confirmed
        case .timeout:
            self = .unknown
        case .unsupported, .walletError, .invalidResponse, .notSent:
            self = .failed
        }
    }
}

/// The result of one part of a boost.
public struct BoostPartResult: Codable, Equatable, Sendable {
    /// A part pays a keysend destination or a lightning address.
    public enum Kind: String, Codable, Sendable { case keysend, lightningAddress }

    /// The recipient name. Nil when the part has no name.
    public let name: String?
    public let kind: Kind
    public let sats: Int
    public let result: BoostPaymentResult

    public init(name: String?, kind: Kind, sats: Int, result: BoostPaymentResult) {
        self.name = name
        self.kind = kind
        self.sats = sats
        self.result = result
    }
}

/// One entry of the boost history.
///
/// ADR 0013 §The history names the stored fields.
public struct BoostHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    /// Auto marks a boost that the trigger sent. Manual marks a boost that the listener sent.
    public enum Kind: String, Codable, Sendable { case auto, manual }

    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let title: String
    public let artist: String?
    public let amountSats: Int
    public let message: String?
    public let parts: [BoostPartResult]

    public init(
        id: UUID = UUID(), date: Date, kind: Kind, title: String, artist: String?,
        amountSats: Int, message: String?, parts: [BoostPartResult]
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.artist = artist
        self.amountSats = amountSats
        self.message = message
        self.parts = parts
    }

    /// The sum of the sats of the parts with the result confirmed.
    public var confirmedSats: Int {
        parts.filter { $0.result == .confirmed }.reduce(0) { $0 + $1.sats }
    }
}

/// The last 200 boosts, newest first.
///
/// ADR 0013 §The history owns this list and its file store.
public struct BoostHistory: Equatable, Sendable {
    /// The maximum number of entries that the history keeps.
    public static let capacity = 200

    public private(set) var entries: [BoostHistoryEntry]

    /// Keeps only the first `capacity` entries of the given list.
    public init(entries: [BoostHistoryEntry] = []) {
        self.entries = Array(entries.prefix(Self.capacity))
    }

    /// Inserts the entry first, then keeps the first `capacity` entries.
    public mutating func add(_ entry: BoostHistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.capacity {
            entries.removeLast(entries.count - Self.capacity)
        }
    }

    /// Encodes the entries as JSON, with ISO 8601 dates.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    /// Decodes a history from JSON that `encoded()` wrote.
    public static func decode(_ data: Data) throws -> BoostHistory {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([BoostHistoryEntry].self, from: data)
        return BoostHistory(entries: entries)
    }
}

/// A store for the boost history.
public protocol BoostHistoryStoring: Sendable {
    /// Loads the stored history. A missing file or a bad file gives an empty history.
    func load() async -> BoostHistory
    /// Adds the entry to the stored history, and gives the new history.
    func add(_ entry: BoostHistoryEntry) async -> BoostHistory
}

/// Stores the boost history in a file. ADR 0013 §The history names this store.
///
/// The app keeps the file in its Application Support folder, off the main actor (ADR 0006).
public actor BoostHistoryFileStore: BoostHistoryStoring {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Loads the stored history. A missing file or a bad file gives an empty history.
    public func load() async -> BoostHistory {
        guard let data = try? Data(contentsOf: fileURL) else { return BoostHistory() }
        return (try? BoostHistory.decode(data)) ?? BoostHistory()
    }

    /// Loads the file, adds the entry, and writes the file. Gives the new history.
    ///
    /// A write error does not throw. A history problem does not stop a payment.
    /// This method gives the result in memory. The write can fail, and the result stays correct.
    public func add(_ entry: BoostHistoryEntry) async -> BoostHistory {
        var history = await load()
        history.add(entry)
        write(history)
        return history
    }

    /// Writes the history to the file, as one atomic write.
    /// Creates the folder of the file when the folder is missing.
    /// Ignores a write error.
    private func write(_ history: BoostHistory) {
        guard let data = try? history.encoded() else { return }
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// The user texts for one boost history entry.
public enum BoostHistoryText {
    /// The summary text of an entry.
    ///
    /// For example "Confirmed 99 of 100 sats." or "Failed. No payment was confirmed."
    public static func summary(for entry: BoostHistoryEntry) -> String {
        let confirmedCount = entry.parts.filter { $0.result == .confirmed }.count
        let unknownCount = entry.parts.filter { $0.result == .unknown }.count
        let failedCount = entry.parts.filter { $0.result == .failed }.count

        if confirmedCount > 0 {
            var text = "Confirmed \(entry.confirmedSats) of \(entry.amountSats) sats."
            if unknownCount > 0 { text += " \(unknownCount) unknown." }
            if failedCount > 0 { text += " \(failedCount) failed." }
            return text
        }
        if unknownCount > 0 {
            var text = "Not known. \(unknownCount) payments have no result."
            if failedCount > 0 { text += " \(failedCount) failed." }
            return text
        }
        return "Failed. No payment was confirmed."
    }

    /// The label of one payment result: "Confirmed", "Failed" or "Unknown".
    public static func label(for result: BoostPaymentResult) -> String {
        switch result {
        case .confirmed:
            return "Confirmed"
        case .failed:
            return "Failed"
        case .unknown:
            return "Unknown"
        }
    }
}
