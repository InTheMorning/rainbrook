import Foundation

/// The TLV records of a keysend boost part.
/// ADR 0012 §The payment names the keys of the boost record.
public enum BoostRecord {
    public static let recordType: UInt64 = 7_629_169
    public static let appName = "CitizenRadio"

    /// The boost record JSON, with sorted keys, in UTF-8.
    public static func json(part: BoostPart, payload: LiveValuePayload, totalSats: Int) -> Data {
        var object: [String: Any] = [
            "action": "boost",
            "app_name": appName,
            "value_msat_total": Int64(totalSats) * 1000,
            "value_msat": Int64(part.sats) * 1000,
            "episode": payload.title,
            "event_guid": payload.eventGuid,
            "block_guid": payload.blockGuid
        ]
        if let name = part.destination.name {
            object["name"] = name
        }
        if let feedGuid = payload.feedGuid {
            object["guid"] = feedGuid
        }
        if let itemGuid = payload.itemGuid {
            object["episode_guid"] = itemGuid
        }
        // The object holds only strings and integers, so the serialization cannot fail.
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    /// The boost record, then the custom record if the destination has one.
    public static func tlvRecords(part: BoostPart, payload: LiveValuePayload, totalSats: Int) -> [TLVRecord] {
        var records = [
            TLVRecord(type: recordType, value: hex(json(part: part, payload: payload, totalSats: totalSats)))
        ]
        if let key = part.destination.customKey,
           let value = part.destination.customValue,
           let type = UInt64(key) {
            records.append(TLVRecord(type: type, value: hex(Data(value.utf8))))
        }
        return records
    }

    /// The bytes as lowercase hexadecimal text.
    private static func hex(_ data: Data) -> String {
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
