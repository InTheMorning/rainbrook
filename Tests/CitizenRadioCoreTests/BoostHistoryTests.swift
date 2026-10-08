import Foundation
import XCTest
@testable import CitizenRadioCore

final class BoostHistoryTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private var tempDirectory: URL!

    override func setUp() {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func entry(sats: Int, parts: [BoostPartResult] = []) -> BoostHistoryEntry {
        BoostHistoryEntry(
            date: fixedDate, kind: .auto, title: "Track", artist: "Artist",
            amountSats: sats, message: nil, parts: parts
        )
    }

    // MARK: - BoostPaymentResult

    func testPaidGivesConfirmed() {
        XCTAssertEqual(BoostPaymentResult(.paid), .confirmed)
    }

    func testUnsupportedGivesFailed() {
        XCTAssertEqual(BoostPaymentResult(.unsupported), .failed)
    }

    func testWalletErrorGivesFailed() {
        XCTAssertEqual(BoostPaymentResult(.walletError(code: "CODE", message: "message")), .failed)
    }

    func testTimeoutGivesUnknown() {
        XCTAssertEqual(BoostPaymentResult(.timeout), .unknown)
    }

    func testInvalidResponseGivesFailed() {
        XCTAssertEqual(BoostPaymentResult(.invalidResponse), .failed)
    }

    func testNotSentGivesFailed() {
        XCTAssertEqual(BoostPaymentResult(.notSent), .failed)
    }

    // MARK: - BoostFailure

    func testFailureForEachOutcome() {
        XCTAssertNil(BoostFailure(.paid))
        XCTAssertNil(BoostFailure(.timeout))
        XCTAssertEqual(BoostFailure(.unsupported), .unsupported)
        XCTAssertEqual(
            BoostFailure(.walletError(code: "PAYMENT_FAILED", message: "No route")),
            .walletError(code: "PAYMENT_FAILED", message: "No route")
        )
        XCTAssertEqual(BoostFailure(.invalidResponse), .invalidResponse)
        XCTAssertEqual(BoostFailure(.notSent), .notSent)
    }

    func testIsRetryableForEachFailure() {
        XCTAssertTrue(BoostFailure.walletError(code: "CODE", message: "message").isRetryable)
        XCTAssertTrue(BoostFailure.notSent.isRetryable)
        XCTAssertTrue(BoostFailure.lightningAddress.isRetryable)
        XCTAssertFalse(BoostFailure.unsupported.isRetryable)
        XCTAssertFalse(BoostFailure.invalidResponse.isRetryable)
    }

    func testAWalletErrorMessageOf250CharactersKeeps200() {
        let message = String(repeating: "a", count: 200) + String(repeating: "b", count: 50)
        XCTAssertEqual(
            BoostFailure(.walletError(code: "CODE", message: message)),
            .walletError(code: "CODE", message: String(repeating: "a", count: 200))
        )
    }

    // MARK: - BoostPartResult

    private let retryData = BoostRetryPayment.keysend(
        pubkey: "02" + String(repeating: "a", count: 64), amountMsat: 70_000,
        tlvRecords: [TLVRecord(type: 7_629_169, value: "7b7d")]
    )

    func testAPartThatDidNotFailHasNoFailureAndNoRetryData() {
        let part = BoostPartResult(
            name: nil, kind: .keysend, sats: 70, result: .confirmed, failure: .notSent, retry: retryData
        )
        XCTAssertNil(part.failure)
        XCTAssertNil(part.retry)
        XCTAssertFalse(part.isRetryable)
    }

    func testAPartWithAFailureThatIsNotRetryableHasNoRetryData() {
        let part = BoostPartResult(
            name: nil, kind: .keysend, sats: 70, result: .failed, failure: .invalidResponse, retry: retryData
        )
        XCTAssertEqual(part.failure, .invalidResponse)
        XCTAssertNil(part.retry)
        XCTAssertFalse(part.isRetryable)
    }

    // MARK: - Retryable parts of an entry

    func testRetryablePartsAndRetryableSats() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "A", kind: .keysend, sats: 70, result: .failed, failure: .notSent, retry: retryData),
            BoostPartResult(name: "B", kind: .keysend, sats: 20, result: .failed, failure: .unsupported),
            BoostPartResult(name: "C", kind: .keysend, sats: 10, result: .confirmed)
        ])
        XCTAssertTrue(entry.hasRetryableParts)
        XCTAssertEqual(entry.retryableSats, 70)
    }

    func testAnEntryWithNoRetryablePart() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "A", kind: .keysend, sats: 100, result: .unknown)
        ])
        XCTAssertFalse(entry.hasRetryableParts)
        XCTAssertEqual(entry.retryableSats, 0)
    }

    func testReplacingPartsKeepsTheOtherFields() {
        let original = BoostHistoryEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, date: fixedDate, kind: .manual,
            title: "Track", artist: "Artist", amountSats: 100, message: "Hello",
            parts: [BoostPartResult(name: "A", kind: .keysend, sats: 100, result: .failed)]
        )
        let newParts = [BoostPartResult(name: "A", kind: .keysend, sats: 100, result: .confirmed, attempts: 2)]

        let replaced = original.replacingParts(newParts)

        XCTAssertEqual(replaced, BoostHistoryEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, date: fixedDate, kind: .manual,
            title: "Track", artist: "Artist", amountSats: 100, message: "Hello", parts: newParts
        ))
    }

    // MARK: - BoostHistory.update

    func testUpdateReplacesTheEntryAtItsPositionAndKeepsTheOtherEntries() {
        let first = entry(sats: 1)
        let second = entry(sats: 2)
        let third = entry(sats: 3)
        var history = BoostHistory(entries: [first, second, third])
        let updated = second.replacingParts([BoostPartResult(name: "A", kind: .keysend, sats: 2, result: .confirmed)])

        history.update(updated)

        XCTAssertEqual(history.entries, [first, updated, third])
    }

    func testUpdateWithAnUnknownIdChangesNothing() {
        let history = BoostHistory(entries: [entry(sats: 1), entry(sats: 2)])
        var changed = history

        changed.update(entry(sats: 3))

        XCTAssertEqual(changed, history)
    }

    func testFileStoreUpdateWritesTheUpdatedEntry() async {
        let fileURL = tempDirectory.appendingPathComponent("history.json")
        let store = BoostHistoryFileStore(fileURL: fileURL)
        let original = entry(sats: 50)
        _ = await store.add(original)
        let updated = original.replacingParts([BoostPartResult(name: "A", kind: .keysend, sats: 50, result: .confirmed)])

        let result = await store.update(updated)
        let loaded = await BoostHistoryFileStore(fileURL: fileURL).load()

        XCTAssertEqual(result.entries, [updated])
        XCTAssertEqual(loaded.entries, [updated])
    }

    // MARK: - BoostHistory.add

    func testAddPutsTheNewestEntryFirst() {
        var history = BoostHistory()
        history.add(entry(sats: 1))
        history.add(entry(sats: 2))
        XCTAssertEqual(history.entries.map(\.amountSats), [2, 1])
    }

    func testAfter201EntriesTheHistoryHas200AndTheFirstEntryIsGone() {
        var history = BoostHistory()
        for sats in 1...201 {
            history.add(entry(sats: sats))
        }
        XCTAssertEqual(history.entries.count, 200)
        XCTAssertEqual(history.entries.first?.amountSats, 201)
        XCTAssertFalse(history.entries.contains { $0.amountSats == 1 })
    }

    // MARK: - Codable round trip

    func testEncodedThenDecodeGivesAnEqualHistory() throws {
        var history = BoostHistory()
        history.add(entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 60, result: .confirmed),
            BoostPartResult(name: nil, kind: .lightningAddress, sats: 40, result: .unknown)
        ]))

        let data = try history.encoded()
        let decoded = try BoostHistory.decode(data)

        XCTAssertEqual(decoded, history)
    }

    func testEncodedThenDecodeKeepsTheFailureTheRetryDataAndTheAttempts() throws {
        var history = BoostHistory()
        history.add(entry(sats: 100, parts: [
            BoostPartResult(
                name: "Alice", kind: .keysend, sats: 60, result: .failed,
                failure: .walletError(code: "PAYMENT_FAILED", message: "No route"), retry: retryData, attempts: 2
            ),
            BoostPartResult(
                name: nil, kind: .lightningAddress, sats: 40, result: .failed, failure: .lightningAddress,
                retry: .lightningAddress(name: "alice", host: "pay.io", amountMsat: 40_000, comment: "Great set")
            )
        ]))

        let decoded = try BoostHistory.decode(try history.encoded())

        XCTAssertEqual(decoded, history)
    }

    func testTheHistoryFileOfADR0013DecodesWithOneAttempt() throws {
        let json = """
        [{"id":"22222222-2222-2222-2222-222222222222","date":"2023-11-14T22:13:20Z","kind":"auto",
          "title":"Track","artist":"Artist","amountSats":100,
          "parts":[{"name":"Alice","kind":"keysend","sats":70,"result":"failed"},
                   {"kind":"lightningAddress","sats":30,"result":"confirmed"}]}]
        """

        let history = try BoostHistory.decode(Data(json.utf8))

        XCTAssertEqual(history.entries, [BoostHistoryEntry(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, date: fixedDate, kind: .auto,
            title: "Track", artist: "Artist", amountSats: 100, message: nil,
            parts: [
                BoostPartResult(name: "Alice", kind: .keysend, sats: 70, result: .failed, failure: nil, retry: nil, attempts: 1),
                BoostPartResult(name: nil, kind: .lightningAddress, sats: 30, result: .confirmed, failure: nil, retry: nil, attempts: 1)
            ]
        )])
    }

    func testTheHistoryFileOfADR0016WithALightningAddressPartAndItsRetryDataDecodesWithNoPath() throws {
        let json = """
        [{"id":"33333333-3333-3333-3333-333333333333","date":"2023-11-14T22:13:20Z","kind":"manual",
          "title":"Track","amountSats":100,"message":"Great set",
          "parts":[{"name":"Alice","kind":"lightningAddress","sats":100,"result":"failed",
                    "failure":{"lightningAddress":{}},"attempts":2,
                    "retry":{"lightningAddress":{"name":"alice","host":"pay.io","amountMsat":100000,"comment":"Great set"}}}]}]
        """

        let history = try BoostHistory.decode(Data(json.utf8))

        let part = try XCTUnwrap(history.entries.first?.parts.first)
        XCTAssertNil(part.path)
        XCTAssertEqual(part.failure, .lightningAddress)
        XCTAssertEqual(part.attempts, 2)
        XCTAssertEqual(
            part.retry,
            .lightningAddress(
                name: "alice", host: "pay.io", amountMsat: 100_000, comment: "Great set", tlvRecords: nil, payerName: nil
            )
        )
        XCTAssertTrue(part.isRetryable)
    }

    func testEncodedThenDecodeKeepsThePathAndTheNewRetryData() throws {
        var history = BoostHistory()
        history.add(entry(sats: 100, parts: [
            BoostPartResult(
                name: "Alice", kind: .lightningAddress, sats: 100, result: .failed, failure: .notSent,
                retry: .lightningAddress(
                    name: "alice", host: "pay.io", amountMsat: 100_000, comment: "Great set",
                    tlvRecords: [TLVRecord(type: 7_629_169, value: "7b7d")], payerName: "Maik"
                ),
                path: .keysend
            )
        ]))

        let decoded = try BoostHistory.decode(try history.encoded())

        XCTAssertEqual(decoded, history)
        XCTAssertEqual(decoded.entries.first?.parts.first?.path, .keysend)
    }

    func testAKeysendPartAlwaysHasThePathKeysend() {
        XCTAssertEqual(BoostPartResult(name: nil, kind: .keysend, sats: 1, result: .confirmed).path, .keysend)
        XCTAssertEqual(
            BoostPartResult(name: nil, kind: .keysend, sats: 1, result: .confirmed, path: .invoice).path, .keysend
        )
    }

    // MARK: - BoostHistoryFileStore

    func testLoadOfAMissingFileIsEmpty() async {
        let store = BoostHistoryFileStore(fileURL: tempDirectory.appendingPathComponent("history.json"))
        let history = await store.load()
        XCTAssertEqual(history, BoostHistory())
    }

    func testANewStoreOnTheSameFileLoadsTheEntryAfterAdd() async {
        // The folder of the file does not exist yet. The store must create it.
        let fileURL = tempDirectory.appendingPathComponent("history", isDirectory: true)
            .appendingPathComponent("history.json")
        let firstStore = BoostHistoryFileStore(fileURL: fileURL)
        _ = await firstStore.add(entry(sats: 50))

        let secondStore = BoostHistoryFileStore(fileURL: fileURL)
        let history = await secondStore.load()

        XCTAssertEqual(history.entries.map(\.amountSats), [50])
    }

    func testAFileWithBadJSONLoadsAsEmpty() async throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("history.json")
        try Data("not json".utf8).write(to: fileURL)

        let store = BoostHistoryFileStore(fileURL: fileURL)
        let history = await store.load()

        XCTAssertEqual(history, BoostHistory())
    }

    // MARK: - BoostHistoryText.summary

    func testSummaryAllPartsConfirmed() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 100, result: .confirmed)
        ])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Confirmed 100 of 100 sats.")
    }

    func testSummaryConfirmedWithOneUnknown() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 70, result: .confirmed),
            BoostPartResult(name: "Bob", kind: .keysend, sats: 30, result: .unknown)
        ])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Confirmed 70 of 100 sats. 1 unknown.")
    }

    func testSummaryConfirmedWithOneFailed() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 70, result: .confirmed),
            BoostPartResult(name: "Bob", kind: .keysend, sats: 30, result: .failed)
        ])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Confirmed 70 of 100 sats. 1 failed.")
    }

    func testSummaryConfirmedWithOneUnknownAndOneFailed() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 50, result: .confirmed),
            BoostPartResult(name: "Bob", kind: .keysend, sats: 30, result: .unknown),
            BoostPartResult(name: "Carl", kind: .keysend, sats: 20, result: .failed)
        ])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Confirmed 50 of 100 sats. 1 unknown. 1 failed.")
    }

    func testSummaryNoConfirmedPartWithTwoUnknown() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 50, result: .unknown),
            BoostPartResult(name: "Bob", kind: .keysend, sats: 50, result: .unknown)
        ])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Not known. 2 payments have no result.")
    }

    func testSummaryNoConfirmedPartWithOneUnknownAndOneFailed() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 50, result: .unknown),
            BoostPartResult(name: "Bob", kind: .keysend, sats: 50, result: .failed)
        ])
        XCTAssertEqual(
            BoostHistoryText.summary(for: entry), "Not known. 1 payments have no result. 1 failed."
        )
    }

    func testSummaryNoPartIsFailed() {
        let entry = entry(sats: 100, parts: [])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Failed. No payment was confirmed.")
    }

    func testSummaryAllPartsFailed() {
        let entry = entry(sats: 100, parts: [
            BoostPartResult(name: "Alice", kind: .keysend, sats: 100, result: .failed)
        ])
        XCTAssertEqual(BoostHistoryText.summary(for: entry), "Failed. No payment was confirmed.")
    }

    // MARK: - BoostHistoryText.label

    func testLabelForEachResult() {
        XCTAssertEqual(BoostHistoryText.label(for: .confirmed), "Confirmed")
        XCTAssertEqual(BoostHistoryText.label(for: .failed), "Failed")
        XCTAssertEqual(BoostHistoryText.label(for: .unknown), "Unknown")
    }

    // MARK: - BoostHistoryText.path

    func testPathTextForALightningAddressPart() {
        XCTAssertEqual(
            BoostHistoryText.path(for: BoostPartResult(
                name: nil, kind: .lightningAddress, sats: 1, result: .confirmed, path: .keysend
            )),
            "Keysend"
        )
        XCTAssertEqual(
            BoostHistoryText.path(for: BoostPartResult(
                name: nil, kind: .lightningAddress, sats: 1, result: .confirmed, path: .invoice
            )),
            "Invoice"
        )
        XCTAssertNil(BoostHistoryText.path(for: BoostPartResult(name: nil, kind: .lightningAddress, sats: 1, result: .confirmed)))
        XCTAssertNil(BoostHistoryText.path(for: BoostPartResult(name: nil, kind: .keysend, sats: 1, result: .confirmed)))
    }

    // MARK: - BoostHistoryText.reason

    private func failedPart(_ failure: BoostFailure?) -> BoostPartResult {
        BoostPartResult(name: nil, kind: .keysend, sats: 10, result: .failed, failure: failure)
    }

    func testReasonForEachFailure() {
        XCTAssertEqual(
            BoostHistoryText.reason(for: failedPart(.walletError(code: "PAYMENT_FAILED", message: "No route"))),
            "Wallet error PAYMENT_FAILED: No route"
        )
        XCTAssertEqual(BoostHistoryText.reason(for: failedPart(.unsupported)), "The wallet does not support this payment.")
        XCTAssertEqual(BoostHistoryText.reason(for: failedPart(.invalidResponse)), "The wallet answer was not valid.")
        XCTAssertEqual(BoostHistoryText.reason(for: failedPart(.notSent)), "The payment was not sent.")
        XCTAssertEqual(BoostHistoryText.reason(for: failedPart(.lightningAddress)), "The lightning address request failed.")
        XCTAssertNil(BoostHistoryText.reason(for: failedPart(nil)))
    }
}
