#if os(iOS)
import Foundation
#if SWIFT_PACKAGE
import RainbrookCore
#endif

/// Opens a relay connection with `URLSessionWebSocketTask`.
/// ADR 0007 §Connection test names this rule.
struct URLSessionRelayConnector: RelayConnecting {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(to url: URL) async throws -> any RelayConnection {
        let task = session.webSocketTask(with: url)
        task.resume()
        return URLSessionRelayConnection(task: task)
    }
}

/// One open WebSocket connection to a relay.
///
/// `NWCClient` cancels its Swift task after a timeout.
/// The async calls on `URLSessionWebSocketTask` do not stop on their own when Swift cancels the task.
/// So `send` and `receive` cancel the WebSocket task themselves.
final class URLSessionRelayConnection: RelayConnection, Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func send(_ text: String) async throws {
        try await withTaskCancellationHandler {
            try await task.send(.string(text))
        } onCancel: {
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    func receive() async throws -> String {
        let message = try await withTaskCancellationHandler {
            try await task.receive()
        } onCancel: {
            task.cancel(with: .goingAway, reason: nil)
        }
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw URLSessionRelayConnectionError.invalidTextEncoding
            }
            return text
        @unknown default:
            throw URLSessionRelayConnectionError.unknownMessageType
        }
    }

    func close() async {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

/// An error from `URLSessionRelayConnection`. It does not hold message text.
enum URLSessionRelayConnectionError: Error {
    /// A `.data` message did not hold UTF-8 text.
    case invalidTextEncoding
    /// The message was not `.string` or `.data`.
    case unknownMessageType
}
#endif
