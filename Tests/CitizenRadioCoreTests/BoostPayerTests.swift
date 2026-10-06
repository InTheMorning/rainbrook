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

    private func address(_ name: String, sats: Int) -> BoostPart {
        BoostPart(
            destination: LiveValueDestination(
                kind: .lightningAddress(name: name, host: "pay.io"), name: nil, split: 50, fee: false,
                customKey: nil, customValue: nil
            ),
            sats: sats
        )
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

    // MARK: - Payments

    func testTwoNodePartsGiveOneCallWithTwoKeysendPayments() async throws {
        let wallet = FakeWallet(outcomes: [.paid, .paid])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [
            node(pubkeyA, sats: 60, name: "Alice", customKey: "696969", customValue: "abc"),
            node(pubkeyB, sats: 40, name: nil)
        ]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100)

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

        XCTAssertEqual(
            result, BoostResult(paidSats: 100, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 2)
        )
    }

    func testLightningAddressPartFetchesTheInvoiceAndPaysIt() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, payRequest),
            callback100: (200, #"{"pr":"\#(invoice100)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)

        let result = await payer.pay(parts: [address("alice", sats: 100)], payload: payload, amountSats: 100)

        let requests = await fetcher.requests
        XCTAssertEqual(requests, [wellKnown, callback100])
        let calls = await wallet.calls
        XCTAssertEqual(calls, [[.invoice(invoice100)]])
        XCTAssertEqual(
            result, BoostResult(paidSats: 100, unknownSats: 0, paidParts: 1, unknownParts: 0, totalParts: 1)
        )
    }

    func testInvoiceForADifferentAmountIsNotPaid() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, payRequest),
            callback100: (200, #"{"pr":"\#(invoice200)"}"#)
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let parts = [address("alice", sats: 100), node(pubkeyA, sats: 30, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 130)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.count, 1)
        guard case .keysend(let payment) = calls.first?.first else {
            return XCTFail("The only payment must be the keysend payment.")
        }
        XCTAssertEqual(payment.pubkey, pubkeyA)
        XCTAssertEqual(
            result, BoostResult(paidSats: 30, unknownSats: 0, paidParts: 1, unknownParts: 0, totalParts: 2)
        )
    }

    func testWellKnownStatus404FailsOnlyThatPart() async {
        let wallet = FakeWallet(outcomes: [.paid, .paid])
        let fetcher = FakeLNURLFetcher([
            wellKnown: (200, payRequest),
            callback100: (200, #"{"pr":"\#(invoice100)"}"#),
            "https://pay.io/.well-known/lnurlp/bob": (404, "")
        ])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)
        let parts = [address("bob", sats: 50), address("alice", sats: 100), node(pubkeyA, sats: 20, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 170)

        let requests = await fetcher.requests
        XCTAssertEqual(requests, ["https://pay.io/.well-known/lnurlp/bob", wellKnown, callback100])
        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.count, 2)
        XCTAssertEqual(calls.first?.first, .invoice(invoice100))
        XCTAssertEqual(
            result, BoostResult(paidSats: 120, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 3)
        )
    }

    // MARK: - Outcomes

    func testPaidWalletErrorPaidGivesTwoPaidParts() async {
        let wallet = FakeWallet(outcomes: [.paid, .walletError(code: "INSUFFICIENT_BALANCE", message: ""), .paid])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [node(pubkeyA, sats: 50, name: nil), node(pubkeyB, sats: 30, name: nil), node(pubkeyA, sats: 20, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100)

        XCTAssertEqual(
            result, BoostResult(paidSats: 70, unknownSats: 0, paidParts: 2, unknownParts: 0, totalParts: 3)
        )
    }

    func testPaidTimeoutNotSentGivesOnePaidAndOneUnknownPart() async {
        let wallet = FakeWallet(outcomes: [.paid, .timeout, .notSent])
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [node(pubkeyA, sats: 50, name: nil), node(pubkeyB, sats: 30, name: nil), node(pubkeyA, sats: 20, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100)

        XCTAssertEqual(
            result, BoostResult(paidSats: 50, unknownSats: 30, paidParts: 1, unknownParts: 1, totalParts: 3)
        )
    }

    func testWalletThrowGivesZeroPaid() async {
        let wallet = FakeWallet(fails: true)
        let payer = BoostPayer(wallet: wallet, fetcher: FakeLNURLFetcher([:]))
        let parts = [node(pubkeyA, sats: 60, name: nil), node(pubkeyB, sats: 40, name: nil)]

        let result = await payer.pay(parts: parts, payload: payload, amountSats: 100)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(
            result, BoostResult(paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: 2)
        )
    }

    func testNoPaymentLeftGivesNoWalletCall() async {
        let wallet = FakeWallet(outcomes: [.paid])
        let fetcher = FakeLNURLFetcher(["https://pay.io/.well-known/lnurlp/bob": (404, "")])
        let payer = BoostPayer(wallet: wallet, fetcher: fetcher)

        let result = await payer.pay(parts: [address("bob", sats: 100)], payload: payload, amountSats: 100)

        let calls = await wallet.calls
        XCTAssertEqual(calls.count, 0)
        XCTAssertEqual(
            result, BoostResult(paidSats: 0, unknownSats: 0, paidParts: 0, unknownParts: 0, totalParts: 1)
        )
    }
}
