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
        try await Self.withTimeLimit(timeout) { try await self.runGetInfo() }
    }

    /// Runs `operation` with the time limit `limit`.
    ///
    /// After that limit, this method cancels `operation` and throws `Error.timeout`.
    private static func withTimeLimit<Result: Sendable>(
        _ limit: Duration, _ operation: @escaping @Sendable () async throws -> Result
    ) async throws -> Result {
        try await withThrowingTaskGroup(of: Result.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: limit)
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
        let request = try await sendRequest(
            "{\"method\":\"get_info\",\"params\":{}}", over: relayConnection, info: info
        )
        let requestEvent = request.event
        let subscriptionID = request.subscriptionID

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

    /// A signed request event that the client sent, with the subscription for its response.
    private struct SentRequest {
        let event: NostrEvent
        let subscriptionID: String
    }

    /// Encrypts and signs a request event, then subscribes to its response and sends it.
    ///
    /// The subscription starts before the request, so the client cannot miss a fast response.
    private func sendRequest(
        _ plainContent: String, over relayConnection: any RelayConnection, info: WalletInfoEvent
    ) async throws -> SentRequest {
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
        return SentRequest(event: requestEvent, subscriptionID: subscriptionID)
    }

    /// Decrypts the response event and decodes its content as a JSON object.
    ///
    /// This method throws `Error.invalidResponse` if the decryption or the decoding fails.
    private func decryptResponseObject(_ event: NostrEvent, info: WalletInfoEvent) throws -> [String: Any] {
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
        return object
    }

    /// Decrypts and decodes the wallet's response event.
    private func decodeResponse(_ event: NostrEvent, info: WalletInfoEvent) throws -> WalletInfo {
        let object = try decryptResponseObject(event, info: info)
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

// MARK: - Payments

extension NWCClient {
    /// One item for the payment read loop.
    private enum PaymentInput: Sendable {
        /// A text message from the relay.
        case message(String)
        /// The connection failed while the client waited for a message.
        case failed(any Swift.Error)
        /// The time limit for the request with this number is at its end.
        case deadline(Int)
    }

    /// Sends the payments in order over one relay connection. Throws only when the connection
    /// or the info event fails before the first payment. Each payment gets one outcome, in order.
    ///
    /// ADR 0012 §The payment names this sequence. The read of the info event has the
    /// time limit `timeout`. Each payment request has the time limit `requestTimeout`.
    /// A timeout of one request does not stop the next payment.
    public func pay(_ payments: [NWCPayment], requestTimeout: Duration = .seconds(30)) async throws -> [NWCPaymentOutcome] {
        guard !payments.isEmpty else { return [] }
        let relayConnection = try await connector.connect(to: connection.relays[0])
        do {
            let info = try await Self.withTimeLimit(timeout) { try await self.readWalletInfo(over: relayConnection) }
            let outcomes = try await sendPayments(payments, over: relayConnection, info: info, requestTimeout: requestTimeout)
            await relayConnection.close()
            return outcomes
        } catch {
            await relayConnection.close()
            throw error
        }
    }

    /// Sends each payment request in sequence, and reads one outcome for each request.
    ///
    /// One read task reads all relay messages. A request timeout does not cancel that task,
    /// because a canceled read can close the connection.
    ///
    /// This method is `nonisolated`, so the stream iterator stays in one isolation domain.
    /// On iOS 17, an actor method cannot call `next()` on an iterator without a data race error.
    private nonisolated func sendPayments(
        _ payments: [NWCPayment], over relayConnection: any RelayConnection, info: WalletInfoEvent,
        requestTimeout: Duration
    ) async throws -> [NWCPaymentOutcome] {
        let (inputs, continuation) = AsyncStream.makeStream(of: PaymentInput.self)
        let reader = Task {
            do {
                while true {
                    continuation.yield(.message(try await relayConnection.receive()))
                }
            } catch {
                continuation.yield(.failed(error))
                continuation.finish()
            }
        }
        defer { reader.cancel() }

        var iterator = inputs.makeAsyncIterator()
        var outcomes: [NWCPaymentOutcome] = []
        for (number, payment) in payments.enumerated() {
            guard info.methods.contains(payment.method) else {
                outcomes.append(.unsupported)
                continue
            }
            do {
                let content = try payment.requestContent()
                let request = try await sendRequest(content, over: relayConnection, info: info)
                let deadline = Task {
                    guard (try? await Task.sleep(for: requestTimeout)) != nil else { return }
                    continuation.yield(.deadline(number))
                }
                defer { deadline.cancel() }
                let outcome = try await readPaymentOutcome(for: request, number: number, info: info, from: &iterator)
                outcomes.append(outcome)
                try await relayConnection.send(ClientMessage.close(subscriptionID: request.subscriptionID))
            } catch {
                // ADR 0012 §The limits: after a connection error, the result of the request in flight is
                // not known. It counts as a timeout, so the caller counts it against the daily limit.
                // The payments after it are not sent.
                if outcomes.count == number {
                    outcomes.append(.timeout)
                }
                outcomes.append(contentsOf: Array(repeating: .notSent, count: payments.count - outcomes.count))
                return outcomes
            }
        }
        return outcomes
    }

    /// Reads the relay messages until the response to `request`, or until its time limit.
    private nonisolated func readPaymentOutcome(
        for request: SentRequest, number: Int, info: WalletInfoEvent,
        from iterator: inout AsyncStream<PaymentInput>.Iterator
    ) async throws -> NWCPaymentOutcome {
        while let input = await iterator.next() {
            switch input {
            case .failed(let error):
                throw error
            case .deadline(let deadlineNumber):
                // A deadline from an earlier request has no effect.
                if deadlineNumber == number { return .timeout }
            case .message(let text):
                guard let message = try? RelayMessage(text: text) else { continue }
                switch message {
                case .ok(let eventID, let accepted, let okMessage):
                    guard eventID == request.event.id, !accepted else { continue }
                    return .walletError(code: "RELAY_REJECTED", message: okMessage)
                case .event(let sid, let event):
                    guard sid == request.subscriptionID else { continue }
                    // A relay can send a forged event. Ignore any event that fails these checks.
                    guard event.isValid(), event.pubkey == connection.walletPublicKey,
                          event.tags.contains(where: { $0.count >= 2 && $0[0] == "e" && $0[1] == request.event.id })
                    else { continue }
                    return await paymentOutcome(of: event, info: info)
                default:
                    continue
                }
            }
        }
        // The stream ends only when the caller cancels the task.
        throw CancellationError()
    }

    /// Decrypts and decodes the wallet's response to one payment request.
    private func paymentOutcome(of event: NostrEvent, info: WalletInfoEvent) -> NWCPaymentOutcome {
        guard let object = try? decryptResponseObject(event, info: info) else { return .invalidResponse }
        if let errorObject = object["error"] as? [String: Any] {
            let code = errorObject["code"] as? String ?? ""
            let message = errorObject["message"] as? String ?? ""
            return .walletError(code: code, message: message)
        }
        guard object["result"] is [String: Any] else { return .invalidResponse }
        return .paid
    }
}
