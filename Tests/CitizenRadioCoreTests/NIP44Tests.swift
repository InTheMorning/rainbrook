import Foundation
import XCTest
@testable import CitizenRadioCore

final class NIP44Tests: XCTestCase {
    /// The `v2` section of the official NIP-44 test vector file.
    private struct V2: Decodable {
        let valid: Valid
        let invalid: Invalid
    }

    private struct Valid: Decodable {
        let get_conversation_key: [ConversationKeyVector]
        let calc_padded_len: [[Int]]
        let encrypt_decrypt: [EncryptDecryptVector]
    }

    private struct Invalid: Decodable {
        let encrypt_msg_lengths: [Int]
        let get_conversation_key: [InvalidConversationKeyVector]
        let decrypt: [InvalidDecryptVector]
    }

    private struct ConversationKeyVector: Decodable {
        let sec1: String
        let pub2: String
        let conversation_key: String
    }

    private struct InvalidConversationKeyVector: Decodable {
        let sec1: String
        let pub2: String
        let note: String
    }

    private struct EncryptDecryptVector: Decodable {
        let conversation_key: String
        let nonce: String
        let plaintext: String
        let payload: String
    }

    private struct InvalidDecryptVector: Decodable {
        let conversation_key: String
        let payload: String
        let note: String
    }

    /// Reads and decodes `Vectors/nip44.vectors.json`.
    private func loadVectors() throws -> V2 {
        let fileURL = try XCTUnwrap(
            Bundle.module.url(forResource: "nip44.vectors", withExtension: "json", subdirectory: "Vectors")
        )
        let data = try Data(contentsOf: fileURL)
        let file = try JSONDecoder().decode([String: V2].self, from: data)
        return try XCTUnwrap(file["v2"])
    }

    // MARK: - Conversation key

    func testValidConversationKeyVectors() throws {
        let vectors = try loadVectors().valid.get_conversation_key
        XCTAssertEqual(vectors.count, 35, "The vector file must have 35 valid conversation key vectors.")
        for vector in vectors {
            let key = try NIP44.conversationKey(secretKey: vector.sec1, publicKey: vector.pub2)
            XCTAssertEqual(NostrKeys.hex(Array(key)), vector.conversation_key)
        }
    }

    func testInvalidConversationKeyVectorsThrow() throws {
        let vectors = try loadVectors().invalid.get_conversation_key
        XCTAssertEqual(vectors.count, 8, "The vector file must have 8 invalid conversation key vectors.")
        for vector in vectors {
            XCTAssertThrowsError(
                try NIP44.conversationKey(secretKey: vector.sec1, publicKey: vector.pub2),
                vector.note
            )
        }
    }

    // MARK: - Padded length

    func testValidPaddedLengthVectors() throws {
        let vectors = try loadVectors().valid.calc_padded_len
        XCTAssertEqual(vectors.count, 24, "The vector file must have 24 padded length vectors.")
        for vector in vectors {
            let pair = try XCTUnwrap(vector.count == 2 ? vector : nil)
            XCTAssertEqual(NIP44.paddedLength(pair[0]), pair[1])
        }
    }

    // MARK: - Encrypt and decrypt

    func testValidEncryptDecryptVectors() throws {
        let vectors = try loadVectors().valid.encrypt_decrypt
        XCTAssertEqual(vectors.count, 10, "The vector file must have 10 encrypt-decrypt vectors.")
        for vector in vectors {
            let conversationKey = Data(try XCTUnwrap(NostrKeys.hexBytes(vector.conversation_key)))
            let nonce = Data(try XCTUnwrap(NostrKeys.hexBytes(vector.nonce)))

            let payload = try NIP44.encrypt(vector.plaintext, conversationKey: conversationKey, nonce: nonce)
            XCTAssertEqual(payload, vector.payload)

            let plaintext = try NIP44.decrypt(vector.payload, conversationKey: conversationKey)
            XCTAssertEqual(plaintext, vector.plaintext)
        }
    }

    func testInvalidMessageLengthsThrow() throws {
        let lengths = try loadVectors().invalid.encrypt_msg_lengths
        XCTAssertEqual(lengths.count, 4, "The vector file must have 4 invalid message lengths.")
        let conversationKey = Data(repeating: 0xAB, count: 32)
        for length in lengths {
            let plaintext = String(repeating: "a", count: length)
            XCTAssertThrowsError(try NIP44.encrypt(plaintext, conversationKey: conversationKey)) { error in
                XCTAssertEqual(error as? NIP44.Error, .messageLength)
            }
        }
    }

    func testInvalidDecryptVectorsThrow() throws {
        let vectors = try loadVectors().invalid.decrypt
        XCTAssertEqual(vectors.count, 12, "The vector file must have 12 invalid decrypt vectors.")
        for vector in vectors {
            let conversationKey = Data(try XCTUnwrap(NostrKeys.hexBytes(vector.conversation_key)))
            XCTAssertThrowsError(try NIP44.decrypt(vector.payload, conversationKey: conversationKey), vector.note)
        }
    }

    func testRandomNonceRoundTrip() throws {
        let conversationKey = Data(repeating: 0x11, count: 32)
        let payload = try NIP44.encrypt("hello nostr wallet connect", conversationKey: conversationKey)
        let plaintext = try NIP44.decrypt(payload, conversationKey: conversationKey)
        XCTAssertEqual(plaintext, "hello nostr wallet connect")
    }
}
