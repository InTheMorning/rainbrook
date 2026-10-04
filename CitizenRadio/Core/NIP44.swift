import Crypto
import CryptoExtras
import Foundation
import P256K

/// NIP-44 version 2 encryption for Nostr direct messages.
///
/// The method derives a conversation key from an elliptic curve
/// Diffie-Hellman shared secret. It then derives a new set of message keys
/// for each nonce with HKDF. It encrypts with ChaCha20, and it tags the
/// result with HMAC-SHA256. This type implements version 2 only.
public enum NIP44 {
    /// An error in a NIP-44 operation.
    ///
    /// No case carries a key, a plaintext, or a shared secret.
    public enum Error: Swift.Error, Equatable {
        /// A secret key or a public key is not a correct secp256k1 key.
        case invalidKey
        /// The payload is not correct base64, or its shape is incorrect.
        case invalidPayload
        /// The MAC does not agree with the payload.
        case invalidMAC
        /// The decrypted padding does not agree with the NIP-44 padding rule.
        case invalidPadding
        /// The plaintext length is not between 1 and 65535 bytes.
        case messageLength
    }

    /// The version byte of a NIP-44 version 2 payload.
    private static let version: UInt8 = 0x02

    /// The salt for the HKDF extract step, as UTF-8 bytes.
    private static let salt = Data("nip44-v2".utf8)

    /// The byte length of the three message keys together.
    private static let messageKeysLength = 76

    /// The byte length of the nonce and of the MAC.
    private static let fixedFieldLength = 32

    /// Derives the 32-byte conversation key for a secret key and a peer public key.
    ///
    /// The shared secret is the x-coordinate of the elliptic curve
    /// Diffie-Hellman point. The peer public key is an x-only Nostr key, so
    /// this method builds a compressed key with an assumed even Y coordinate
    /// before key agreement.
    public static func conversationKey(secretKey: String, publicKey: String) throws -> Data {
        let sharedX = try sharedXCoordinate(secretKey: secretKey, publicKey: publicKey)
        let extracted = HKDF<Crypto.SHA256>.extract(inputKeyMaterial: SymmetricKey(data: sharedX), salt: salt)
        return extracted.withUnsafeBytes { Data($0) }
    }

    /// Encrypts `plaintext` with a new random 32-byte nonce.
    public static func encrypt(_ plaintext: String, conversationKey: Data) throws -> String {
        try encrypt(plaintext, conversationKey: conversationKey, nonce: Data(randomBytes(count: fixedFieldLength)))
    }

    /// Encrypts `plaintext` with the given 32-byte nonce.
    ///
    /// A test uses this entry point to compare the result with an official
    /// NIP-44 test vector. Each vector gives a fixed nonce.
    static func encrypt(_ plaintext: String, conversationKey: Data, nonce: Data) throws -> String {
        guard conversationKey.count == fixedFieldLength, nonce.count == fixedFieldLength else {
            throw Error.invalidKey
        }
        let plainBytes = Array(plaintext.utf8)
        guard plainBytes.count >= 1, plainBytes.count <= 65535 else {
            throw Error.messageLength
        }

        let padded = pad(plainBytes)
        let keys = messageKeys(conversationKey: conversationKey, nonce: nonce)
        let chachaNonce = try Insecure.ChaCha20CTR.Nonce(data: keys.chachaNonce)
        let ciphertext = try Insecure.ChaCha20CTR.encrypt(padded, using: keys.chachaKey, nonce: chachaNonce)
        let mac = Data(HMAC<Crypto.SHA256>.authenticationCode(for: nonce + ciphertext, using: keys.hmacKey))

        var payload = Data([version])
        payload.append(nonce)
        payload.append(ciphertext)
        payload.append(mac)
        return payload.base64EncodedString()
    }

    /// Decrypts a NIP-44 version 2 payload with the given conversation key.
    ///
    /// This method compares the MAC in constant time, before it decrypts
    /// anything. A payload that starts with `#` names a different
    /// encryption version. This method rejects that payload, and it throws
    /// `.invalidPayload`.
    public static func decrypt(_ payload: String, conversationKey: Data) throws -> String {
        guard conversationKey.count == fixedFieldLength else {
            throw Error.invalidKey
        }
        guard !payload.hasPrefix("#") else {
            throw Error.invalidPayload
        }
        guard let payloadBytes = Data(base64Encoded: payload) else {
            throw Error.invalidPayload
        }

        let minimumLength = 1 + fixedFieldLength + fixedFieldLength + fixedFieldLength
        guard payloadBytes.count >= minimumLength, payloadBytes.first == version else {
            throw Error.invalidPayload
        }

        let bytes = Array(payloadBytes)
        let nonce = Data(bytes[1..<(1 + fixedFieldLength)])
        let macStart = bytes.count - fixedFieldLength
        let ciphertext = Data(bytes[(1 + fixedFieldLength)..<macStart])
        let mac = Data(bytes[macStart...])

        let keys = messageKeys(conversationKey: conversationKey, nonce: nonce)
        guard HMAC<Crypto.SHA256>.isValidAuthenticationCode(mac, authenticating: nonce + ciphertext, using: keys.hmacKey)
        else {
            throw Error.invalidMAC
        }

        let chachaNonce = try Insecure.ChaCha20CTR.Nonce(data: keys.chachaNonce)
        let padded = try Insecure.ChaCha20CTR.encrypt(ciphertext, using: keys.chachaKey, nonce: chachaNonce)
        return try unpad(padded)
    }

    /// The padded length for a plaintext of `length` bytes, as NIP-44 defines it.
    ///
    /// A length of 32 bytes or less always pads to 32 bytes. A longer length
    /// pads to the next chunk boundary above its own power-of-two range.
    static func paddedLength(_ length: Int) -> Int {
        if length <= 32 {
            return 32
        }
        let belowLength = length - 1
        let highestBit = Int.bitWidth - belowLength.leadingZeroBitCount
        let nextPower = 1 << highestBit
        let chunk = nextPower <= 256 ? 32 : nextPower / 8
        return chunk * (belowLength / chunk + 1)
    }

    /// Computes the x-coordinate of the elliptic curve Diffie-Hellman shared
    /// point for a secret key and a peer public key.
    ///
    /// `sharedSecretFromKeyAgreement` gives a 33-byte compressed point. This
    /// method drops the first byte and keeps the 32-byte x-coordinate only.
    private static func sharedXCoordinate(secretKey: String, publicKey: String) throws -> Data {
        guard let secretBytes = NostrKeys.hexBytes(secretKey), secretBytes.count == 32,
              let peerXBytes = NostrKeys.hexBytes(publicKey), peerXBytes.count == 32
        else {
            throw Error.invalidKey
        }
        do {
            let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: secretBytes)
            let peerKey = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: [0x02] + peerXBytes, format: .compressed
            )
            let sharedPoint = privateKey.sharedSecretFromKeyAgreement(with: peerKey, format: .compressed)
            return sharedPoint.withUnsafeBytes { Data($0.dropFirst()) }
        } catch {
            throw Error.invalidKey
        }
    }

    /// The ChaCha20 key, the ChaCha20 nonce, and the HMAC key for one message.
    ///
    /// These come from an HKDF expand step. The key is the conversation
    /// key. The info is the message nonce. The length is 76 bytes.
    private static func messageKeys(
        conversationKey: Data, nonce: Data
    ) -> (chachaKey: SymmetricKey, chachaNonce: Data, hmacKey: SymmetricKey) {
        let expandedKey = HKDF<Crypto.SHA256>.expand(
            pseudoRandomKey: conversationKey, info: nonce, outputByteCount: messageKeysLength
        )
        let expanded = expandedKey.withUnsafeBytes { Data($0) }
        return (
            chachaKey: SymmetricKey(data: expanded[0..<32]),
            chachaNonce: Data(expanded[32..<44]),
            hmacKey: SymmetricKey(data: expanded[44..<76])
        )
    }

    /// Adds the 2-byte big-endian length prefix and the zero padding to `plaintext`.
    private static func pad(_ plaintext: [UInt8]) -> Data {
        let total = paddedLength(plaintext.count)
        var result = Data(capacity: 2 + total)
        result.append(UInt8(plaintext.count >> 8))
        result.append(UInt8(plaintext.count & 0xFF))
        result.append(contentsOf: plaintext)
        result.append(Data(repeating: 0, count: total - plaintext.count))
        return result
    }

    /// Removes the padding from a decrypted buffer and gives back the plaintext.
    ///
    /// This method checks the length prefix and the total length against
    /// `paddedLength`, as NIP-44 requires.
    private static func unpad(_ padded: Data) throws -> String {
        guard padded.count >= 2 else {
            throw Error.invalidPadding
        }
        let bytes = Array(padded)
        let length = Int(bytes[0]) << 8 | Int(bytes[1])
        guard length > 0, length <= 65535, bytes.count == 2 + paddedLength(length) else {
            throw Error.invalidPadding
        }
        let plaintextBytes = bytes[2..<(2 + length)]
        guard let text = String(bytes: plaintextBytes, encoding: .utf8) else {
            throw Error.invalidPadding
        }
        return text
    }

    /// Gives `count` random bytes from the system random number generator.
    private static func randomBytes(count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
    }
}
