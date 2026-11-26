import Foundation

/// An image format that the app accepts for track artwork.
public enum ArtworkFormat: Equatable, Sendable {
    case jpeg, png, gif
}

/// The rules for track artwork data and cache keys.
/// ADR 0008 §Artwork names the rules for relay images.
/// ADR 0015 names the rules for URL images.
public enum ArtworkPolicy {
    /// The largest number of bytes accepted for a relay image.
    public static let relayMaximumBytes = 524_288

    /// The largest number of bytes accepted for a URL image.
    public static let urlMaximumBytes = 41_943_040

    private static let jpegSignature: [UInt8] = [0xFF, 0xD8, 0xFF]
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    private static let gif87Signature: [UInt8] = Array("GIF87a".utf8)
    private static let gif89Signature: [UInt8] = Array("GIF89a".utf8)

    /// The format from the first bytes, or nil.
    /// The check does not decode the image.
    public static func format(of data: Data) -> ArtworkFormat? {
        if hasSignature(data, jpegSignature) {
            return .jpeg
        }
        if hasSignature(data, pngSignature) {
            return .png
        }
        if hasSignature(data, gif87Signature) || hasSignature(data, gif89Signature) {
            return .gif
        }
        return nil
    }

    /// Relay images: JPEG or PNG, a maximum of relayMaximumBytes. URL images: JPEG, PNG or GIF, a maximum of urlMaximumBytes.
    public static func accepts(_ data: Data, for artwork: TrackDisplay.Artwork) -> Bool {
        guard data.count <= maximumBytes(for: artwork), let format = format(of: data) else {
            return false
        }
        switch artwork {
        case .relay:
            return format == .jpeg || format == .png
        case .url:
            return true
        }
    }

    /// The largest number of bytes accepted for the artwork source.
    public static func maximumBytes(for artwork: TrackDisplay.Artwork) -> Int {
        switch artwork {
        case .relay:
            return relayMaximumBytes
        case .url:
            return urlMaximumBytes
        }
    }

    /// Gives the cache key for the artwork.
    /// A relay image uses its hash. A URL image uses its full address.
    public static func cacheKey(for artwork: TrackDisplay.Artwork) -> String {
        switch artwork {
        case .relay(let sha256, _):
            return "sha256:\(sha256)"
        case .url(let url):
            return "url:\(url.absoluteString)"
        }
    }

    private static func hasSignature(_ data: Data, _ signature: [UInt8]) -> Bool {
        guard data.count >= signature.count else {
            return false
        }
        return data.prefix(signature.count).elementsEqual(signature)
    }
}
