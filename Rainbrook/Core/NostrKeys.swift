import Foundation
import P256K

/// Nostr key operations, with BIP-340 Schnorr signatures over the secp256k1 curve.
///
/// NIP-01 names a user by the 32-byte x-only public key of a secp256k1 key pair.
public enum NostrKeys {
    /// An error in a Nostr secret key.
    ///
    /// The description does not include the secret value.
    public enum KeyError: LocalizedError, Equatable {
        /// The secret is not 64 hexadecimal characters, or it is not a correct secp256k1 scalar.
        case invalidSecret

        public var errorDescription: String? {
            "The secret key must be 64 hexadecimal characters."
        }
    }

    /// The x-only public key (64 lowercase hexadecimal characters) for a secret key.
    public static func publicKey(forSecret secretHex: String) throws -> String {
        let privateKey = try schnorrPrivateKey(forSecret: secretHex)
        return hex(privateKey.xonly.bytes)
    }

    /// Signs a message with a secret key and the given BIP-340 auxiliary randomness.
    ///
    /// A Nostr event always signs its 32-byte event ID, with `strict` as `true`. A test
    /// can set `strict` to `false`. This lets the test compare results with the
    /// official BIP-340 vectors, which include messages of other lengths.
    static func sign(
        message: [UInt8],
        secretKey secretHex: String,
        auxiliaryRand: [UInt8],
        strict: Bool = true
    ) throws -> [UInt8] {
        let privateKey = try schnorrPrivateKey(forSecret: secretHex)
        var messageBytes = message
        var auxBytes = auxiliaryRand
        let signature = try auxBytes.withUnsafeMutableBytes { pointer in
            try privateKey.signature(message: &messageBytes, auxiliaryRand: pointer.baseAddress, strict: strict)
        }
        return Array(signature.dataRepresentation)
    }

    /// True only if `signature` is a correct BIP-340 signature of `message` by the x-only `publicKey`.
    /// A public key that is not on the curve gives false.
    static func verify(message: [UInt8], signature: [UInt8], publicKey: [UInt8]) -> Bool {
        guard publicKey.count == 32, signature.count == 64,
              let schnorrSignature = try? P256K.Schnorr.SchnorrSignature(dataRepresentation: signature) else {
            return false
        }
        var messageBytes = message
        return P256K.Schnorr.XonlyKey(dataRepresentation: publicKey).isValid(schnorrSignature, for: &messageBytes)
    }

    /// Builds a validated Schnorr private key from a 64-character hexadecimal secret.
    static func schnorrPrivateKey(forSecret secretHex: String) throws -> P256K.Schnorr.PrivateKey {
        guard secretHex.count == 64, let bytes = hexBytes(secretHex) else {
            throw KeyError.invalidSecret
        }
        do {
            return try P256K.Schnorr.PrivateKey(dataRepresentation: bytes)
        } catch {
            throw KeyError.invalidSecret
        }
    }

    /// The sixteen lowercase hexadecimal digits, from zero to fifteen.
    private static let hexDigits = Array("0123456789abcdef")

    /// Encodes bytes as a lowercase hexadecimal string.
    static func hex(_ bytes: [UInt8]) -> String {
        var text = ""
        text.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            text.append(hexDigits[Int(byte >> 4)])
            text.append(hexDigits[Int(byte & 0x0F)])
        }
        return text
    }

    /// Decodes a hexadecimal string to bytes.
    ///
    /// Gives `nil` if the string has an odd length or a character that is not a
    /// hexadecimal digit. Accepts uppercase and lowercase digits.
    static func hexBytes(_ text: String) -> [UInt8]? {
        // UInt8(_:radix:) also accepts a "+" or "-" sign, so check each character first.
        guard text.count.isMultiple(of: 2), text.allSatisfy(\.isHexDigit) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.count / 2)
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }
}
