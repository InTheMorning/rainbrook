import Foundation

/// A parsed and validated relay event URI.
/// ADR 0008 names the fields that this type must validate and store.
public struct RelayEvent: Equatable, Sendable {
    public enum ParseError: Error, Equatable, LocalizedError {
        case scheme, path, eventID

        public var errorDescription: String? {
            switch self {
            case .scheme:
                return "The track info address must start with https."
            case .path:
                return "This is not a relay event address."
            case .eventID:
                return "The relay event identifier is not correct."
            }
        }
    }

    public let origin: URL
    public let eventID: String

    public init(uri: String) throws {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https" else {
            throw ParseError.scheme
        }

        var pathAndID: (path: String, eventID: String)?

        // Try /v1/liveitems/<id> form first
        let path = components.path
        if !path.isEmpty {
            let normalized = path.hasSuffix("/") ? String(path.dropLast()) : path
            if normalized.hasPrefix("/v1/liveitems/") {
                let idPart = String(normalized.dropFirst("/v1/liveitems/".count))
                if !idPart.isEmpty && components.query == nil {
                    pathAndID = ("/v1/liveitems/", idPart)
                }
            }
        }

        // Try /event form with event_id query parameter
        if pathAndID == nil {
            if path == "/event" {
                let queryItems = components.queryItems ?? []
                if let eventItem = queryItems.first(where: { $0.name == "event_id" }),
                   let eventValue = eventItem.value, !eventValue.isEmpty {
                    pathAndID = ("/event", eventValue)
                }
            }
        }

        guard let (_, idString) = pathAndID, let host = components.host, !host.isEmpty else {
            throw ParseError.path
        }

        // Validate event ID: 1-128 characters from A-Z, a-z, 0-9, -, _
        let allowedChars = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        guard idString.count > 0 && idString.count <= 128,
              idString.unicodeScalars.allSatisfy(allowedChars.contains) else {
            throw ParseError.eventID
        }

        // Construct origin URL with host and port only
        var originComponents = URLComponents()
        originComponents.scheme = "https"
        originComponents.host = host
        originComponents.port = components.port

        guard let originURL = originComponents.url else {
            throw ParseError.path
        }

        self.origin = originURL
        self.eventID = idString
    }

    public var displayURL: URL {
        origin.appending(path: "/v1/liveitems/\(eventID)/display")
    }

    public var displayEventsURL: URL {
        origin.appending(path: "/v1/liveitems/\(eventID)/display/events")
    }

    /// GET /v1/liveitems/{event_id}/metadata. ADR 0018 §The value snapshot.
    public var metadataURL: URL {
        origin.appending(path: "/v1/liveitems/\(eventID)/metadata")
    }

    public var valueEventsURL: URL {
        origin.appending(path: "/v1/liveitems/\(eventID)/events")
    }

    public func artworkURL(sha256: String) -> URL {
        origin.appending(path: "/v1/liveitems/\(eventID)/artwork/\(sha256)")
    }
}
