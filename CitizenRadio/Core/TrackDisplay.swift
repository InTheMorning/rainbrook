import Foundation

/// A track to display with metadata and artwork.
public struct TrackDisplay: Equatable, Sendable {
    public enum Artwork: Equatable, Sendable {
        case relay(sha256: String, mime: String)
        case url(URL)
    }

    public enum DecodeError: Error, Equatable {
        case invalid
    }

    public let artist: String
    public let title: String
    public let artwork: Artwork?

    public init(artist: String, title: String, artwork: Artwork?) {
        self.artist = artist
        self.title = title
        self.artwork = artwork
    }

    /// Decodes a relay display state. Gives nil for {"track": null}.
    public static func decode(_ data: Data) throws -> TrackDisplay? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let dict = json as? [String: Any] else {
            throw DecodeError.invalid
        }

        guard let trackValue = dict["track"] else {
            throw DecodeError.invalid
        }

        // "track": null gives nil
        if trackValue is NSNull {
            return nil
        }

        guard let track = trackValue as? [String: Any] else {
            throw DecodeError.invalid
        }

        let artist = (track["artist"] as? String) ?? ""
        let title = (track["title"] as? String) ?? ""

        var artwork: Artwork?
        if let artworkValue = track["artwork"] {
            if artworkValue is NSNull {
                artwork = nil
            } else if let artworkDict = artworkValue as? [String: Any] {
                if let sha256Str = artworkDict["sha256"] as? String,
                   let mimeStr = artworkDict["mime"] as? String {
                    // Validate sha256: 64 lowercase hex characters
                    guard sha256Str.count == 64,
                          sha256Str.unicodeScalars.allSatisfy({ c in
                              c.value >= 48 && c.value <= 57 || // 0-9
                                  c.value >= 97 && c.value <= 102 // a-f
                          }) else {
                        throw DecodeError.invalid
                    }

                    // Validate mime
                    guard mimeStr == "image/jpeg" || mimeStr == "image/png" else {
                        throw DecodeError.invalid
                    }

                    artwork = .relay(sha256: sha256Str, mime: mimeStr)
                } else if let urlStr = artworkDict["url"] as? String {
                    // Validate URL
                    guard let url = URL(string: urlStr) else {
                        throw DecodeError.invalid
                    }

                    let scheme = url.scheme?.lowercased() ?? ""
                    guard scheme == "http" || scheme == "https" else {
                        throw DecodeError.invalid
                    }

                    guard url.host != nil else {
                        throw DecodeError.invalid
                    }

                    guard urlStr.count <= 2048 else {
                        throw DecodeError.invalid
                    }

                    // Reject data: URLs
                    if scheme == "data" {
                        throw DecodeError.invalid
                    }

                    artwork = .url(url)
                } else {
                    throw DecodeError.invalid
                }
            } else {
                throw DecodeError.invalid
            }
        }

        return TrackDisplay(artist: artist, title: title, artwork: artwork)
    }
}
