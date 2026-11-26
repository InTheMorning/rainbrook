import Foundation
import XCTest
@testable import RainbrookCore

final class StreamAddressTests: XCTestCase {
    func testAcceptsDirectStreamsAndPreservesQuery() throws {
        let input = "  https://radio.example.org:8443/live.mp3?token=a%2Bb&quality=high\n"
        let address = try StreamAddress(input)
        XCTAssertEqual(address.url.absoluteString, "https://radio.example.org:8443/live.mp3?token=a%2Bb&quality=high")
        XCTAssertEqual(try StreamAddress("http://radio.example.org:8000/live").url.scheme, "http")
    }

    func testAcceptsIPv6Stream() throws {
        XCTAssertEqual(try StreamAddress("https://[2001:db8::1]:8443/live").url.port, 8443)
    }

    func testRejectsIncompleteOrUnsupportedAddresses() {
        for input in ["", "  \n", "radio.example.org/live", "ftp://radio.example.org/live",
                      "file:///tmp/audio.mp3", "https:///live", "https://", "https://radio.example.org:0/live",
                      "https://radio.example.org:65536/live", "https://radio.example.org/a b"] {
            XCTAssertThrowsError(try StreamAddress(input), input)
        }
    }

    func testRejectsCredentialsAndFragments() {
        XCTAssertThrowsError(try StreamAddress("https://user:password@radio.example.org/live")) { error in
            XCTAssertEqual(error as? StreamAddress.ValidationError, .credentials)
        }
        XCTAssertThrowsError(try StreamAddress("https://radio.example.org/live#player")) { error in
            XCTAssertEqual(error as? StreamAddress.ValidationError, .fragment)
        }
    }
}
