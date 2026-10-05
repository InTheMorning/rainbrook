import Foundation

/// The user texts for the Wallet section of Settings.
/// ADR 0007 §Settings and §Connection test name these texts.
public enum WalletStatusText {
    /// The text for a correct connection test.
    public static func connected(_ info: WalletInfo) -> String {
        let greeting: String
        if let alias = info.alias {
            greeting = "Connected to \(alias)."
        } else {
            greeting = "Connected to the wallet."
        }
        return "\(greeting) \(info.methods.count) methods available."
    }

    /// The keysend warning for the wallet. Returns nil if the wallet supports keysend.
    public static func keysendWarning(_ info: WalletInfo) -> String? {
        guard !info.supportsKeysend else { return nil }
        return "This wallet does not support keysend. Streaming payments need keysend."
    }

    /// The text for a Keychain error when the app reads, saves or removes the connection.
    public static let storageFailure = "CitizenRadio cannot access the wallet connection in the Keychain."

    /// The text for an error during paste or during the connection test.
    public static func failure(_ error: any Error) -> String {
        if let parseError = error as? NWCConnection.ParseError {
            return parseError.errorDescription ?? "This is not a Nostr Wallet Connect link."
        }
        if let clientError = error as? NWCClient.Error {
            return text(for: clientError)
        }
        return "CitizenRadio cannot connect to the relay."
    }

    private static func text(for error: NWCClient.Error) -> String {
        switch error {
        case .noInfoEvent:
            return "The wallet did not publish its information. Examine the connection in your wallet."
        case .unsupportedEncryption:
            return "The wallet uses an encryption that CitizenRadio does not support."
        case .relayRejected:
            return "The relay did not accept the request."
        case .walletError(let code, _):
            return "The wallet returned the error \(code)."
        case .invalidResponse:
            return "CitizenRadio cannot read the response of the wallet."
        case .timeout:
            return "The wallet did not answer in 10 seconds."
        }
    }
}
