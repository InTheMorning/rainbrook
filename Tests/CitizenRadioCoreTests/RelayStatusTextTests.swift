import XCTest
@testable import CitizenRadioCore

final class RelayStatusTextTests: XCTestCase {
    func testNotFoundShowsTheAddressMessage() {
        XCTAssertEqual(
            RelayStatusText.message(for: .stopped(.notFound)),
            "The relay does not know this event. Examine the track info address."
        )
    }

    func testNotReservedShowsTheReserveMessage() {
        XCTAssertEqual(
            RelayStatusText.message(for: .stopped(.notReserved)),
            "The relay event is not reserved. Ask the stream producer to reserve it."
        )
    }

    func testWaitingShowsTheRetryMessage() {
        for seconds in EventStreamClient.backoffSeconds {
            XCTAssertEqual(
                RelayStatusText.message(for: .waiting(seconds: seconds)),
                "The relay is not available. CitizenRadio tries again."
            )
        }
    }

    func testOtherStatusesShowNoMessage() {
        XCTAssertNil(RelayStatusText.message(for: .connecting))
        XCTAssertNil(RelayStatusText.message(for: .live))
        XCTAssertNil(RelayStatusText.message(for: .stopped(.requested)))
    }

    func testNoStatusShowsNoMessage() {
        XCTAssertNil(RelayStatusText.message(for: nil))
    }
}
