import XCTest
@testable import CitizenRadioCore

/// ADR 0022 §The playback log: the log keeps the last 500 events in sequence.
final class PlaybackLogTests: XCTestCase {
    private func entry(_ index: Int) -> PlaybackLog.Entry {
        PlaybackLog.Entry(date: Date(timeIntervalSince1970: 1_800_000_000 + Double(index)), text: "Event \(index)")
    }

    func testAddKeepsTheLast500() {
        var log = PlaybackLog()
        for index in 1...501 {
            log.add(entry(index))
        }
        XCTAssertEqual(log.entries.count, 500)
        XCTAssertEqual(log.entries.first, entry(2))
        XCTAssertEqual(log.entries.last, entry(501))
    }

    func testClearRemovesAllEntries() {
        var log = PlaybackLog(entries: [entry(1), entry(2)])
        log.clear()
        XCTAssertTrue(log.entries.isEmpty)
    }

    func testTextGivesOneLineForEachEntry() {
        let log = PlaybackLog(entries: [
            PlaybackLog.Entry(date: Date(timeIntervalSince1970: 1_800_000_000.25), text: "ICY: Artist - Title"),
            PlaybackLog.Entry(date: Date(timeIntervalSince1970: 1_800_000_061), text: "Stall: no item")
        ])
        XCTAssertEqual(
            log.text(),
            "2027-01-15T08:00:00.250Z ICY: Artist - Title\n2027-01-15T08:01:01.000Z Stall: no item"
        )
    }

    func testEncodeAndDecodeGiveTheSameLog() throws {
        let log = PlaybackLog(entries: [entry(1), entry(2), entry(3)])
        let decoded = try PlaybackLog.decode(log.encoded())
        XCTAssertEqual(decoded, log)
    }

    func testInitKeepsTheLast500() {
        let log = PlaybackLog(entries: (1...600).map(entry))
        XCTAssertEqual(log.entries.count, 500)
        XCTAssertEqual(log.entries.first, entry(101))
        XCTAssertEqual(log.entries.last, entry(600))
    }
}
