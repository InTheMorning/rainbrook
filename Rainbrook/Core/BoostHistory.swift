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

/// The reason of one failed part. ADR 0016 §The failure reason.
public enum BoostFailure: Codable, Equatable, Sendable {
    /// The wallet sent an error. The message has a maximum of 200 characters.
    case walletError(code: String, message: String)
    /// The wallet does not list the method.
    case unsupported
    /// The wallet answer was not valid.
    case invalidResponse
    /// The app sent no request for the part.
    case notSent
    /// An LNURL request or check failed.
    case lightningAddress

    /// The maximum number of characters of a wallet error message that the app keeps.
    public static let maximumMessageLength = 200

    /// True for walletError, notSent and lightningAddress.
    /// ADR 0016 §The retry names the retryable reasons.
    public var isRetryable: Bool {
        switch self {
        case .walletError, .notSent, .lightningAddress:
            return true
        case .unsupported, .invalidResponse:
            return false
        }
    }

    /// Maps one wallet outcome to its reason. Nil for .paid and .timeout.
    /// A wallet error keeps the first 200 characters of its message.
    public init?(_ outcome: NWCPaymentOutcome) {
        switch outcome {
        case .paid, .timeout:
            return nil
        case .unsupported:
            self = .unsupported
        case .walletError(let code, let message):
            self = .walletError(code: code, message: String(message.prefix(Self.maximumMessageLength)))
        case .invalidResponse:
            self = .invalidResponse
        case .notSent:
            self = .notSent
        }
    }
}

/// The data to send one part again. ADR 0016 §The retry.
public enum BoostRetryPayment: Codable, Equatable, Sendable {
    /// A keysend part. A retry sends the same TLV records.
    case keysend(pubkey: String, amountMsat: Int64, tlvRecords: [TLVRecord])
    /// A lightning address part. A retry does the keysend-first steps of ADR 0023 §A lightning address part again.
    ///
    /// `tlvRecords` holds the boost record. A keysend sends it again. `payerName` is the LUD-18 name of the invoice.
    /// The two keys are optional, because the history file of ADR 0016 does not have them.
    /// With no `tlvRecords`, the retry gets only a new invoice.
    case lightningAddress(
        name: String, host: String, amountMsat: Int64, comment: String,
        tlvRecords: [TLVRecord]? = nil, payerName: String? = nil
    )
}

/// The path that paid a lightning address part, or that failed last. ADR 0023 §A lightning address part.
public enum BoostPaymentPath: String, Codable, Sendable {
    case keysend, invoice
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
    /// The reason of the failure. Nil unless the result is failed.
    public let failure: BoostFailure?
    /// The data to send the part again.
    /// Not nil only when the result is failed and the failure is retryable.
    public let retry: BoostRetryPayment?
    /// The number of payments of this part. It is 1 after the first payment.
    public let attempts: Int
    /// The path that paid the part, or that failed last (ADR 0023). It is keysend for a keysend part.
    /// Nil for a lightning address part of a history file that has no path.
    public let path: BoostPaymentPath?

    /// True when the result is failed and the part has retry data.
    public var isRetryable: Bool { result == .failed && retry != nil }

    /// Removes a failure from a part that did not fail.
    /// Removes the retry data from a part that is not retryable (ADR 0016 §The retry).
    /// A keysend part always gets the path keysend (ADR 0023).
    public init(
        name: String?, kind: Kind, sats: Int, result: BoostPaymentResult,
        failure: BoostFailure? = nil, retry: BoostRetryPayment? = nil, attempts: Int = 1,
        path: BoostPaymentPath? = nil
    ) {
        let keptFailure = result == .failed ? failure : nil
        self.name = name
        self.kind = kind
        self.sats = sats
        self.result = result
        self.failure = keptFailure
        self.retry = keptFailure?.isRetryable == true ? retry : nil
        self.attempts = attempts
        self.path = kind == .keysend ? .keysend : path
    }

    /// Decodes a part result. The keys `failure`, `retry` and `attempts` are optional,
    /// because the history file of ADR 0013 does not have them. A missing `attempts` gives 1.
    /// The key `path` is optional, because the history file of ADR 0016 does not have it (ADR 0023).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decodeIfPresent(String.self, forKey: .name),
            kind: try container.decode(Kind.self, forKey: .kind),
            sats: try container.decode(Int.self, forKey: .sats),
            result: try container.decode(BoostPaymentResult.self, forKey: .result),
            failure: try container.decodeIfPresent(BoostFailure.self, forKey: .failure),
            retry: try container.decodeIfPresent(BoostRetryPayment.self, forKey: .retry),
            attempts: try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 1,
            path: try container.decodeIfPresent(BoostPaymentPath.self, forKey: .path)
        )
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

    /// True when one or more parts are retryable.
    public var hasRetryableParts: Bool {
        parts.contains { $0.isRetryable }
    }

    /// The sum of the sats of the retryable parts.
    public var retryableSats: Int {
        parts.filter(\.isRetryable).reduce(0) { $0 + $1.sats }
    }

    /// The same entry (id, date, kind, title, artist, amount, message) with new parts.
    public func replacingParts(_ parts: [BoostPartResult]) -> BoostHistoryEntry {
        BoostHistoryEntry(
            id: id, date: date, kind: kind, title: title, artist: artist,
            amountSats: amountSats, message: message, parts: parts
        )
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

    /// Replaces the entry with the same id, at the same position.
    /// When no entry has that id, the history does not change.
    public mutating func update(_ entry: BoostHistoryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
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
    /// Replaces the stored entry with the same id, and gives the new history.
    func update(_ entry: BoostHistoryEntry) async -> BoostHistory
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

    /// Loads the file, replaces the entry with the same id, and writes the file. Gives the new history.
    ///
    /// A write error does not throw, as in `add(_:)`.
    public func update(_ entry: BoostHistoryEntry) async -> BoostHistory {
        var history = await load()
        history.update(entry)
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

    /// The path text of a lightning address part: "Keysend" or "Invoice" (ADR 0023).
    /// Nil for a keysend part and for a part with no path.
    public static func path(for part: BoostPartResult) -> String? {
        guard part.kind == .lightningAddress else { return nil }
        switch part.path {
        case .keysend:
            return "Keysend"
        case .invoice:
            return "Invoice"
        case nil:
            return nil
        }
    }

    /// The text of the failure reason of one part. Nil when the part has no failure.
    /// ADR 0016 §The failure reason names the reasons.
    public static func reason(for part: BoostPartResult) -> String? {
        switch part.failure {
        case nil:
            return nil
        case .walletError(let code, let message):
            return "Wallet error \(code): \(message)"
        case .unsupported:
            return "The wallet does not support this payment."
        case .invalidResponse:
            return "The wallet answer was not valid."
        case .notSent:
            return "The payment was not sent."
        case .lightningAddress:
            return "The lightning address request failed."
        }
    }
}
