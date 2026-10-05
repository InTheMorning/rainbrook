import Foundation

/// Display lines from a relay or ICY track.
public struct TrackLines: Equatable, Sendable {
    /// The default title.
    public static let defaultTitle = "CitizenRadio"
    /// The default Now Playing artist.
    public static let defaultNowPlayingArtist = "Live radio"

    /// The track title.
    public let title: String
    /// The track artist.
    public let artist: String?
    /// The track artwork.
    public let artwork: TrackDisplay.Artwork?

    /// Initialize display lines.
    public init(title: String, artist: String?, artwork: TrackDisplay.Artwork?) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
    }

    /// Select a track to display.
    /// A relay track has priority. Otherwise, the ICY track. Otherwise, the default lines.
    public static func select(relay: TrackDisplay?, icy: IcyTrack?) -> TrackLines {
        if let relayTrack = relay {
            // Use relay track. Empty title gives default. Empty artist gives nil.
            let title = relayTrack.title.isEmpty ? defaultTitle : relayTrack.title
            let artist = relayTrack.artist.isEmpty ? nil : relayTrack.artist
            return TrackLines(title: title, artist: artist, artwork: relayTrack.artwork)
        } else if let icyTrack = icy {
            // Use ICY track with no artwork.
            return TrackLines(title: icyTrack.title, artist: icyTrack.artist, artwork: nil)
        } else {
            // Use default lines.
            return TrackLines(title: defaultTitle, artist: nil, artwork: nil)
        }
    }

    /// The artist text for Now Playing.
    /// Returns the artist, or "Live radio" when the artist is nil.
    public var nowPlayingArtist: String {
        artist ?? Self.defaultNowPlayingArtist
    }
}
