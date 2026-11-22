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

    /// Names the live value payload for this track. ADR 0012 §The pairing names its use.
    public struct ValueIdentity: Equatable, Sendable {
        public let eventGuid: String
        public let blockGuid: String

        public init(eventGuid: String, blockGuid: String) {
            self.eventGuid = eventGuid
            self.blockGuid = blockGuid
        }
    }

    public let artist: String
    public let title: String
    public let artwork: Artwork?
    public let value: ValueIdentity?
    /// ADR 0019: the optional album. Nil when the publisher sends no album.
    public let album: String?
    /// ADR 0024: the ICY `StreamTitle` line of this state (relay key `songLine`). Nil when the relay sends none.
    public let songLine: String?

    public init(
        artist: String, title: String, artwork: Artwork?, value: ValueIdentity? = nil, album: String? = nil,
        songLine: String? = nil
    ) {
        self.artist = artist
        self.title = title
        self.artwork = artwork
        self.value = value
        self.album = album
        self.songLine = songLine
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

        // Read value {eventGuid, blockGuid}. Any other shape gives value = nil, with no throw.
        var value: ValueIdentity?
        if let valueDict = track["value"] as? [String: Any],
           let eventGuid = valueDict["eventGuid"] as? String, !eventGuid.isEmpty,
           let blockGuid = valueDict["blockGuid"] as? String, !blockGuid.isEmpty {
            value = ValueIdentity(eventGuid: eventGuid, blockGuid: blockGuid)
        }

        // ADR 0019: a non-empty string gives the album. A missing key, null, an empty
        // string or a non-string value gives nil. The album decode does not throw.
        let album: String?
        if let albumStr = track["album"] as? String, !albumStr.isEmpty {
            album = albumStr
        } else {
            album = nil
        }

        // ADR 0024: a non-empty string gives the song line. A missing key, null, an empty
        // string or a non-string value gives nil. The song line decode does not throw.
        let songLine: String?
        if let songLineStr = track["songLine"] as? String, !songLineStr.isEmpty {
            songLine = songLineStr
        } else {
            songLine = nil
        }

        return TrackDisplay(
            artist: artist, title: title, artwork: artwork, value: value, album: album, songLine: songLine
        )
    }
}
