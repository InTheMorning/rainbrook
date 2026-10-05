import Foundation

/// A parsed server-sent event.
public struct ServerSentEvent: Equatable, Sendable {
    public let event: String
    public let id: String?
    public let data: String
}

/// Parses server-sent events in the WHATWG format.
public struct EventStreamParser: Sendable {
    private var eventName: String = "message"
    private var dataLines: [String] = []
    public private(set) var lastEventID: String?

    public init() {
    }

    /// Takes one line without its line terminator. Gives an event when the line is empty and data is present.
    public mutating func feed(line: String) -> ServerSentEvent? {
        // Comment line
        if line.hasPrefix(":") {
            return nil
        }

        // Empty line dispatches
        if line.isEmpty {
            if dataLines.isEmpty {
                return nil
            }
            let data = dataLines.joined(separator: "\n")
            let event = ServerSentEvent(event: eventName.isEmpty ? "message" : eventName, id: lastEventID, data: data)
            eventName = "message"
            dataLines.removeAll()
            return event
        }

        // Split at first colon
        if let colonIndex = line.firstIndex(of: ":") {
            let field = String(line[..<colonIndex])
            var value = String(line[line.index(after: colonIndex)...])

            // Remove one leading space if present
            if value.hasPrefix(" ") {
                value.removeFirst()
            }

            switch field {
            case "event":
                eventName = value
            case "data":
                dataLines.append(value)
            case "id":
                if !value.contains("\0") {
                    lastEventID = value
                }
            default:
                break
            }
        } else {
            // Line with no colon is a field with empty value
            let field = line
            switch field {
            case "event":
                eventName = ""
            case "data":
                dataLines.append("")
            default:
                break
            }
        }

        return nil
    }
}
