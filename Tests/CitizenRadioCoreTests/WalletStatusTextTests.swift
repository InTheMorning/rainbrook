import Foundation
import XCTest
@testable import CitizenRadioCore

/// An error that is not a `NWCConnection.ParseError` and not a `NWCClient.Error`.
private struct OtherError: Error {}

final class WalletStatusTextTests: XCTestCase {
    // MARK: - connected

    func testConnectedWithAliasShowsTheAliasAndTheMethodCount() {
        let info = WalletInfo(alias: "Alby Hub", methods: ["get_info", "pay_keysend"], encryption: "nip44_v2")
        XCTAssertEqual(WalletStatusText.connected(info), "Connected to Alby Hub. 2 methods available.")
    }

    func testConnectedWithoutAliasShowsAGenericGreeting() {
        let info = WalletInfo(alias: nil, methods: ["get_info"], encryption: "nip44_v2")
        XCTAssertEqual(WalletStatusText.connected(info), "Connected to the wallet. 1 methods available.")
    }

    // MARK: - keysendWarning

    func testKeysendWarningIsNilWhenTheWalletSupportsKeysend() {
        let info = WalletInfo(alias: nil, methods: ["get_info", "pay_keysend"], encryption: "nip44_v2")
        XCTAssertNil(WalletStatusText.keysendWarning(info))
    }

    func testKeysendWarningWhenTheWalletDoesNotSupportKeysend() {
        let info = WalletInfo(alias: nil, methods: ["get_info"], encryption: "nip44_v2")
        XCTAssertEqual(
            WalletStatusText.keysendWarning(info),
            "This wallet does not support keysend. Streaming payments need keysend."
        )
    }

    // MARK: - failure, NWCConnection.ParseError

    func testFailureWithAParseErrorUsesItsErrorDescription() {
        XCTAssertEqual(WalletStatusText.failure(NWCConnection.ParseError.scheme), "This is not a Nostr Wallet Connect link.")
        XCTAssertEqual(WalletStatusText.failure(NWCConnection.ParseError.publicKey), "The wallet key in the link is not correct.")
        XCTAssertEqual(
            WalletStatusText.failure(NWCConnection.ParseError.relay),
            "The link must contain a secure relay address (wss)."
        )
        XCTAssertEqual(WalletStatusText.failure(NWCConnection.ParseError.secret), "The secret in the link is not correct.")
    }

    // MARK: - failure, NWCClient.Error

    func testFailureWithNoInfoEvent() {
        XCTAssertEqual(
            WalletStatusText.failure(NWCClient.Error.noInfoEvent),
            "The wallet did not publish its information. Examine the connection in your wallet."
        )
    }

    func testFailureWithUnsupportedEncryption() {
        XCTAssertEqual(
            WalletStatusText.failure(NWCClient.Error.unsupportedEncryption),
            "The wallet uses an encryption that CitizenRadio does not support."
        )
    }

    func testFailureWithRelayRejected() {
        XCTAssertEqual(
            WalletStatusText.failure(NWCClient.Error.relayRejected("duplicate: already have this event")),
            "The relay did not accept the request."
        )
    }

    func testFailureWithWalletError() {
        XCTAssertEqual(
            WalletStatusText.failure(NWCClient.Error.walletError(code: "UNAUTHORIZED", message: "no permission")),
            "The wallet returned the error UNAUTHORIZED."
        )
    }

    func testFailureWithInvalidResponse() {
        XCTAssertEqual(
            WalletStatusText.failure(NWCClient.Error.invalidResponse),
            "CitizenRadio cannot read the response of the wallet."
        )
    }

    func testFailureWithTimeout() {
        XCTAssertEqual(
            WalletStatusText.failure(NWCClient.Error.timeout),
            "The wallet did not answer in 10 seconds."
        )
    }

    // MARK: - failure, any other error

    func testStorageFailureNamesTheKeychain() {
        XCTAssertEqual(
            WalletStatusText.storageFailure,
            "CitizenRadio cannot access the wallet connection in the Keychain."
        )
    }

    func testFailureWithAnyOtherErrorShowsAGenericRelayMessage() {
        XCTAssertEqual(WalletStatusText.failure(OtherError()), "CitizenRadio cannot connect to the relay.")
    }
}
