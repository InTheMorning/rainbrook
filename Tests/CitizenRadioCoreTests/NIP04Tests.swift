import Foundation
import XCTest
@testable import CitizenRadioCore

final class NIP04Tests: XCTestCase {
    /// A secret key known to be a correct secp256k1 scalar (BIP-340 vector 0).
    private let secretOne = "0000000000000000000000000000000000000000000000000000000000000001"

    /// A second secret key known to be a correct secp256k1 scalar.
    private let secretTwo = "0000000000000000000000000000000000000000000000000000000000000002"

    func testRoundTripBetweenTwoKeyPairs() throws {
        let publicOne = try NostrKeys.publicKey(forSecret: secretOne)
        let publicTwo = try NostrKeys.publicKey(forSecret: secretTwo)

        let payload = try NIP04.encrypt("hello wallet", secretKey: secretOne, publicKey: publicTwo)
        let plaintext = try NIP04.decrypt(payload, secretKey: secretTwo, publicKey: publicOne)
        XCTAssertEqual(plaintext, "hello wallet")
    }

    func testPayloadHasTheIVShape() throws {
        let publicTwo = try NostrKeys.publicKey(forSecret: secretTwo)
        let payload = try NIP04.encrypt("hello wallet", secretKey: secretOne, publicKey: publicTwo)

        let parts = payload.components(separatedBy: "?iv=")
        XCTAssertEqual(parts.count, 2, "The payload must have exactly one ?iv= marker.")
        XCTAssertNotNil(Data(base64Encoded: parts[0]), "The ciphertext part must be correct base64.")

        let ivData = try XCTUnwrap(Data(base64Encoded: parts[1]))
        XCTAssertEqual(ivData.count, 16, "The initialization vector must be 16 bytes.")
    }

    func testFixedIVGivesTheExpectedSuffix() throws {
        let iv = Data(repeating: 0x01, count: 16)
        let publicTwo = try NostrKeys.publicKey(forSecret: secretTwo)
        let payload = try NIP04.encrypt("fixed iv", secretKey: secretOne, publicKey: publicTwo, iv: iv)
        XCTAssertTrue(payload.hasSuffix("?iv=" + iv.base64EncodedString()))
    }

    func testChangedPayloadDoesNotGiveThePlaintext() throws {
        let publicOne = try NostrKeys.publicKey(forSecret: secretOne)
        let publicTwo = try NostrKeys.publicKey(forSecret: secretTwo)

        let payload = try NIP04.encrypt("hello wallet", secretKey: secretOne, publicKey: publicTwo)
        let parts = payload.components(separatedBy: "?iv=")
        var cipherBytes = try XCTUnwrap(Data(base64Encoded: parts[0]))
        cipherBytes[0] ^= 0xFF
        let changed = cipherBytes.base64EncodedString() + "?iv=" + parts[1]

        // A changed ciphertext must not decrypt to the initial plaintext.
        // The call must throw an error, or it must give a different
        // string.
        if let result = try? NIP04.decrypt(changed, secretKey: secretTwo, publicKey: publicOne) {
            XCTAssertNotEqual(result, "hello wallet")
        }
    }

    func testMalformedPayloadThrowsInvalidPayload() throws {
        XCTAssertThrowsError(try NIP04.decrypt("not a payload", secretKey: secretOne, publicKey: secretTwo)) { error in
            XCTAssertEqual(error as? NIP04.Error, .invalidPayload)
        }
    }
}
