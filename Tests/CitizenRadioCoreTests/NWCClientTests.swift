import Foundation
import XCTest
@testable import CitizenRadioCore

final class NWCClientTests: XCTestCase {
    /// A secp256k1 scalar for the fake wallet. It is the integer 3, a known valid key.
    private let walletSecretKey = String(repeating: "0", count: 63) + "3"
    /// A secp256k1 scalar for the client. It is the integer 5, a known valid key.
    private let clientSecretKey = String(repeating: "0", count: 63) + "5"
    /// A second wallet secret key, used only to forge an event from the wrong public key.
    private let otherSecretKey = String(repeating: "0", count: 63) + "7"

    private func makeConnection(walletPublicKey: String) throws -> NWCConnection {
        let uri = "nostr+walletconnect://\(walletPublicKey)?relay=wss://relay.example.com&secret=\(clientSecretKey)"
        return try NWCConnection(uri: uri)
    }

    // MARK: - Success

    func testGetInfoWithNIP44WalletGivesAliasMethodsAndEncryption() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info", "pay_keysend"], encryptionTag: "nip44_v2 nip04"),
            response: .success(alias: "Test Wallet", methods: ["get_info", "pay_keysend", "list_transactions"])
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let info = try await client.getInfo()

        XCTAssertEqual(info.alias, "Test Wallet")
        XCTAssertEqual(info.methods, ["get_info", "pay_keysend", "list_transactions"])
        XCTAssertEqual(info.encryption, "nip44_v2")
        XCTAssertTrue(info.supportsKeysend)
        await assertRequestEventIsCorrect(wallet, walletPublicKey: wallet.walletPublicKey)
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testGetInfoWithNoEncryptionTagUsesNIP04() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info"], encryptionTag: nil),
            response: .success(alias: nil, methods: nil)
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let info = try await client.getInfo()

        XCTAssertEqual(info.encryption, "nip04")
        XCTAssertNil(info.alias)
        XCTAssertEqual(info.methods, ["get_info"], "Without a result methods list, the info event methods apply.")
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    // MARK: - Wallet and relay errors

    func testWalletErrorResponseThrowsWalletError() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info"], encryptionTag: "nip44_v2"),
            response: .walletError(code: "UNAUTHORIZED", message: "no permission")
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        await assertThrows(client, equals: .walletError(code: "UNAUTHORIZED", message: "no permission"))
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testRelayRejectionThrowsRelayRejected() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info"], encryptionTag: "nip44_v2"),
            response: .rejected(message: "duplicate: already have this event")
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        await assertThrows(client, equals: .relayRejected("duplicate: already have this event"))
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testNoInfoEventThrowsNoInfoEvent() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .missing,
            response: .noResponse
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        await assertThrows(client, equals: .noInfoEvent)
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    // MARK: - Forged responses

    func testWrongSignatureResponseIsIgnoredAndTimesOut() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info"], encryptionTag: "nip44_v2"),
            response: .forgedWrongSignature
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet,
            timeout: .milliseconds(200)
        )

        await assertThrows(client, equals: .timeout)
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testDifferentPublicKeyResponseIsIgnoredAndTimesOut() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info"], encryptionTag: "nip44_v2"),
            response: .forgedDifferentPubkey(secretKey: otherSecretKey)
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet,
            timeout: .milliseconds(200)
        )

        await assertThrows(client, equals: .timeout)
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    // MARK: - Timeout

    func testWalletThatDoesNotAnswerThrowsTimeoutWithin200Milliseconds() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info"], encryptionTag: "nip44_v2"),
            response: .noResponse
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet,
            timeout: .milliseconds(200)
        )

        let clock = ContinuousClock()
        let start = clock.now
        await assertThrows(client, equals: .timeout)
        let elapsed = clock.now - start
        XCTAssertLessThan(elapsed, .seconds(1), "The timeout must not wait much longer than the configured limit.")
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    // MARK: - Payments

    /// A node key for the keysend tests: 66 hexadecimal characters.
    private let nodePubkey = "02" + String(repeating: "ab", count: 32)

    func testPayTwoKeysendPaymentsGivesTwoPaidAndSendsTheExactContent() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info", "pay_keysend"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.paid, .paid]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )
        let first = KeysendPayment(
            amountMsat: 21000, pubkey: nodePubkey,
            tlvRecords: [TLVRecord(type: 7629169, value: "7b7d"), TLVRecord(type: 696969, value: "6162")]
        )
        let second = KeysendPayment(amountMsat: 1000, pubkey: nodePubkey, tlvRecords: [])

        let outcomes = try await client.pay([.keysend(first), .keysend(second)], requestTimeout: .milliseconds(500))

        XCTAssertEqual(outcomes, [.paid, .paid])
        let contents = await wallet.receivedRequestContents
        XCTAssertEqual(contents, [
            "{\"method\":\"pay_keysend\",\"params\":{\"amount\":21000,\"pubkey\":\"\(nodePubkey)\","
                + "\"tlv_records\":[{\"type\":7629169,\"value\":\"7b7d\"},{\"type\":696969,\"value\":\"6162\"}]}}",
            "{\"method\":\"pay_keysend\",\"params\":{\"amount\":1000,\"pubkey\":\"\(nodePubkey)\"}}"
        ])
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testPayInvoiceContentHasTheInvoice() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["pay_invoice"], encryptionTag: nil),
            response: .noResponse,
            paymentResponses: [.paid]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let outcomes = try await client.pay([.invoice("lnbc210n1ptestinvoice")], requestTimeout: .milliseconds(500))

        XCTAssertEqual(outcomes, [.paid])
        let contents = await wallet.receivedRequestContents
        XCTAssertEqual(contents, ["{\"method\":\"pay_invoice\",\"params\":{\"invoice\":\"lnbc210n1ptestinvoice\"}}"])
    }

    func testWalletWithoutPayKeysendGivesUnsupportedAndReceivesNoKeysendRequest() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["get_info", "pay_invoice"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.paid]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )
        let keysend = KeysendPayment(amountMsat: 1000, pubkey: nodePubkey, tlvRecords: [])

        let outcomes = try await client.pay(
            [.keysend(keysend), .invoice("lnbc10n1ptest")], requestTimeout: .milliseconds(500)
        )

        XCTAssertEqual(outcomes, [.unsupported, .paid])
        let contents = await wallet.receivedRequestContents
        XCTAssertEqual(contents, ["{\"method\":\"pay_invoice\",\"params\":{\"invoice\":\"lnbc10n1ptest\"}}"])
    }

    func testWalletErrorGivesWalletErrorAndTheNextPaymentIsSent() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["pay_invoice"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.walletError(code: "INSUFFICIENT_BALANCE", message: "not enough sats"), .paid]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let outcomes = try await client.pay([.invoice("lnbc1a"), .invoice("lnbc1b")], requestTimeout: .milliseconds(500))

        XCTAssertEqual(outcomes, [.walletError(code: "INSUFFICIENT_BALANCE", message: "not enough sats"), .paid])
        let contents = await wallet.receivedRequestContents
        XCTAssertEqual(contents, [
            "{\"method\":\"pay_invoice\",\"params\":{\"invoice\":\"lnbc1a\"}}",
            "{\"method\":\"pay_invoice\",\"params\":{\"invoice\":\"lnbc1b\"}}"
        ])
    }

    func testRelayRejectionGivesRelayRejectedWalletErrorAndTheNextPaymentIsSent() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["pay_invoice"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.rejected(message: "blocked: rate limit"), .paid]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let outcomes = try await client.pay([.invoice("lnbc1a"), .invoice("lnbc1b")], requestTimeout: .milliseconds(500))

        XCTAssertEqual(outcomes, [.walletError(code: "RELAY_REJECTED", message: "blocked: rate limit"), .paid])
    }

    func testRequestWithNoResponseTimesOutAndTheNextPaymentIsSent() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["pay_invoice"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.noResponse, .paid]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let clock = ContinuousClock()
        let start = clock.now
        let outcomes = try await client.pay([.invoice("lnbc1a"), .invoice("lnbc1b")], requestTimeout: .milliseconds(200))
        let elapsed = clock.now - start

        XCTAssertEqual(outcomes, [.timeout, .paid])
        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(200), "The timeout must wait for the request time limit.")
        XCTAssertLessThan(elapsed, .seconds(1), "The timeout must not wait much longer than the request time limit.")
        let contents = await wallet.receivedRequestContents
        XCTAssertEqual(contents.count, 2, "The payment after the timeout must still be sent.")
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testForgedResponseFromADifferentKeyIsIgnored() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["pay_invoice"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.forgedDifferentPubkeyThenPaid(secretKey: otherSecretKey)]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let outcomes = try await client.pay([.invoice("lnbc1a")], requestTimeout: .milliseconds(500))

        XCTAssertEqual(outcomes, [.paid], "The forged error response must have no effect.")
    }

    func testConnectionErrorGivesTimeoutForTheRequestInFlightAndNotSentForTheRest() async throws {
        let wallet = try FakeWallet(
            walletSecretKey: walletSecretKey,
            info: .valid(methods: ["pay_invoice"], encryptionTag: "nip44_v2"),
            response: .noResponse,
            paymentResponses: [.connectionFailure]
        )
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        let outcomes = try await client.pay([.invoice("lnbc1a"), .invoice("lnbc1b")], requestTimeout: .milliseconds(500))

        XCTAssertEqual(outcomes, [.timeout, .notSent], "The first request was sent, so its result is not known.")
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    func testPayWithNoInfoEventThrowsNoInfoEventAndClosesTheConnection() async throws {
        let wallet = try FakeWallet(walletSecretKey: walletSecretKey, info: .missing, response: .noResponse)
        let client = NWCClient(
            connection: try makeConnection(walletPublicKey: wallet.walletPublicKey), connector: wallet
        )

        do {
            _ = try await client.pay([.invoice("lnbc1a")], requestTimeout: .milliseconds(500))
            XCTFail("Expected pay(_:requestTimeout:) to throw.")
        } catch {
            XCTAssertEqual(error as? NWCClient.Error, .noInfoEvent)
        }
        let contents = await wallet.receivedRequestContents
        XCTAssertEqual(contents, [])
        let closeCount = await wallet.closeCount
        XCTAssertEqual(closeCount, 1)
    }

    // MARK: - Helpers

    private func assertThrows(
        _ client: NWCClient, equals expected: NWCClient.Error, file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            _ = try await client.getInfo()
            XCTFail("Expected getInfo() to throw \(expected).", file: file, line: line)
        } catch let error as NWCClient.Error {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected an NWCClient.Error, got \(type(of: error)).", file: file, line: line)
        }
    }

    private func assertRequestEventIsCorrect(
        _ wallet: FakeWallet, walletPublicKey: String, file: StaticString = #filePath, line: UInt = #line
    ) async {
        guard let requestEvent = await wallet.receivedRequestEvent else {
            return XCTFail("The fake wallet did not receive a request event.", file: file, line: line)
        }
        XCTAssertEqual(requestEvent.kind, 23194, file: file, line: line)
        XCTAssertTrue(requestEvent.isValid(), file: file, line: line)
        XCTAssertTrue(
            requestEvent.tags.contains(["p", walletPublicKey]),
            "The request event must have a p tag with the wallet key.", file: file, line: line
        )
    }
}

/// A fake Nostr Wallet Connect wallet, reached over a fake relay connection.
///
/// This actor plays both roles: `RelayConnecting` opens the connection, and
/// `RelayConnection` carries the NIP-01 text messages. A test sets its
/// behavior for the info event and for the response event.
private actor FakeWallet: RelayConnecting, RelayConnection {
    /// The content of the kind 13194 info event, or its absence.
    enum InfoBehavior {
        case valid(methods: [String], encryptionTag: String?)
        case missing
    }

    /// How the wallet answers a signed request event.
    enum ResponseBehavior {
        case success(alias: String?, methods: [String]?)
        /// A payment result with a preimage.
        case paid
        case walletError(code: String, message: String)
        case rejected(message: String)
        case forgedWrongSignature
        case forgedDifferentPubkey(secretKey: String)
        /// A forged error response from an incorrect key, then a correct payment result.
        case forgedDifferentPubkeyThenPaid(secretKey: String)
        /// The connection fails, and each subsequent receive throws.
        case connectionFailure
        case noResponse
    }

    private let walletSecretKey: String
    let walletPublicKey: String
    private let info: InfoBehavior
    private let response: ResponseBehavior
    /// The behavior for each request in sequence. When this list is empty, `response` applies.
    private var paymentResponses: [ResponseBehavior]

    private var outgoing: [String] = []
    private var responseSubscriptionID: String?
    private var connectionFailed = false
    private(set) var closeCount = 0
    private(set) var receivedRequestEvent: NostrEvent?
    /// The decrypted content of each request event, in sequence.
    private(set) var receivedRequestContents: [String] = []

    init(
        walletSecretKey: String, info: InfoBehavior, response: ResponseBehavior,
        paymentResponses: [ResponseBehavior] = []
    ) throws {
        self.walletSecretKey = walletSecretKey
        self.walletPublicKey = try NostrKeys.publicKey(forSecret: walletSecretKey)
        self.info = info
        self.response = response
        self.paymentResponses = paymentResponses
    }

    // MARK: - RelayConnecting

    func connect(to url: URL) async throws -> any RelayConnection {
        self
    }

    // MARK: - RelayConnection

    func send(_ text: String) async throws {
        try handle(text)
    }

    /// Waits for the next message. The payment read task waits here before the client
    /// sends a request, so this method looks for a new message at a short interval.
    func receive() async throws -> String {
        while outgoing.isEmpty {
            if connectionFailed { throw FakeWalletConnectionError() }
            try await Task.sleep(for: .milliseconds(5))
        }
        return outgoing.removeFirst()
    }

    func close() async {
        closeCount += 1
    }

    // MARK: - Reading the client's messages

    private func handle(_ text: String) throws {
        guard let data = text.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let label = array.first as? String
        else {
            return
        }
        switch label {
        case "REQ":
            handleRequest(array)
        case "EVENT":
            try handleEvent(array)
        default:
            break
        }
    }

    private func handleRequest(_ array: [Any]) {
        guard array.count == 3, let subscriptionID = array[1] as? String,
              let filter = array[2] as? [String: Any], let kinds = filter["kinds"] as? [Int]
        else {
            return
        }
        if kinds.contains(13194) {
            sendInfoEvent(subscriptionID: subscriptionID)
        } else if kinds.contains(23195) {
            responseSubscriptionID = subscriptionID
        }
    }

    private func handleEvent(_ array: [Any]) throws {
        guard array.count == 2, let eventObject = array[1] as? [String: Any] else { return }
        let data = try JSONSerialization.data(withJSONObject: eventObject)
        let event = try JSONDecoder().decode(NostrEvent.self, from: data)
        receivedRequestEvent = event
        receivedRequestContents.append(try decryptedContent(of: event))
        let behavior = paymentResponses.isEmpty ? response : paymentResponses.removeFirst()
        try respond(to: event, behavior: behavior)
    }

    private func decryptedContent(of requestEvent: NostrEvent) throws -> String {
        if usesNIP44(requestEvent) {
            let key = try NIP44.conversationKey(secretKey: walletSecretKey, publicKey: requestEvent.pubkey)
            return try NIP44.decrypt(requestEvent.content, conversationKey: key)
        }
        return try NIP04.decrypt(requestEvent.content, secretKey: walletSecretKey, publicKey: requestEvent.pubkey)
    }

    private func usesNIP44(_ requestEvent: NostrEvent) -> Bool {
        requestEvent.tags.contains { $0.first == "encryption" && $0.dropFirst().first == "nip44_v2" }
    }

    // MARK: - Sending the info event

    private func sendInfoEvent(subscriptionID: String) {
        if case .valid(let methods, let encryptionTag) = info {
            var tags: [[String]] = []
            if let encryptionTag { tags.append(["encryption", encryptionTag]) }
            if let event = try? NostrEvent.signed(
                kind: 13194, tags: tags, content: methods.joined(separator: " "),
                createdAt: Int(Date().timeIntervalSince1970), secretKey: walletSecretKey
            ) {
                outgoing.append(relayEventText(subscriptionID: subscriptionID, event: event))
            }
        }
        outgoing.append("[\"EOSE\",\"\(subscriptionID)\"]")
    }

    // MARK: - Sending the response

    private func respond(to requestEvent: NostrEvent, behavior: ResponseBehavior) throws {
        switch behavior {
        case .rejected(let message):
            outgoing.append(okText(eventID: requestEvent.id, accepted: false, message: message))
            return
        case .noResponse:
            return
        case .connectionFailure:
            connectionFailed = true
            return
        case .success, .paid, .walletError, .forgedWrongSignature, .forgedDifferentPubkey, .forgedDifferentPubkeyThenPaid:
            outgoing.append(okText(eventID: requestEvent.id, accepted: true, message: ""))
        }

        if case .forgedDifferentPubkeyThenPaid(let secretKey) = behavior {
            // The forged event has an error content. A client that accepts it gives a wallet error.
            let forgedPlaintext = responsePlaintext(.walletError(code: "FORGED", message: "forged"))
            try sendResponse(to: requestEvent, plaintext: forgedPlaintext, signedAs: .forgedDifferentPubkey(secretKey: secretKey))
            try sendResponse(to: requestEvent, plaintext: responsePlaintext(.paid), signedAs: .paid)
        } else {
            try sendResponse(to: requestEvent, plaintext: responsePlaintext(behavior), signedAs: behavior)
        }
    }

    private func sendResponse(to requestEvent: NostrEvent, plaintext: String, signedAs behavior: ResponseBehavior) throws {
        guard let responseSubscriptionID else { return }
        let content: String
        if usesNIP44(requestEvent) {
            let key = try NIP44.conversationKey(secretKey: walletSecretKey, publicKey: requestEvent.pubkey)
            content = try NIP44.encrypt(plaintext, conversationKey: key)
        } else {
            content = try NIP04.encrypt(plaintext, secretKey: walletSecretKey, publicKey: requestEvent.pubkey)
        }

        let tags = [["e", requestEvent.id], ["p", requestEvent.pubkey]]
        let responseEvent = try signedResponseEvent(content: content, tags: tags, behavior: behavior)
        outgoing.append(relayEventText(subscriptionID: responseSubscriptionID, event: responseEvent))
    }

    private func responsePlaintext(_ behavior: ResponseBehavior) -> String {
        let object: [String: Any]
        switch behavior {
        case .success(let alias, let methods):
            var result: [String: Any] = [:]
            if let alias { result["alias"] = alias }
            if let methods { result["methods"] = methods }
            object = ["result": result]
        case .paid:
            object = ["result_type": "pay", "result": ["preimage": String(repeating: "0", count: 64)]]
        case .walletError(let code, let message):
            object = ["error": ["code": code, "message": message]]
        case .forgedWrongSignature, .forgedDifferentPubkey:
            object = ["result": ["alias": "forged", "methods": ["get_info"]]]
        case .rejected, .noResponse, .connectionFailure, .forgedDifferentPubkeyThenPaid:
            object = [:]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Signs the response event. A forged scenario signs with the wrong key
    /// or replaces a correct signature with one that does not match.
    private func signedResponseEvent(content: String, tags: [[String]], behavior: ResponseBehavior) throws -> NostrEvent {
        let createdAt = Int(Date().timeIntervalSince1970)
        switch behavior {
        case .forgedDifferentPubkey(let secretKey):
            return try NostrEvent.signed(kind: 23195, tags: tags, content: content, createdAt: createdAt, secretKey: secretKey)
        case .forgedWrongSignature:
            let event = try NostrEvent.signed(
                kind: 23195, tags: tags, content: content, createdAt: createdAt, secretKey: walletSecretKey
            )
            return NostrEvent(
                id: event.id, pubkey: event.pubkey, created_at: event.created_at, kind: event.kind,
                tags: event.tags, content: event.content, sig: String(repeating: "0", count: 128)
            )
        case .success, .paid, .walletError, .rejected, .noResponse, .connectionFailure, .forgedDifferentPubkeyThenPaid:
            return try NostrEvent.signed(
                kind: 23195, tags: tags, content: content, createdAt: createdAt, secretKey: walletSecretKey
            )
        }
    }

    private func okText(eventID: String, accepted: Bool, message: String) -> String {
        "[\"OK\",\"\(eventID)\",\(accepted),\"\(message)\"]"
    }

    /// Builds the NIP-01 relay-to-client shape: `["EVENT","<subscription_id>",<event>]`.
    ///
    /// `ClientMessage.event` builds the client-to-relay publish shape instead,
    /// which has only two items. The fake relay needs this three-item shape.
    private func relayEventText(subscriptionID: String, event: NostrEvent) -> String {
        guard let data = try? JSONEncoder().encode(event), let eventText = String(data: data, encoding: .utf8) else {
            return "[\"EVENT\",\"\(subscriptionID)\",{}]"
        }
        return "[\"EVENT\",\"\(subscriptionID)\"," + eventText + "]"
    }
}

/// The fake wallet throws this error after the connection fails.
private struct FakeWalletConnectionError: Error {}
