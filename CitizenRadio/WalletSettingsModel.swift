#if os(iOS)
import Combine
import Foundation
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// The view model for the Wallet section of Settings.
///
/// ADR 0007 §Settings names this section. The state never holds the secret,
/// the URI or decrypted wallet content. `WalletStore` and `NWCClient` do the
/// Keychain and network work, off the main thread.
@MainActor
final class WalletSettingsModel: ObservableObject {
    enum State: Equatable {
        case loading
        case notConnected(message: String?)
        case connected(WalletSummary, status: String?, warning: String?, isTesting: Bool)
    }

    @Published private(set) var state: State = .loading

    private let store: WalletStore
    private let connector: any RelayConnecting

    init(
        store: WalletStore = WalletStore(secrets: KeychainSecretStore()),
        connector: any RelayConnecting = URLSessionRelayConnector()
    ) {
        self.store = store
        self.connector = connector
    }

    /// Loads the stored connection, if the app has one.
    func load() async {
        do {
            guard let connection = try await store.connection() else {
                state = .notConnected(message: nil)
                return
            }
            state = .connected(WalletSummary(connection), status: nil, warning: nil, isTesting: false)
        } catch {
            state = .notConnected(message: WalletStatusText.failure(error))
        }
    }

    /// Parses and saves a pasted connection URI.
    /// A missing or empty text leaves the state as it is.
    func connect(text: String?) async {
        guard let text, !text.isEmpty else { return }
        do {
            let connection = try NWCConnection(uri: text)
            try await store.save(connection)
            state = .connected(WalletSummary(connection), status: nil, warning: nil, isTesting: false)
        } catch {
            state = .notConnected(message: WalletStatusText.failure(error))
        }
    }

    /// Sends a `get_info` request to the connected wallet, and shows the result.
    func test() async {
        guard case .connected(let summary, _, let warning, false) = state else { return }
        state = .connected(summary, status: nil, warning: warning, isTesting: true)
        do {
            guard let connection = try await store.connection() else {
                state = .notConnected(message: nil)
                return
            }
            let info = try await NWCClient(connection: connection, connector: connector).getInfo()
            state = .connected(
                WalletSummary(connection),
                status: WalletStatusText.connected(info),
                warning: WalletStatusText.keysendWarning(info),
                isTesting: false
            )
        } catch {
            state = .connected(summary, status: WalletStatusText.failure(error), warning: warning, isTesting: false)
        }
    }

    /// Removes the stored connection.
    func disconnect() async {
        do {
            try await store.remove()
            state = .notConnected(message: nil)
        } catch {
            if case .connected(let summary, _, let warning, _) = state {
                state = .connected(summary, status: WalletStatusText.failure(error), warning: warning, isTesting: false)
            }
        }
    }
}
#endif
