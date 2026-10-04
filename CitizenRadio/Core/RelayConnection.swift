import Foundation

/// One open connection to a relay.
///
/// `NWCClient` sends and reads NIP-01 text messages through this protocol
/// only. ADR 0007 keeps the WebSocket code out of `CitizenRadioCore`, so
/// Linux tests can use a fake connection.
public protocol RelayConnection: Sendable {
    /// Sends one text message to the relay.
    func send(_ text: String) async throws

    /// Waits for the next text message from the relay.
    func receive() async throws -> String

    /// Closes the connection.
    ///
    /// A caller closes the connection on every path, also after an error.
    /// This method does not throw.
    func close() async
}

/// Opens a `RelayConnection` to a relay address.
public protocol RelayConnecting: Sendable {
    /// Opens a new connection to the relay at `url`.
    func connect(to url: URL) async throws -> any RelayConnection
}
