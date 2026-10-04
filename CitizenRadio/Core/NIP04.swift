import Crypto
import CryptoExtras
import Foundation
import P256K

/// NIP-04 encryption for an older Nostr Wallet Connect wallet.
///
/// NIP-44 is the preferred method. This type exists only for a wallet
/// that does not use NIP-44.
public enum NIP04 {
    /// An error in a NIP-04 operation.
    ///
    /// No case carries a key, a plaintext, or a shared secret.
    public enum Error: Swift.Error, Equatable {
        /// A secret key or a public key is not a correct secp256k1 key.
        case invalidKey
        /// The payload does not have the `base64ciphertext?iv=base64iv` shape.
        case invalidPayload
    }

    /// Encrypts `plaintext` with a new random 16-byte initialization vector.
    public static func encrypt(_ plaintext: String, secretKey: String, publicKey: String) throws -> String {
        try encrypt(plaintext, secretKey: secretKey, publicKey: publicKey, iv: Data(AES._CBC.IV()))
    }

    /// Encrypts `plaintext` with the given 16-byte initialization vector.
    ///
    /// A test uses this entry point to examine the payload shape, with a
    /// fixed initialization vector.
    static func encrypt(_ plaintext: String, secretKey: String, publicKey: String, iv: Data) throws -> String {
        let shared = try sharedXCoordinate(secretKey: secretKey, publicKey: publicKey)
        let key = SymmetricKey(data: shared)
        do {
            let ivValue = try AES._CBC.IV(ivBytes: iv)
            let ciphertext = try AES._CBC.encrypt(Data(plaintext.utf8), using: key, iv: ivValue)
            return ciphertext.base64EncodedString() + "?iv=" + iv.base64EncodedString()
        } catch {
            throw Error.invalidPayload
        }
    }

    /// Decrypts a NIP-04 payload with the given secret key and peer public key.
    public static func decrypt(_ payload: String, secretKey: String, publicKey: String) throws -> String {
        let parts = payload.components(separatedBy: "?iv=")
        guard parts.count == 2,
              let ciphertext = Data(base64Encoded: parts[0]),
              let ivBytes = Data(base64Encoded: parts[1]),
              ivBytes.count == 16
        else {
            throw Error.invalidPayload
        }

        let shared = try sharedXCoordinate(secretKey: secretKey, publicKey: publicKey)
        let key = SymmetricKey(data: shared)
        do {
            let iv = try AES._CBC.IV(ivBytes: ivBytes)
            let plainData = try AES._CBC.decrypt(ciphertext, using: key, iv: iv)
            guard let text = String(data: plainData, encoding: .utf8) else {
                throw Error.invalidPayload
            }
            return text
        } catch {
            throw Error.invalidPayload
        }
    }

    /// Computes the x-coordinate of the elliptic curve Diffie-Hellman shared
    /// point for a secret key and a peer public key.
    ///
    /// NIP-04 uses this x-coordinate as the AES key, without a hash step.
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
}
