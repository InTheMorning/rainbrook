import Foundation

/// The values that the settings sheet shows for a connected wallet.
/// ADR 0007 §Settings names these fields. The summary never holds the secret.
public struct WalletSummary: Equatable, Sendable {
    public let relayHost: String
    public let walletKeyPrefix: String
    public let lud16: String?

    public init(_ connection: NWCConnection) {
        relayHost = connection.relays.first?.host ?? ""
        walletKeyPrefix = String(connection.walletPublicKey.prefix(8))
        lud16 = connection.lud16
    }
}
