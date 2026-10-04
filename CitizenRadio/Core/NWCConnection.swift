import Foundation

/// A parsed and validated Nostr Wallet Connect (NWC) URI.
/// ADR 0007 names the fields that this type must validate and store.
public struct NWCConnection: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public enum ParseError: Error, Equatable, LocalizedError {
        case scheme, publicKey, relay, secret

        public var errorDescription: String? {
            switch self {
            case .scheme:
                return "This is not a Nostr Wallet Connect link."
            case .publicKey:
                return "The wallet key in the link is not correct."
            case .relay:
                return "The link must contain a secure relay address (wss)."
            case .secret:
                return "The secret in the link is not correct."
            }
        }
    }

    public let walletPublicKey: String
    public let relays: [URL]
    public let secret: String
    public let lud16: String?

    public init(uri: String) throws {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "nostr+walletconnect" else {
            throw ParseError.scheme
        }
        guard let host = components.host, let key = Self.hex(host, length: 64) else {
            throw ParseError.publicKey
        }
        let queryItems = components.queryItems ?? []
        let relayItems = queryItems.filter { $0.name == "relay" }
        guard !relayItems.isEmpty else { throw ParseError.relay }
        var relays: [URL] = []
        for item in relayItems {
            guard let value = item.value,
                  let relayComponents = URLComponents(string: value),
                  relayComponents.scheme?.lowercased() == "wss",
                  let relayHost = relayComponents.host, !relayHost.isEmpty,
                  let relayURL = relayComponents.url else {
                throw ParseError.relay
            }
            relays.append(relayURL)
        }
        guard let secretValue = queryItems.first(where: { $0.name == "secret" })?.value,
              let secret = Self.hex(secretValue, length: 64),
              secret != Self.zeroSecret else {
            throw ParseError.secret
        }
        let lud16Value = queryItems.first(where: { $0.name == "lud16" })?.value
        self.walletPublicKey = key
        self.relays = relays
        self.secret = secret
        self.lud16 = (lud16Value?.isEmpty ?? true) ? nil : lud16Value
    }

    /// The canonical URI for storage. It gives an equal value when parsed again.
    public var uri: String {
        var components = URLComponents()
        components.scheme = "nostr+walletconnect"
        components.host = walletPublicKey
        var items = relays.map { Self.encodedItem("relay", $0.absoluteString) }
        items.append(Self.encodedItem("secret", secret))
        if let lud16 {
            items.append(Self.encodedItem("lud16", lud16))
        }
        // Apple and Linux Foundation encode "&" and "=" in queryItems differently.
        // Encode each value here, so the two platforms give the same URI.
        components.percentEncodedQueryItems = items
        return components.string ?? ""
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encodedItem(_ name: String, _ value: String) -> URLQueryItem {
        URLQueryItem(name: name, value: value.addingPercentEncoding(withAllowedCharacters: unreserved))
    }

    public var description: String {
        "NWCConnection(walletPublicKey: \(keyPrefix), relays: \(relayHosts))"
    }

    public var debugDescription: String {
        "NWCConnection(walletPublicKey: \(keyPrefix), relays: \(relayHosts), lud16: \(lud16 ?? "nil"))"
    }

    public var customMirror: Mirror {
        Mirror(self, children: ["walletPublicKey": keyPrefix, "relays": relayHosts])
    }

    private var keyPrefix: String {
        String(walletPublicKey.prefix(8))
    }

    private var relayHosts: [String] {
        relays.compactMap(\.host)
    }

    private static let zeroSecret = String(repeating: "0", count: 64)

    /// Checks that `text` has the exact hexadecimal length, and returns the lowercase form.
    /// Returns nil when `text` has the wrong length or holds a character that is not hexadecimal.
    private static func hex(_ text: String, length: Int) -> String? {
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard text.count == length, text.unicodeScalars.allSatisfy(allowed.contains) else {
            return nil
        }
        return text.lowercased()
    }
}
