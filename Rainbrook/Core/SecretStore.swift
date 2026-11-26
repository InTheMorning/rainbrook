import Foundation

/// A store for one secret text value.
/// ADR 0007 §Module boundaries names this protocol. The app target supplies the Keychain version.
public protocol SecretStore: Sendable {
    /// Reads the stored value. Returns nil if nothing is stored.
    func read() async throws -> String?
    /// Stores the value. Each write replaces the stored value.
    func write(_ value: String) async throws
    /// Removes the stored value. This call succeeds if nothing is stored.
    func delete() async throws
}

/// Stores and reads the wallet connection, through a `SecretStore`.
public struct WalletStore: Sendable {
    private let secrets: any SecretStore

    public init(secrets: any SecretStore) {
        self.secrets = secrets
    }

    /// Reads the stored connection.
    /// Returns nil if nothing is stored, or if the stored value does not parse.
    public func connection() async throws -> NWCConnection? {
        guard let value = try await secrets.read() else { return nil }
        return try? NWCConnection(uri: value)
    }

    /// Stores the connection URI.
    public func save(_ connection: NWCConnection) async throws {
        try await secrets.write(connection.uri)
    }

    /// Removes the stored connection.
    public func remove() async throws {
        try await secrets.delete()
    }
}
