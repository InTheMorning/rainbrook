import Foundation

/// One destination that the app may pay from a live value payload.
/// ADR 0012 §Payable destinations names the rules this type enforces.
public struct LiveValueDestination: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// A keysend destination. The pubkey is 66 lowercase hex characters.
        case node(pubkey: String)
        /// A lightning address destination. The name and the host are lowercase.
        case lightningAddress(name: String, host: String)
    }

    public let kind: Kind
    public let name: String?
    public let split: Double
    public let fee: Bool
    public let customKey: String?
    public let customValue: String?

    public init(
        kind: Kind, name: String?, split: Double, fee: Bool,
        customKey: String?, customValue: String?
    ) {
        self.kind = kind
        self.name = name
        self.split = split
        self.fee = fee
        self.customKey = customKey
        self.customValue = customValue
    }
}

/// A live value payload from the relay. ADR 0012 names its payable destinations.
public struct LiveValuePayload: Equatable, Sendable {
    /// The title of the placeholder payload between V4V tracks.
    public static let placeholderTitle = "No V4V track playing"

    public let title: String
    public let eventGuid: String
    public let blockGuid: String
    public let feedGuid: String?
    public let itemGuid: String?
    /// Only the payable destinations, in payload order.
    public let destinations: [LiveValueDestination]
    /// The podcast name of the payload. Nil when the payload has no non-empty `podcastName` text.
    /// ADR 0023 §The boost record uses it for the `podcast` key.
    public let podcastName: String?

    /// False for the default dead block title, and when no destination is payable.
    /// ADR 0026: the reserved host of the dead block gives no destination. That rule excludes the dead block
    /// for each title, also for a title that the station sets.
    public var isPayable: Bool {
        title != Self.placeholderTitle && !destinations.isEmpty
    }

    public enum DecodeError: Error, Equatable {
        case invalid
    }

    /// Decodes a relay live value payload. Gives nil for {}.
    /// Throws DecodeError.invalid for data that is not a JSON object,
    /// or for a missing or empty title, eventGuid or blockGuid.
    public static func decode(_ data: Data) throws -> LiveValuePayload? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let dict = json as? [String: Any] else {
            throw DecodeError.invalid
        }
        return try decode(object: dict)
    }

    /// Decodes the body of GET /metadata: reads the "metadata" object and gives it to decode(_:).
    /// Throws DecodeError.invalid when the body is not an object or has no "metadata" object.
    /// ADR 0018 §The value snapshot names this body.
    public static func decodeMetadataSnapshot(_ data: Data) throws -> LiveValuePayload? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let body = json as? [String: Any],
              let metadata = body["metadata"] as? [String: Any] else {
            throw DecodeError.invalid
        }
        return try decode(object: metadata)
    }

    /// Decodes one payload object. `decode(_:)` names the rules.
    private static func decode(object dict: [String: Any]) throws -> LiveValuePayload? {
        if dict.isEmpty {
            return nil
        }

        guard let title = dict["title"] as? String, !title.isEmpty,
              let eventGuid = dict["eventGuid"] as? String, !eventGuid.isEmpty,
              let blockGuid = dict["blockGuid"] as? String, !blockGuid.isEmpty else {
            throw DecodeError.invalid
        }

        let feedGuid = dict["feedGuid"] as? String
        let itemGuid = dict["itemGuid"] as? String
        var podcastName: String?
        if let text = dict["podcastName"] as? String, !text.isEmpty {
            podcastName = text
        }

        var destinations: [LiveValueDestination] = []
        if let value = dict["value"] as? [String: Any],
           let rawDestinations = value["destinations"] as? [[String: Any]] {
            destinations = rawDestinations.compactMap(Self.destination(from:))
        }

        return LiveValuePayload(
            title: title,
            eventGuid: eventGuid,
            blockGuid: blockGuid,
            feedGuid: feedGuid,
            itemGuid: itemGuid,
            destinations: destinations,
            podcastName: podcastName
        )
    }

    /// Reads one destination. Gives nil when the destination is not payable.
    private static func destination(from raw: [String: Any]) -> LiveValueDestination? {
        guard let type = raw["type"] as? String,
              let rawAddress = raw["address"] as? String else {
            return nil
        }
        let address = rawAddress.lowercased()

        let kind: LiveValueDestination.Kind
        switch type {
        case "node":
            guard address.count == 66, address.unicodeScalars.allSatisfy(Self.isHexDigit) else {
                return nil
            }
            kind = .node(pubkey: address)
        case "lnaddress":
            let parts = address.components(separatedBy: "@")
            guard parts.count == 2, !parts[0].isEmpty, Self.isPayableHost(parts[1]) else {
                return nil
            }
            kind = .lightningAddress(name: parts[0], host: parts[1])
        default:
            return nil
        }

        guard let split = Self.split(from: raw["split"]), split.isFinite, split > 0 else {
            return nil
        }

        let fee = isJSONBoolean(raw["fee"]) && (raw["fee"] as? Bool) == true
        let name = raw["name"] as? String
        let customKey = raw["customKey"] as? String
        let customValue = raw["customValue"] as? String

        return LiveValueDestination(
            kind: kind, name: name, split: split, fee: fee,
            customKey: customKey, customValue: customValue
        )
    }

    /// True for a lowercase or uppercase hex digit.
    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 48 && scalar.value <= 57) || // 0-9
            (scalar.value >= 97 && scalar.value <= 102) // a-f
    }

    /// True only for a JSON `true` or `false`.
    ///
    /// `JSONSerialization` gives an `NSNumber` for a number and for a boolean, on Apple platforms
    /// and on Linux. An `NSNumber` with the value 0 or 1 also matches `is Bool`, so that test is
    /// not correct here. A JSON boolean has the type code `c`, and a JSON number never has it.
    private static func isJSONBoolean(_ raw: Any?) -> Bool {
        guard let number = raw as? NSNumber else { return false }
        return String(cString: number.objCType) == "c"
    }

    /// Reads a split value from a JSON string or number. Gives nil for any other shape.
    private static func split(from raw: Any?) -> Double? {
        guard let raw else {
            return nil
        }
        // A JSON boolean also casts to NSNumber, so reject it here.
        if isJSONBoolean(raw) {
            return nil
        }
        if let number = raw as? NSNumber {
            return number.doubleValue
        }
        if let text = raw as? String {
            return Double(text)
        }
        return nil
    }

    /// True for a host the app may pay. ADR 0012 §Payable destinations names the reserved hosts.
    private static func isPayableHost(_ host: String) -> Bool {
        guard host.contains(".") else {
            return false
        }

        let reservedHosts: Set<String> = ["example.com", "example.net", "example.org"]
        if reservedHosts.contains(host) {
            return false
        }

        let reservedSuffixes = [".invalid", ".example", ".test", ".localhost"]
        return !reservedSuffixes.contains { host.hasSuffix($0) }
    }
}
