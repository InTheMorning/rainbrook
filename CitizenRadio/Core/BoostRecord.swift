import Foundation

/// The text items of a boost. An empty text is stored as nil.
/// ADR 0013 §The payment names the use of each item.
public struct BoostSender: Equatable, Sendable {
    /// The boost message. Nil when there is no message.
    public let message: String?
    /// The sender name. Nil when there is no sender name.
    public let senderName: String?
    /// The app name. It is never empty: an empty value gives `BoostSettings.defaultAppName`.
    public let appName: String

    public init(message: String?, senderName: String?, appName: String) {
        self.message = Self.text(message)
        self.senderName = Self.text(senderName)
        self.appName = Self.text(appName) ?? BoostSettings.defaultAppName
    }

    /// Reads BoostSettings: the message, the sender name and the app name.
    /// The init reads each value one time.
    public init(settings: BoostSettings) {
        self.init(message: settings.message, senderName: settings.senderName, appName: settings.appName)
    }

    /// Gives nil for nil, for an empty text and for a text with only white space.
    private static func text(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}

/// The action of a boost record. ADR 0023 §The boost record.
public enum BoostAction: String, Codable, Sendable {
    /// A manual boost.
    case boost
    /// An auto-boost.
    case auto
}

/// The data that is the same in each split of one boost. ADR 0023 §The boost record.
public struct BoostContext: Equatable, Sendable {
    public let action: BoostAction
    /// One UUID for each boost. Each split of the boost has the same value.
    public let uuid: UUID
    /// The station name. `podcast` uses it when the payload has no podcastName.
    public let stationName: String?

    public init(action: BoostAction, uuid: UUID, stationName: String?) {
        self.action = action
        self.uuid = uuid
        self.stationName = stationName
    }
}

/// The TLV records of a keysend boost part.
/// ADR 0013 §The payment and ADR 0023 §The boost record name the keys of the boost record.
public enum BoostRecord {
    public static let recordType: UInt64 = 7_629_169

    /// The boost record JSON, with sorted keys, in UTF-8.
    /// A key with no value is not in the JSON.
    public static func json(
        part: BoostPart, payload: LiveValuePayload, totalSats: Int, sender: BoostSender, context: BoostContext
    ) -> Data {
        var object: [String: Any] = [
            "action": context.action.rawValue,
            "uuid": context.uuid.uuidString.lowercased(),
            "app_name": sender.appName,
            "value_msat_total": Int64(totalSats) * 1000,
            "value_msat": Int64(part.sats) * 1000,
            "episode": payload.title,
            "event_guid": payload.eventGuid,
            "block_guid": payload.blockGuid
        ]
        if let name = part.destination.name {
            object["name"] = name
        }
        if let podcast = payload.podcastName ?? context.stationName, !podcast.isEmpty {
            object["podcast"] = podcast
        }
        if let feedGuid = payload.feedGuid {
            object["guid"] = feedGuid
        }
        if let itemGuid = payload.itemGuid {
            object["episode_guid"] = itemGuid
        }
        if let message = sender.message {
            object["message"] = message
        }
        if let senderName = sender.senderName {
            object["sender_name"] = senderName
        }
        // The object holds only strings and integers, so the serialization cannot fail.
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    /// The boost record, then the custom record if the destination has one.
    public static func tlvRecords(
        part: BoostPart, payload: LiveValuePayload, totalSats: Int, sender: BoostSender, context: BoostContext
    ) -> [TLVRecord] {
        let record = json(part: part, payload: payload, totalSats: totalSats, sender: sender, context: context)
        var records = [TLVRecord(type: recordType, value: hex(record))]
        if let key = part.destination.customKey,
           let value = part.destination.customValue,
           let type = UInt64(key) {
            records.append(TLVRecord(type: type, value: hex(Data(value.utf8))))
        }
        return records
    }

    /// The bytes as lowercase hexadecimal text.
    static func hex(_ data: Data) -> String {
        let digits = Array("0123456789abcdef")
        var text = ""
        text.reserveCapacity(data.count * 2)
        for byte in data {
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0f)])
        }
        return text
    }
}
