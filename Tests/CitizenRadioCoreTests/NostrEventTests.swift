import Foundation
import XCTest
@testable import CitizenRadioCore

final class NostrEventTests: XCTestCase {
    /// One row of the official BIP-340 test vector CSV.
    private struct Vector {
        let secretKey: String?
        let publicKey: String
        let auxiliaryRand: String?
        let message: String
        let signature: String
        let verificationResult: Bool
    }

    /// A secret key known to be a correct secp256k1 scalar (BIP-340 vector 0).
    private let sampleSecretKey = "0000000000000000000000000000000000000000000000000000000000000003"

    /// An error in the test fixture CSV. The bundled file must not cause this error.
    private enum FixtureError: Error {
        case malformedRow
    }

    /// Reads and parses `Vectors/bip340-test-vectors.csv`.
    private func loadVectors() throws -> [Vector] {
        let fileURL = try XCTUnwrap(
            Bundle.module.url(forResource: "bip340-test-vectors", withExtension: "csv", subdirectory: "Vectors")
        )
        let text = try String(contentsOf: fileURL, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        return try lines.dropFirst().map { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 7 else { throw FixtureError.malformedRow }
            return Vector(
                secretKey: fields[1].isEmpty ? nil : fields[1].lowercased(),
                publicKey: fields[2].lowercased(),
                auxiliaryRand: fields[3].isEmpty ? nil : fields[3].lowercased(),
                message: fields[4].lowercased(),
                signature: fields[5].lowercased(),
                verificationResult: fields[6].uppercased() == "TRUE"
            )
        }
    }

    // MARK: - BIP-340 test vectors

    func testBIP340VectorsGiveThePublicKeyAndSignature() throws {
        let vectors = try loadVectors().filter { $0.secretKey != nil }
        XCTAssertEqual(vectors.count, 8, "The BIP-340 CSV must have eight vectors with a secret key.")

        for vector in vectors {
            guard let secretKey = vector.secretKey, let auxiliaryHex = vector.auxiliaryRand else {
                XCTFail("A vector with a secret key must also have auxiliary data.")
                continue
            }

            let publicKey = try NostrKeys.publicKey(forSecret: secretKey)
            XCTAssertEqual(publicKey, vector.publicKey, "Wrong public key for secret \(secretKey.prefix(8))…")

            let messageBytes = try XCTUnwrap(NostrKeys.hexBytes(vector.message))
            let auxiliaryBytes = try XCTUnwrap(NostrKeys.hexBytes(auxiliaryHex))
            let signatureBytes = try NostrKeys.sign(
                message: messageBytes, secretKey: secretKey, auxiliaryRand: auxiliaryBytes, strict: false
            )
            XCTAssertEqual(
                NostrKeys.hex(signatureBytes), vector.signature,
                "Wrong signature for secret \(secretKey.prefix(8))…"
            )
        }
    }

    func testBIP340VectorsGiveTheVerificationResult() throws {
        let vectors = try loadVectors()
        XCTAssertEqual(vectors.count, 19, "The BIP-340 CSV must have 19 vectors.")
        for (index, vector) in vectors.enumerated() {
            let result = NostrKeys.verify(
                message: try XCTUnwrap(NostrKeys.hexBytes(vector.message)),
                signature: try XCTUnwrap(NostrKeys.hexBytes(vector.signature)),
                publicKey: try XCTUnwrap(NostrKeys.hexBytes(vector.publicKey))
            )
            XCTAssertEqual(result, vector.verificationResult, "Wrong verification result for vector \(index).")
        }
    }

    func testHexRejectsSignsAndOtherCharacters() {
        XCTAssertNil(NostrKeys.hexBytes("+f"))
        XCTAssertNil(NostrKeys.hexBytes("-0"))
        XCTAssertNil(NostrKeys.hexBytes("0g"))
        XCTAssertEqual(NostrKeys.hexBytes("0aFF"), [0x0A, 0xFF])
    }

    // MARK: - Secret key validation

    func testInvalidSecretLengthThrows() {
        XCTAssertThrowsError(try NostrKeys.publicKey(forSecret: "abcd")) { error in
            XCTAssertEqual(error as? NostrKeys.KeyError, .invalidSecret)
        }
    }

    // MARK: - NIP-01 serialization

    func testSerializationEscapesPerNIP01() {
        let content = "a\"b\\c\nd/é"
        let data = NostrEvent.serialize(
            pubkey: String(repeating: "a", count: 64), createdAt: 0, kind: 1, tags: [], content: content
        )
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(text.contains(" "))
        XCTAssertFalse(text.contains("\n"))
        XCTAssertTrue(text.contains("a\\\"b\\\\c\\nd/é"), "The serialization must include the escaped content.")
        XCTAssertFalse(text.contains("\\/"), "A forward slash must stay unescaped.")
        XCTAssertFalse(text.contains("\\u00e9"), "A non-ASCII character must stay as raw UTF-8, not an escape.")
        XCTAssertFalse(text.contains("\\u00E9"), "A non-ASCII character must stay as raw UTF-8, not an escape.")
    }

    // MARK: - Signing and verification

    func testSignedEventIsValid() throws {
        let event = try NostrEvent.signed(
            kind: 1, tags: [["t", "test"]], content: "hello world", createdAt: 1_700_000_000,
            secretKey: sampleSecretKey
        )
        XCTAssertTrue(event.isValid())
    }

    func testTamperedContentIsInvalid() throws {
        let event = try NostrEvent.signed(
            kind: 1, tags: [], content: "hello world", createdAt: 1_700_000_000, secretKey: sampleSecretKey
        )
        let tampered = NostrEvent(
            id: event.id,
            pubkey: event.pubkey,
            created_at: event.created_at,
            kind: event.kind,
            tags: event.tags,
            content: "Hello world",
            sig: event.sig
        )
        XCTAssertFalse(tampered.isValid())
    }

    func testCodableRoundTripGivesAnEqualEvent() throws {
        let event = try NostrEvent.signed(
            kind: 1, tags: [["p", "abc"]], content: "round trip", createdAt: 1_700_000_001,
            secretKey: sampleSecretKey
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(NostrEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }
}
