import Crypto
import Foundation
import P256K

/// A Nostr event, as NIP-01 defines it: a signed, timestamped piece of content.
public struct NostrEvent: Codable, Equatable, Sendable {
    public let id: String
    public let pubkey: String
    public let created_at: Int
    public let kind: Int
    public let tags: [[String]]
    public let content: String
    public let sig: String

    /// The NIP-01 serialization: `[0,pubkey,created_at,kind,tags,content]` as UTF-8 JSON.
    ///
    /// The text has no spaces and no line breaks. This method builds the JSON by hand.
    /// `JSONSerialization` and `JSONEncoder` can write `/` as `\/`. NIP-01 does not
    /// allow that.
    public static func serialize(
        pubkey: String, createdAt: Int, kind: Int, tags: [[String]], content: String
    ) -> Data {
        var text = "[0,\"" + escapedJSONString(pubkey) + "\","
        text += "\(createdAt),\(kind),["
        for (tagIndex, tag) in tags.enumerated() {
            if tagIndex > 0 { text += "," }
            text += "["
            for (itemIndex, item) in tag.enumerated() {
                if itemIndex > 0 { text += "," }
                text += "\"" + escapedJSONString(item) + "\""
            }
            text += "]"
        }
        text += "],\"" + escapedJSONString(content) + "\"]"
        return Data(text.utf8)
    }

    /// Builds and signs an event. The signature uses new random auxiliary bytes.
    public static func signed(
        kind: Int, tags: [[String]], content: String, createdAt: Int, secretKey secretHex: String
    ) throws -> NostrEvent {
        try signed(
            kind: kind, tags: tags, content: content, createdAt: createdAt,
            secretKey: secretHex, auxiliaryRand: randomAuxiliaryBytes()
        )
    }

    /// Builds and signs an event with the given auxiliary bytes.
    ///
    /// A test uses this entry point to compare the signature with an official BIP-340
    /// test vector. Each vector gives fixed auxiliary bytes.
    static func signed(
        kind: Int,
        tags: [[String]],
        content: String,
        createdAt: Int,
        secretKey secretHex: String,
        auxiliaryRand: [UInt8]
    ) throws -> NostrEvent {
        let privateKey = try NostrKeys.schnorrPrivateKey(forSecret: secretHex)
        let pubkey = NostrKeys.hex(privateKey.xonly.bytes)
        let serialization = serialize(pubkey: pubkey, createdAt: createdAt, kind: kind, tags: tags, content: content)
        var idBytes = Array(SHA256.hash(data: serialization))
        var auxBytes = auxiliaryRand
        let signature = try auxBytes.withUnsafeMutableBytes { pointer in
            try privateKey.signature(message: &idBytes, auxiliaryRand: pointer.baseAddress, strict: true)
        }
        return NostrEvent(
            id: NostrKeys.hex(idBytes),
            pubkey: pubkey,
            created_at: createdAt,
            kind: kind,
            tags: tags,
            content: content,
            sig: NostrKeys.hex(Array(signature.dataRepresentation))
        )
    }

    /// True only if `id` is the SHA-256 of the serialization and `sig` is a correct
    /// BIP-340 signature of `id` by `pubkey`.
    public func isValid() -> Bool {
        guard let pubkeyBytes = NostrKeys.hexBytes(pubkey), pubkeyBytes.count == 32,
              let sigBytes = NostrKeys.hexBytes(sig), sigBytes.count == 64,
              let idBytes = NostrKeys.hexBytes(id), idBytes.count == 32
        else {
            return false
        }
        let serialization = Self.serialize(
            pubkey: pubkey, createdAt: created_at, kind: kind, tags: tags, content: content
        )
        let computedID = Array(SHA256.hash(data: serialization))
        guard computedID == idBytes else {
            return false
        }
        return NostrKeys.verify(message: computedID, signature: sigBytes, publicKey: pubkeyBytes)
    }

    /// Gives 32 random bytes from the system random number generator, for BIP-340
    /// auxiliary randomness.
    private static func randomAuxiliaryBytes() -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
    }

    /// Escapes a string with the NIP-01 rules.
    ///
    /// The method escapes only `"`, `\`, line feed, carriage return, tab, backspace and
    /// form feed. It writes all other characters as UTF-8 without change. This rule
    /// also applies to a non-ASCII character and to a forward slash.
    private static func escapedJSONString(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"":
                result += "\\\""
            case "\\":
                result += "\\\\"
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            case "\u{08}":
                result += "\\b"
            case "\u{0C}":
                result += "\\f"
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
