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
}
