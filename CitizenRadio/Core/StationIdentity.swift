import Foundation

/// ADR 0028: the station title and the station image from the dead block payload.
/// The publisher sends them in each dead block (publisher ADR 0029). They do not change between blocks,
/// so the app can show them at each time and needs no display delay.
public struct StationIdentity: Equatable, Sendable {
    /// The station title, or nil for the default dead block title or an empty title.
    public let title: String?
    /// The station image, or nil.
    public let image: URL?

    /// Initialize the identity from values.
    public init(title: String?, image: URL?) {
        self.title = title
        self.image = image
    }

    /// Reads the identity from a dead block payload. Gives nil for each other payload.
    public init?(_ payload: LiveValuePayload) {
        guard payload.isDeadBlock else { return nil }
        let trimmed = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDefault = trimmed.isEmpty || trimmed == LiveValuePayload.placeholderTitle
        self.init(title: isDefault ? nil : trimmed, image: payload.image)
    }

    /// The station image as an artwork, or nil.
    public var artwork: TrackDisplay.Artwork? {
        image.map { .url($0) }
    }
}

extension TrackLines {
    /// ADR 0028: the station lines replace the default lines, and the lines of a track whose value block ended.
    /// `valueEnded` comes from `IcySync.valueEnded(_:)`. Without a station identity, the lines stay as they are.
    public func withStation(_ station: StationIdentity?, valueEnded: Bool = false) -> TrackLines {
        guard let station else { return self }
        if valueEnded {
            return TrackLines(title: station.title ?? Self.defaultTitle, artist: nil, artwork: nil, album: nil)
        }
        guard let title = station.title, self == TrackLines.select(relay: nil, icy: nil) else {
            return self
        }
        return TrackLines(title: title, artist: nil, artwork: nil, album: nil)
    }
}
