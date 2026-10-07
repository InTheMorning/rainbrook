import Foundation
import XCTest
@testable import CitizenRadioCore

private struct FakeError: Error {}

/// A wallet that gives fixed outcomes and records each call.
private actor FakeWallet: WalletPaying {
    private let outcomes: [NWCPaymentOutcome]
    private let fails: Bool
    private(set) var calls: [[NWCPayment]] = []

    init(outcomes: [NWCPaymentOutcome] = [], fails: Bool = false) {
        self.outcomes = outcomes
        self.fails = fails
    }

    func pay(_ payments: [NWCPayment]) async throws -> [NWCPaymentOutcome] {
        calls.append(payments)
        if fails { throw FakeError() }
        return outcomes
    }
}

/// A fetcher that gives a fixed response for each URL and records each request.
/// A URL with no response throws.
private actor FakeLNURLFetcher: SnapshotFetching {
    private let responses: [String: (status: Int, body: String)]
    private(set) var requests: [String] = []

    init(_ responses: [String: (status: Int, body: String)]) {
        self.responses = responses
    }

    func fetch(_ url: URL) async throws -> (status: Int, body: Data) {
        requests.append(url.absoluteString)
        guard let response = responses[url.absoluteString] else { throw FakeError() }
        return (response.status, Data(response.body.utf8))
    }
}

final class BoostPayerTests: XCTestCase {
    private let pubkeyA = "02" + String(repeating: "a", count: 64)
    private let pubkeyB = "03" + String(repeating: "b", count: 64)

    // The data part after the last "1" is a bech32 text. It does not contain "1".
    private let bolt11Body = "pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4js"
    /// 1u is 100 sats.
    private var invoice100: String { "lnbc1u1" + bolt11Body }
    /// 2u is 200 sats.
    private var invoice200: String { "lnbc2u1" + bolt11Body }

    private let wellKnown = "https://pay.io/.well-known/lnurlp/alice"
    private let payRequest = """
    {"tag":"payRequest","callback":"https://pay.io/cb","minSendable":1000,"maxSendable":1000000000}
    """
    private let callback100 = "https://pay.io/cb?amount=100000"

    private let payload = try! LiveValuePayload.decode(Data("""
    { "title": "T", "eventGuid": "e", "blockGuid": "b", "value": { "destinations": [] } }
    """.utf8))!

    private func node(
        _ pubkey: String, sats: Int, name: String?, customKey: String? = nil, customValue: String? = nil
    ) -> BoostPart {
        BoostPart(
            destination: LiveValueDestination(
                kind: .node(pubkey: pubkey), name: name, split: 50, fee: false,
                customKey: customKey, customValue: customValue
            ),
            sats: sats
        )
    }

    /// A sender with no message and no sender name.
    private let plainSender = BoostSender(message: nil, senderName: nil, appName: "CitizenRadio")

    private func address(_ name: String, sats: Int, label: String? = nil) -> BoostPart {
        BoostPart(
            destination: LiveValueDestination(
                kind: .lightningAddress(name: name, host: "pay.io"), name: label, split: 50, fee: false,
                customKey: nil, customValue: nil
            ),
            sats: sats
        )
    }

    private func assertCounts(
        _ result: BoostResult, paidSats: Int, unknownSats: Int, paidParts: Int, unknownParts: Int, totalParts: Int,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(result.paidSats, paidSats, "paidSats", file: file, line: line)
        XCTAssertEqual(result.unknownSats, unknownSats, "unknownSats", file: file, line: line)
        XCTAssertEqual(result.paidParts, paidParts, "paidParts", file: file, line: line)
        XCTAssertEqual(result.unknownParts, unknownParts, "unknownParts", file: file, line: line)
        XCTAssertEqual(result.totalParts, totalParts, "totalParts", file: file, line: line)
    }

    private func text(ofHex hex: String) -> String {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// The TLV records of a keysend payment. Nil for an invoice payment or no payment.
    private func keysendRecords(_ payment: NWCPayment?) -> [TLVRecord]? {
        guard case .keysend(let keysend) = payment else { return nil }
        return keysend.tlvRecords
    }

    // MARK: - Payments

    func testTwoNodePartsGiveOneCallWithTwoKeysendPayments() async throws {
        let wallet = FakeWallet(outcomes: [.paid, .paid])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [
            node(pubkeyA, sats: 60, name: "Alice", customKey: "696969", customValue: "abc"),
            node(pubkeyB, sats: 40, name: nil)
        ]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100, sender: plainSender)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        let payments = try XCTUnwrap(calls.first)
        XCTAssertEqual(payments.count, 2)

        guard case .keysend(let first) = payments[0], case .keysend(let second) = payments[1] else {
            return XCTFail("Both payments must be keysend payments.")
        }
        XCTAssertEqual(first.amountMsat, 60_000)
        XCTAssertEqual(first.pubkey, pubkeyA)
        XCTAssertEqual(first.tlvRecords.map(\.type), [7_629_169, 696_969])
        XCTAssertEqual(
            text(ofHex: first.tlvRecords[0].value),
            #"{"action":"boost","app_name":"CitizenRadio","block_guid":"b","episode":"T","event_guid":"e","#
                + #""name":"Alice","value_msat":60000,"value_msat_total":100000}"#
        )
        XCTAssertEqual(first.tlvRecords[1].value, "616263")

        XCTAssertEqual(second.amountMsat, 40_000)
        XCTAssertEqual(second.pubkey, pubkeyB)
        XCTAssertEqual(second.tlvRecords.map(\.type), [7_629_169])
        XCTAssertEqual(
            text(ofHex: second.tlvRecords[0].value),
            #"{"action":"boost","app_name":"CitizenRadio","block_guid":"b","episode":"T","event_guid":"e","#
                + #""value_msat":40000,"value_msat_total":100000}"#
        )

        XCTAssertEqual(result.parts, [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 60, result: .confirmed),
            BoostPartResult(name: nil, kind: .keysend, sats: 40, result: .confirmed)
        ])
        assertCounts(result, paidSats: 100, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 2)
    }

    func testLightningAddressPartFetchesTheInvoiceAndPaysIt() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, payRequest),
            callback100: (200, #"{"pr":"\#(invoice100)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)

        let result = await payer.pay(parts: [address("alice", sats: 100)], payload: payload, amountSats: 100, sender: plainSender)

        let requests = await fetcher.requests
        XCTAssertEqual(requests, [wellKnown, callback100])
        let calls = await wallet.calls
        XCTAssertEqual(calls, [[.invoice(invoice100)]])
        XCTAssertEqual(result.parts, [
            BoostPartResult(name: nil, kind: .lightningAddress, sats: 100, result: .confirmed)
        ])
        assertCounts(result, paidSats: 100, unknownSats: 0, paidParts: 1, unknownParts: 0, totalParts: 1)
    }

    func testInvoiceForADifferentAmountIsNotPaid() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, payRequest),
            callback100: (200, #"{"pr":"\#(invoice200)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let parts = [address("alice", sats: 100), node(pubkeyA, sats: 30, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 130, sender: plainSender)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.count, 1)
        guard case .keysend(let payment) = calls.first?.first else {
            return XCTFail("The only payment must be the keysend payment.")
        }
        XCTAssertEqual(payment.pubkey, pubkeyA)
        XCTAssertEqual(result.parts, [
            BoostPartResult(
                name: nil, kind: .lightningAddress, sats: 100, result: .failed, failure: .lightningAddress,
                retry: .lightningAddress(name: "alice", host: "pay.io", amountMsat: 100_000, comment: "Boost from CitizenRadio")
            ),
            BoostPartResult(name: nil, kind: .keysend, sats: 30, result: .confirmed)
        ])
        assertCounts(result, paidSats: 30, unknownSats: 0, paidParts: 1, unknownParts: 0, totalParts: 2)
    }

    func testWellKnownStatus404FailsOnlyThatPart() async {
        let wallet = FakeWallet(outcomes: [.paid, .paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, payRequest),
            callback100: (200, #"{"pr":"\#(invoice100)"}"#),
            "https://pay.io/.well-known/lnurlp/bob": (404, "")
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let parts = [
            address("bob", sats: 50, label: "Bob"), address("alice", sats: 100, label: "Alice"),
            node(pubkeyA, sats: 20, name: "Host")
        ]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 170, sender: plainSender)

        let requests = await fetcher.requests
        XCTAssertEqual(requests, ["https://pay.io/.well-known/lnurlp/bob", wellKnown, callback100])
        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.count, 2)
        XCTAssertEqual(calls.first?.first, .invoice(invoice100))
        XCTAssertEqual(result.parts, [
            BoostPartResult(
                name: "Bob", kind: .lightningAddress, sats: 50, result: .failed, failure: .lightningAddress,
                retry: .lightningAddress(name: "bob", host: "pay.io", amountMsat: 50_000, comment: "Boost from CitizenRadio")
            ),
            BoostPartResult(name: "Alice", kind: .lightningAddress, sats: 100, result: .confirmed),
            BoostPartResult(name: "Host", kind: .keysend, sats: 20, result: .confirmed)
        ])
        assertCounts(result, paidSats: 120, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 3)
    }

    // MARK: - Outcomes

    func testPaidWalletErrorPaidGivesTwoPaidParts() async {
        let wallet = FakeWallet(outcomes: [.paid, .walletError(code: "INSUFFICIENT_BALANCE", message: ""), .paid])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [node(pubkeyA, sats: 50, name: nil), node(pubkeyB, sats: 30, name: nil), node(pubkeyA, sats: 20, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100, sender: plainSender)

        XCTAssertEqual(result.parts.map(\.result), [.confirmed, .failed, .confirmed])
        XCTAssertEqual(result.parts.map(\.sats), [50, 30, 20])
        assertCounts(result, paidSats: 70, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 3)
    }

    func testPaidTimeoutNotSentGivesOnePaidAndOneUnknownPart() async throws {
        let wallet = FakeWallet(outcomes: [.paid, .timeout, .notSent])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [node(pubkeyA, sats: 50, name: nil), node(pubkeyB, sats: 30, name: nil), node(pubkeyA, sats: 20, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100, sender: plainSender)

        let calls = await wallet.calls
        let sentRecords = try XCTUnwrap(keysendRecords(calls.first?[2]))
        XCTAssertEqual(result.parts, [
            BoostPartResult(name: nil, kind: .keysend, sats: 50, result: .confirmed),
            BoostPartResult(name: nil, kind: .keysend, sats: 30, result: .unknown),
            BoostPartResult(
                name: nil, kind: .keysend, sats: 20, result: .failed, failure: .notSent,
                retry: .keysend(pubkey: pubkeyA, amountMsat: 20_000, tlvRecords: sentRecords)
            )
        ])
        assertCounts(result, paidSats: 50, unknownSats: 30, paidParts: 1, unknownParts: 1, totalParts: 3)
    }

    func testWalletThrowGivesZeroPaid() async throws {
        let wallet = FakeWallet(fails: true)
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [node(pubkeyA, sats: 60, name: "Alice"), node(pubkeyB, sats: 40, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100, sender: plainSender)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        let firstRecords = try XCTUnwrap(keysendRecords(calls.first?[0]))
        let secondRecords = try XCTUnwrap(keysendRecords(calls.first?[1]))
        XCTAssertEqual(result.parts, [
            BoostPartResult(
                name: "Alice", kind: .keysend, sats: 60, result: .failed, failure: .notSent,
                retry: .keysend(pubkey: pubkeyA, amountMsat: 60_000, tlvRecords: firstRecords)
            ),
            BoostPartResult(
                name: nil, kind: .keysend, sats: 40, result: .failed, failure: .notSent,
                retry: .keysend(pubkey: pubkeyB, amountMsat: 40_000, tlvRecords: secondRecords)
            )
        ])
        assertCounts(result, paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: 2)
    }

    func testNoPaymentLeftGivesNoWalletCall() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let fetcher = FakeLNURLFetcher(["https://pay.io/.well-known/lnurlp/bob": (404, "")])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)

        let result = await payer.pay(parts: [address("bob", sats: 100)], payload: payload, amountSats: 100, sender: plainSender)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 0)
        XCTAssertEqual(result.parts, [
            BoostPartResult(
                name: nil, kind: .lightningAddress, sats: 100, result: .failed, failure: .lightningAddress,
                retry: .lightningAddress(name: "bob", host: "pay.io", amountMsat: 100_000, comment: "Boost from CitizenRadio")
            )
        ])
        assertCounts(result, paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: 1)
    }

    // MARK: - Message

    func testMessageGoesIntoTheKeysendRecordAndTheLNURLComment() async throws {
        let wallet = FakeWallet(outcomes: [.paid, .paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, """
            {"tag":"payRequest","callback":"https://pay.io/cb","minSendable":1000,"maxSendable":1000000000,
             "commentAllowed":50}
            """),
            "https://pay.io/cb?amount=100000&comment=Great%20set": (200, #"{"pr":"\#(invoice100)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let sender = BoostSender(message: "Great set", senderName: "Maik", appName: "MyApp")

        let result = await payer.pay(
            parts: [node(pubkeyA, sats: 30, name: nil), address("alice", sats: 100)],
            payload: payload, amountSats: 130, sender: sender
        )

        let requests = await fetcher.requests
        XCTAssertEqual(requests, [wellKnown, "https://pay.io/cb?amount=100000&comment=Great%20set"])
        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        let payments = try XCTUnwrap(calls.first)
        XCTAssertEqual(payments.count, 2)
        guard case .keysend(let keysend) = payments[0] else {
            return XCTFail("The first payment must be the keysend payment.")
        }
        XCTAssertEqual(
            text(ofHex: keysend.tlvRecords[0].value),
            #"{"action":"boost","app_name":"MyApp","block_guid":"b","episode":"T","event_guid":"e","#
                + #""message":"Great set","sender_name":"Maik","value_msat":30000,"value_msat_total":130000}"#
        )
        XCTAssertEqual(payments[1], .invoice(invoice100))
        XCTAssertEqual(result.parts.map(\.result), [.confirmed, .confirmed])
    }

    func testNoMessageGivesTheAppNameComment() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let callback = "https://pay.io/cb?amount=100000&comment=Boost%20from%20MyApp"
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, """
            {"tag":"payRequest","callback":"https://pay.io/cb","minSendable":1000,"maxSendable":1000000000,
             "commentAllowed":50}
            """),
            callback: (200, #"{"pr":"\#(invoice100)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let sender = BoostSender(message: nil, senderName: nil, appName: "MyApp")

        _ = await payer.pay(parts: [address("alice", sats: 100)], payload: payload, amountSats: 100, sender: sender)

        let requests = await fetcher.requests
        XCTAssertEqual(requests, [wellKnown, callback])
    }

    // MARK: - Failure reason and retry data

    func testKeysendPartWithAWalletErrorKeepsTheReasonTheRecordsAndOneAttempt() async throws {
        let wallet = FakeWallet(outcomes: [.walletError(code: "PAYMENT_FAILED", message: "No route")])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))

        let result = await payer.pay(
            parts: [node(pubkeyA, sats: 70, name: "Main", customKey: "696969", customValue: "abc")],
            payload: payload, amountSats: 100, sender: plainSender
        )

        let calls = await wallet.calls
        let sentRecords = try XCTUnwrap(keysendRecords(calls.first?.first))
        XCTAssertEqual(sentRecords.map(\.type), [7_629_169, 696_969])
        let part = try XCTUnwrap(result.parts.first)
        XCTAssertEqual(part.result, .failed)
        XCTAssertEqual(part.failure, .walletError(code: "PAYMENT_FAILED", message: "No route"))
        XCTAssertEqual(part.retry, .keysend(pubkey: pubkeyA, amountMsat: 70_000, tlvRecords: sentRecords))
        XCTAssertEqual(part.attempts, 1)
        XCTAssertTrue(part.isRetryable)
    }

    func testUnsupportedPartHasNoRetryData() async throws {
        let wallet = FakeWallet(outcomes: [.unsupported])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))

        let result = await payer.pay(parts: [node(pubkeyA, sats: 70, name: nil)], payload: payload, amountSats: 70, sender: plainSender)

        let part = try XCTUnwrap(result.parts.first)
        XCTAssertEqual(part.result, .failed)
        XCTAssertEqual(part.failure, .unsupported)
        XCTAssertNil(part.retry)
        XCTAssertFalse(part.isRetryable)
    }

    func testTimeoutPartHasNoFailureAndNoRetryData() async throws {
        let wallet = FakeWallet(outcomes: [.timeout])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))

        let result = await payer.pay(parts: [node(pubkeyA, sats: 70, name: nil)], payload: payload, amountSats: 70, sender: plainSender)

        let part = try XCTUnwrap(result.parts.first)
        XCTAssertEqual(part.result, .unknown)
        XCTAssertNil(part.failure)
        XCTAssertNil(part.retry)
        XCTAssertEqual(part.attempts, 1)
    }

    func testLNURLFailureKeepsTheReasonAndTheRetryDataWithTheComment() async throws {
        let wallet = FakeWallet(outcomes: [])
        let fetcher = FakeLNURLFetcher([wellKnown: (500, "")])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let sender = BoostSender(message: "Great set", senderName: nil, appName: "MyApp")

        let result = await payer.pay(parts: [address("alice", sats: 100)], payload: payload, amountSats: 100, sender: sender)

        let part = try XCTUnwrap(result.parts.first)
        XCTAssertEqual(part.result, .failed)
        XCTAssertEqual(part.failure, .lightningAddress)
        XCTAssertEqual(
            part.retry, .lightningAddress(name: "alice", host: "pay.io", amountMsat: 100_000, comment: "Great set")
        )
        XCTAssertEqual(part.attempts, 1)
    }

    // MARK: - Retry

    private let storedRecords = [TLVRecord(type: 7_629_169, value: "7b7d"), TLVRecord(type: 696_969, value: "616263")]

    /// A keysend part that failed with a wallet error, with fixed retry data.
    private func failedKeysend(attempts: Int = 1) -> BoostPartResult {
        BoostPartResult(
            name: "Main", kind: .keysend, sats: 70, result: .failed,
            failure: .walletError(code: "PAYMENT_FAILED", message: "No route"),
            retry: .keysend(pubkey: pubkeyA, amountMsat: 70_000, tlvRecords: storedRecords),
            attempts: attempts
        )
    }

    func testRetrySendsOnlyTheRetryablePartAndKeepsTheConfirmedPart() async {
        let wallet = FakeWallet(outcomes: [.walletError(code: "PAYMENT_FAILED", message: "Offline")])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let confirmed = BoostPartResult(name: "Host", kind: .keysend, sats: 30, result: .confirmed)

        let parts = await payer.retry(parts: [confirmed, failedKeysend()])

        let calls = await wallet.calls
        XCTAssertEqual(calls, [[.keysend(KeysendPayment(amountMsat: 70_000, pubkey: pubkeyA, tlvRecords: storedRecords))]])
        XCTAssertEqual(parts, [
            confirmed,
            BoostPartResult(
                name: "Main", kind: .keysend, sats: 70, result: .failed,
                failure: .walletError(code: "PAYMENT_FAILED", message: "Offline"),
                retry: .keysend(pubkey: pubkeyA, amountMsat: 70_000, tlvRecords: storedRecords),
                attempts: 2
            )
        ])
    }

    func testRetriedPartThatIsPaidBecomesConfirmedWithTwoAttempts() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))

        let parts = await payer.retry(parts: [failedKeysend()])

        XCTAssertEqual(parts.map(\.result), [.confirmed])
        XCTAssertEqual(parts.map(\.attempts), [2])
        XCTAssertEqual(parts.map(\.failure), [nil])
        XCTAssertEqual(parts.map(\.retry), [nil])
    }

    func testRetryNeverSendsAnUnknownPartOrAFailedPartWithNoRetryData() async {
        let wallet = FakeWallet(outcomes: [.paid, .paid])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let unknown = BoostPartResult(name: "A", kind: .keysend, sats: 40, result: .unknown)
        let unsupported = BoostPartResult(name: "B", kind: .keysend, sats: 60, result: .failed, failure: .unsupported)

        let parts = await payer.retry(parts: [unknown, unsupported])

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 0)
        XCTAssertEqual(parts, [unknown, unsupported])
    }

    func testRetryOfALightningAddressPartFetchesANewInvoice() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let callback = "https://pay.io/cb?amount=100000&comment=Great%20set"
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, """
            {"tag":"payRequest","callback":"https://pay.io/cb","minSendable":1000,"maxSendable":1000000000,
             "commentAllowed":50}
            """),
            callback: (200, #"{"pr":"\#(invoice100)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let failed = BoostPartResult(
            name: "Alice", kind: .lightningAddress, sats: 100, result: .failed, failure: .lightningAddress,
            retry: .lightningAddress(name: "alice", host: "pay.io", amountMsat: 100_000, comment: "Great set")
        )

        let parts = await payer.retry(parts: [failed])

        let requests = await fetcher.requests
        XCTAssertEqual(requests, [wellKnown, callback])
        let calls = await wallet.calls
        XCTAssertEqual(calls, [[.invoice(invoice100)]])
        XCTAssertEqual(parts, [
            BoostPartResult(name: "Alice", kind: .lightningAddress, sats: 100, result: .confirmed, attempts: 2)
        ])
    }

    func testRetryWithAWalletThrowGivesNotSentAndKeepsTheRetryData() async {
        let wallet = FakeWallet(fails: true)
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))

        let parts = await payer.retry(parts: [failedKeysend(attempts: 2)])

        XCTAssertEqual(parts, [
            BoostPartResult(
                name: "Main", kind: .keysend, sats: 70, result: .failed, failure: .notSent,
                retry: .keysend(pubkey: pubkeyA, amountMsat: 70_000, tlvRecords: storedRecords), attempts: 3
            )
        ])
    }
}
