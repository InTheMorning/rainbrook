import Foundation

/// The rules for track artwork data and cache keys.
/// ADR 0008 §Artwork names these rules.
public enum ArtworkPolicy {
    /// The largest number of bytes accepted for an image.
    public static let maximumBytes = 524_288

    private static let jpegSignature: [UInt8] = [0xFF, 0xD8, 0xFF]
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Tells if the data is a JPEG image or a PNG image of an accepted number of bytes.
    /// The check reads the first bytes of the data. It does not decode the image.
    public static func accepts(_ data: Data) -> Bool {
        guard data.count <= maximumBytes else {
            return false
        }
        return hasSignature(data, jpegSignature) || hasSignature(data, pngSignature)
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
