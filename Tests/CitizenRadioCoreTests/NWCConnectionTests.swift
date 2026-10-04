import Foundation
import XCTest
@testable import CitizenRadioCore

final class NWCConnectionTests: XCTestCase {
    private let walletKey = String(repeating: "abcdef0123456789", count: 4)
    private let secret = String(repeating: "123456789abcdef0", count: 4)

    func testParsesValidURIWithOneRelayAndLowercasesValues() throws {
        let uri = "nostr+walletconnect://\(walletKey.uppercased())?relay=wss://relay.example.com&secret=\(secret.uppercased())"
        let connection = try NWCConnection(uri: uri)
        XCTAssertEqual(connection.walletPublicKey, walletKey)
        XCTAssertEqual(connection.secret, secret)
        XCTAssertEqual(connection.relays, [URL(string: "wss://relay.example.com")!])
        XCTAssertNil(connection.lud16)
    }

    func testParsesValidURIWithTwoRelaysInSequence() throws {
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss://relay-one.example.com&relay=wss://relay-two.example.com&secret=\(secret)"
        let connection = try NWCConnection(uri: uri)
        XCTAssertEqual(connection.relays, [
            URL(string: "wss://relay-one.example.com")!,
            URL(string: "wss://relay-two.example.com")!
        ])
    }

    func testParsesPercentEncodedRelay() throws {
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss%3A%2F%2Frelay.example.com&secret=\(secret)"
        let connection = try NWCConnection(uri: uri)
        XCTAssertEqual(connection.relays, [URL(string: "wss://relay.example.com")!])
    }

    func testRejectsWrongScheme() {
        let uri = "https://\(walletKey)?relay=wss://relay.example.com&secret=\(secret)"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            XCTAssertEqual(error as? NWCConnection.ParseError, .scheme)
        }
    }

    func testRejectsShortPublicKey() {
        let shortKey = String(walletKey.dropLast())
        let uri = "nostr+walletconnect://\(shortKey)?relay=wss://relay.example.com&secret=\(secret)"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            XCTAssertEqual(error as? NWCConnection.ParseError, .publicKey)
        }
    }

    func testRejectsMissingRelay() {
        let uri = "nostr+walletconnect://\(walletKey)?secret=\(secret)"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            XCTAssertEqual(error as? NWCConnection.ParseError, .relay)
        }
    }

    func testRejectsInsecureRelay() {
        let uri = "nostr+walletconnect://\(walletKey)?relay=ws://relay.example.com&secret=\(secret)"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            XCTAssertEqual(error as? NWCConnection.ParseError, .relay)
        }
    }

    func testRejectsMissingSecret() {
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss://relay.example.com"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            XCTAssertEqual(error as? NWCConnection.ParseError, .secret)
        }
    }

    func testRejectsZeroSecret() {
        let zeroSecret = String(repeating: "0", count: 64)
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss://relay.example.com&secret=\(zeroSecret)"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            XCTAssertEqual(error as? NWCConnection.ParseError, .secret)
        }
    }

    func testRoundTripsThroughTheCanonicalURI() throws {
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss://relay-one.example.com&relay=wss://relay-two.example.com&secret=\(secret)&lud16=user@example.com"
        let connection = try NWCConnection(uri: uri)
        let roundTripped = try NWCConnection(uri: connection.uri)
        XCTAssertEqual(roundTripped, connection)
    }

    func testRoundTripsARelayWithItsOwnQuery() throws {
        let relay = "wss%3A%2F%2Frelay.example.com%2Fv1%3Ftoken%3Da%26b%3Dc"
        let text = "nostr+walletconnect://\(String(repeating: "b", count: 64))?relay=\(relay)&secret=\(String(repeating: "1", count: 64))"
        let connection = try NWCConnection(uri: text)
        XCTAssertEqual(connection.relays.first?.absoluteString, "wss://relay.example.com/v1?token=a&b=c")
        XCTAssertEqual(try NWCConnection(uri: connection.uri), connection)
    }

    func testDescriptionsHideTheSecret() throws {
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss://relay.example.com&secret=\(secret)"
        let connection = try NWCConnection(uri: uri)
        XCTAssertFalse(String(describing: connection).contains(secret))
        XCTAssertFalse(String(reflecting: connection).contains(secret))
        var dumped = ""
        dump(connection, to: &dumped)
        XCTAssertFalse(dumped.contains(secret))
    }

    func testErrorDescriptionsDoNotContainTheInputURI() {
        let uri = "https://\(walletKey)?relay=wss://relay.example.com&secret=\(secret)"
        XCTAssertThrowsError(try NWCConnection(uri: uri)) { error in
            let message = (error as? NWCConnection.ParseError)?.errorDescription ?? ""
            XCTAssertFalse(message.contains(uri))
        }
    }

    func testWalletSummaryGivesRelayHostKeyPrefixAndLud16() throws {
        let uri = "nostr+walletconnect://\(walletKey)?relay=wss://relay.example.com&secret=\(secret)&lud16=user@example.com"
        let connection = try NWCConnection(uri: uri)
        let summary = WalletSummary(connection)
        XCTAssertEqual(summary.relayHost, "relay.example.com")
        XCTAssertEqual(summary.walletKeyPrefix, String(walletKey.prefix(8)))
        XCTAssertEqual(summary.lud16, "user@example.com")
    }
}
