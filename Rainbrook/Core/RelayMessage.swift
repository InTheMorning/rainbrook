import Foundation

/// A NIP-01 filter for a relay subscription.
///
/// A `nil` field means the filter does not restrict that part of the query.
/// Encoding omits a `nil` field.
public struct NostrFilter: Codable, Equatable, Sendable {
    public var kinds: [Int]?
    public var authors: [String]?
    public var eventReferences: [String]?
    public var limit: Int?

    private enum CodingKeys: String, CodingKey {
        case kinds
        case authors
        case eventReferences = "#e"
        case limit
    }

    public init(
        kinds: [Int]? = nil, authors: [String]? = nil, eventReferences: [String]? = nil, limit: Int? = nil
    ) {
        self.kinds = kinds
        self.authors = authors
        self.eventReferences = eventReferences
        self.limit = limit
    }
}

/// Builds the NIP-01 text messages that a client sends to a relay.
public enum ClientMessage {
    /// Builds `["EVENT",<event>]`.
    public static func event(_ event: NostrEvent) -> String {
        "[\"EVENT\"," + jsonText(event) + "]"
    }

    /// Builds `["REQ","<id>",<filter>]`.
    public static func request(subscriptionID: String, filter: NostrFilter) -> String {
        "[\"REQ\"," + jsonText(subscriptionID) + "," + jsonText(filter) + "]"
    }

    /// Builds `["CLOSE","<id>"]`.
    public static func close(subscriptionID: String) -> String {
        "[\"CLOSE\"," + jsonText(subscriptionID) + "]"
    }

    /// Encodes one value as compact JSON text.
    ///
    /// This gives `"null"` only on an encoding failure. A `String`, a
    /// `NostrEvent` and a `NostrFilter` always encode without error.
    private static func jsonText(_ value: some Encodable) -> String {
        guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return text
    }
}

/// A NIP-01 text message that a relay sends to a client.
public enum RelayMessage: Equatable, Sendable {
    case event(subscriptionID: String, event: NostrEvent)
    case ok(eventID: String, accepted: Bool, message: String)
    case endOfStoredEvents(subscriptionID: String)
    case notice(String)
    case closed(subscriptionID: String, message: String)

    /// An error in a relay message.
    ///
    /// No case carries a key, a plaintext or a decrypted value.
    public enum Error: Swift.Error, Equatable {
        /// The text is not a JSON array, or a known message type has the wrong shape.
        case malformed
        /// The first array item is a string, but it names no known message type.
        case unknownType(String)
    }

    /// Parses one relay text message.
    ///
    /// This initializer throws `Error.malformed` for text that is not a
    /// JSON array, or for a known message type with the wrong shape. It
    /// throws `Error.unknownType` for a message type NIP-01 does not define.
    public init(text: String) throws {
        guard let data = text.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let label = array.first as? String
        else {
            throw Error.malformed
        }

        switch label {
        case "EVENT":
            guard array.count == 3, let subscriptionID = array[1] as? String else {
                throw Error.malformed
            }
            guard JSONSerialization.isValidJSONObject(array[2]),
                  let eventData = try? JSONSerialization.data(withJSONObject: array[2]),
                  let event = try? JSONDecoder().decode(NostrEvent.self, from: eventData)
            else {
                throw Error.malformed
            }
            self = .event(subscriptionID: subscriptionID, event: event)
        case "OK":
            guard array.count == 4, let eventID = array[1] as? String,
                  let accepted = array[2] as? Bool, let message = array[3] as? String
            else {
                throw Error.malformed
            }
            self = .ok(eventID: eventID, accepted: accepted, message: message)
        case "EOSE":
            guard array.count == 2, let subscriptionID = array[1] as? String else {
                throw Error.malformed
            }
            self = .endOfStoredEvents(subscriptionID: subscriptionID)
        case "NOTICE":
            guard array.count == 2, let message = array[1] as? String else {
                throw Error.malformed
            }
            self = .notice(message)
        case "CLOSED":
            guard array.count == 3, let subscriptionID = array[1] as? String, let message = array[2] as? String
            else {
                throw Error.malformed
            }
            self = .closed(subscriptionID: subscriptionID, message: message)
        default:
            throw Error.unknownType(label)
        }
    }
}
