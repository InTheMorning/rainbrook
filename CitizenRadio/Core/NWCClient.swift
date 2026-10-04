import Foundation

/// The wallet facts that a NIP-47 `get_info` request returns.
public struct WalletInfo: Equatable, Sendable {
    public let alias: String?
    public let methods: [String]
    public let encryption: String
    public var supportsKeysend: Bool { methods.contains("pay_keysend") }
}

/// A Nostr Wallet Connect (NIP-47) client over a relay.
///
/// `NWCClient` depends only on `Foundation`, `NWCConnection` and
/// `RelayConnecting`. It does not import Security, and it does not use
/// `URLSession`. ADR 0007 §Module boundaries names this rule.
public actor NWCClient {
    public enum Error: Swift.Error, Equatable {
        case noInfoEvent
        case unsupportedEncryption
        case relayRejected(String)
        case walletError(code: String, message: String)
        case invalidResponse
        case timeout
    }

    /// The encryption that a wallet can use for a request.
    private enum Encryption: String {
        case nip44 = "nip44_v2"
        case nip04 = "nip04"
    }

    /// The facts from the info event, before the signed request.
    private struct WalletInfoEvent {
        let methods: [String]
        let encryption: Encryption
    }

    private let connection: NWCConnection
    private let connector: any RelayConnecting
    private let timeout: Duration

    public init(connection: NWCConnection, connector: any RelayConnecting, timeout: Duration = .seconds(10)) {
        self.connection = connection
        self.connector = connector
        self.timeout = timeout
    }

    /// Asks the wallet for its alias, its methods and its preferred encryption.
    ///
    /// This method follows the NIP-47 `get_info` sequence. ADR 0007 §Connection
    /// test names this sequence. The complete sequence has the time limit
    /// `timeout`. After that limit, this method throws `Error.timeout`.
    public func getInfo() async throws -> WalletInfo {
        try await withThrowingTaskGroup(of: WalletInfo.self) { group in
            group.addTask { try await self.runGetInfo() }
            group.addTask {
                try await Task.sleep(for: self.timeout)
                throw Error.timeout
            }
            guard let result = try await group.next() else {
                throw Error.timeout
            }
            group.cancelAll()
            return result
        }
    }

    /// Runs the complete `get_info` sequence over one relay connection.
    ///
    /// This method closes the connection on every path, also after an error.
    private func runGetInfo() async throws -> WalletInfo {
        let relayConnection = try await connector.connect(to: connection.relays[0])
        do {
            let result = try await exchangeWithWallet(over: relayConnection)
            await relayConnection.close()
            return result
        } catch {
            await relayConnection.close()
            throw error
        }
    }

    /// Reads the info event, then sends and reads the signed request.
    private func exchangeWithWallet(over relayConnection: any RelayConnection) async throws -> WalletInfo {
        let info = try await readWalletInfo(over: relayConnection)
        return try await requestGetInfo(over: relayConnection, info: info)
    }

    // MARK: - Steps 1 and 2: the info event

    /// Reads the wallet methods and the preferred encryption from the kind 13194 info event.
    private func readWalletInfo(over relayConnection: any RelayConnection) async throws -> WalletInfoEvent {
        let subscriptionID = Self.randomSubscriptionID()
        let filter = NostrFilter(kinds: [13194], authors: [connection.walletPublicKey], limit: 1)
        try await relayConnection.send(ClientMessage.request(subscriptionID: subscriptionID, filter: filter))

        var infoEvent: NostrEvent?
        readLoop: while true {
            let text = try await relayConnection.receive()
            guard let message = try? RelayMessage(text: text) else { continue }
            switch message {
            case .event(let sid, let event):
                guard sid == subscriptionID else { continue }
                // A relay can send a forged event. Accept the first valid one only.
                if infoEvent == nil, event.isValid(), event.pubkey == connection.walletPublicKey {
                    infoEvent = event
                }
            case .endOfStoredEvents(let sid):
                if sid == subscriptionID { break readLoop }
            default:
                continue
            }
        }
        try await relayConnection.send(ClientMessage.close(subscriptionID: subscriptionID))

        guard let infoEvent else { throw Error.noInfoEvent }
        let methods = infoEvent.content.split(separator: " ").map(String.init)
        let listed = encryptionNames(in: infoEvent.tags)
        if listed.contains(Encryption.nip44.rawValue) {
            return WalletInfoEvent(methods: methods, encryption: .nip44)
        }
        if listed.contains(Encryption.nip04.rawValue) {
            return WalletInfoEvent(methods: methods, encryption: .nip04)
        }
        throw Error.unsupportedEncryption
    }

    /// The encryption names from the event's `encryption` tag.
    ///
    /// Without that tag, the wallet supports only `nip04`.
    private func encryptionNames(in tags: [[String]]) -> [String] {
        guard let tag = tags.first(where: { $0.first == "encryption" }), tag.count >= 2 else {
            return [Encryption.nip04.rawValue]
        }
        return tag[1].split(separator: " ").map(String.init)
    }

    // MARK: - Steps 3, 4 and 5: the signed request

    /// Sends the signed `get_info` request event and reads the wallet's response.
    private func requestGetInfo(over relayConnection: any RelayConnection, info: WalletInfoEvent) async throws -> WalletInfo {
        let plainContent = "{\"method\":\"get_info\",\"params\":{}}"
        let requestContent = try encrypt(plainContent, using: info.encryption)
        var tags = [["p", connection.walletPublicKey]]
        if info.encryption == .nip44 {
            tags.append(["encryption", Encryption.nip44.rawValue])
        }
        let requestEvent = try NostrEvent.signed(
            kind: 23194, tags: tags, content: requestContent,
            createdAt: Int(Date().timeIntervalSince1970), secretKey: connection.secret
        )

        let subscriptionID = Self.randomSubscriptionID()
        let filter = NostrFilter(
            kinds: [23195], authors: [connection.walletPublicKey], eventReferences: [requestEvent.id]
        )
        try await relayConnection.send(ClientMessage.request(subscriptionID: subscriptionID, filter: filter))
        try await relayConnection.send(ClientMessage.event(requestEvent))

        while true {
            let text = try await relayConnection.receive()
            guard let message = try? RelayMessage(text: text) else { continue }
            switch message {
            case .ok(let eventID, let accepted, let okMessage):
                guard eventID == requestEvent.id, !accepted else { continue }
                throw Error.relayRejected(okMessage)
            case .event(let sid, let event):
                guard sid == subscriptionID else { continue }
                // A relay can send a forged event. Ignore any event that fails this check.
                guard event.isValid(), event.pubkey == connection.walletPublicKey else { continue }
                return try decodeResponse(event, info: info)
            default:
                continue
            }
        }
    }

    /// Decrypts and decodes the wallet's response event.
    private func decodeResponse(_ event: NostrEvent, info: WalletInfoEvent) throws -> WalletInfo {
        let plaintext: String
        do {
            plaintext = try decrypt(event.content, using: info.encryption)
        } catch {
            throw Error.invalidResponse
        }
        guard let data = plaintext.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw Error.invalidResponse
        }
        if let errorObject = object["error"] as? [String: Any] {
            let code = errorObject["code"] as? String ?? ""
            let message = errorObject["message"] as? String ?? ""
            throw Error.walletError(code: code, message: message)
        }
        guard let result = object["result"] as? [String: Any] else {
            throw Error.invalidResponse
        }
        let alias = result["alias"] as? String
        let methods = (result["methods"] as? [String]) ?? info.methods
        return WalletInfo(alias: alias, methods: methods, encryption: info.encryption.rawValue)
    }

    // MARK: - Encryption

    private func encrypt(_ plaintext: String, using encryption: Encryption) throws -> String {
        switch encryption {
        case .nip44:
            let key = try NIP44.conversationKey(secretKey: connection.secret, publicKey: connection.walletPublicKey)
            return try NIP44.encrypt(plaintext, conversationKey: key)
        case .nip04:
            return try NIP04.encrypt(plaintext, secretKey: connection.secret, publicKey: connection.walletPublicKey)
        }
    }

    private func decrypt(_ payload: String, using encryption: Encryption) throws -> String {
        switch encryption {
        case .nip44:
            let key = try NIP44.conversationKey(secretKey: connection.secret, publicKey: connection.walletPublicKey)
            return try NIP44.decrypt(payload, conversationKey: key)
        case .nip04:
            return try NIP04.decrypt(payload, secretKey: connection.secret, publicKey: connection.walletPublicKey)
        }
    }

    // MARK: - Subscription IDs

    /// A random subscription ID: 16 lowercase hexadecimal characters.
    private static func randomSubscriptionID() -> String {
        let digits = Array("0123456789abcdef")
        var generator = SystemRandomNumberGenerator()
        return String((0..<16).map { _ in digits[Int.random(in: 0..<16, using: &generator)] })
    }
}
