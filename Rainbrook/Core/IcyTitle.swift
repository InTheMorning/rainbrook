import Foundation

/// A track parsed from an Icecast StreamTitle header.
public struct IcyTrack: Equatable, Sendable {
    public let artist: String?
    public let title: String

    public init(artist: String?, title: String) {
        self.artist = artist
        self.title = title
    }
}

/// ADR 0027: the ICY text of one metadata group, with the ID3 title alone when the text joins an artist and a title.
/// ADR 0030: also the segment frame of the group, when the group has one.
public struct IcyText: Equatable, Sendable {
    /// The ICY text (ADR 0025).
    public let text: String
    /// The title item alone, when `text` is "artist - title" from ID3 items. Else nil.
    public let titleAlone: String?
    /// The `musicindex.hls/2` frame of the group, or nil when the group has no such frame (ADR 0030).
    public let segmentFrame: SegmentFrame?

    public init(text: String, titleAlone: String? = nil, segmentFrame: SegmentFrame? = nil) {
        self.text = text
        self.titleAlone = titleAlone
        self.segmentFrame = segmentFrame
    }

    /// The same text with the segment frame of the group.
    public func with(segmentFrame: SegmentFrame?) -> IcyText {
        IcyText(text: text, titleAlone: titleAlone, segmentFrame: segmentFrame)
    }
}

/// ADR 0030: the `musicindex.hls/2` frame of an HLS segment (publisher ADR 0038 §The Segment Frame).
public struct SegmentFrame: Equatable, Sendable {
    /// The schema value of the frame.
    public static let schema = "musicindex.hls/2"

    /// The play ID of the segment that starts at the frame, or nil for a jingle.
    public let playId: String?

    public init(playId: String?) {
        self.playId = playId
    }

    /// Parses the value of a `TXXX` item. Gives nil when the value is not a `musicindex.hls/2` frame.
    /// A missing `playId`, `null` or an empty string gives a frame with no play ID.
    /// A `playId` of a different type gives nil.
    public static func parse(_ value: String) -> SegmentFrame? {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any],
              dict["schema"] as? String == schema else {
            return nil
        }
        switch dict["playId"] {
        case nil, is NSNull:
            return SegmentFrame(playId: nil)
        case let playId as String:
            return SegmentFrame(playId: playId.isEmpty ? nil : playId)
        default:
            return nil
        }
    }
}

/// Parses Icecast StreamTitle values.
public enum IcyTitle {
    /// ADR 0025 and ADR 0027: gives the ICY text of one metadata group, or nil when the group gives no ICY text.
    /// `titleAlone` is the trimmed title only when the text joins an artist and a title.
    public static func icyText(streamTitle: String?, artist: String?, title: String?) -> IcyText? {
        guard let text = text(streamTitle: streamTitle, artist: artist, title: title) else {
            return nil
        }
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let joined = streamTitle == nil && text != trimmedTitle
        return IcyText(text: text, titleAlone: joined ? trimmedTitle : nil)
    }

    /// ADR 0025: gives the ICY text of one metadata group, or nil when the group gives no ICY text.
    ///
    /// - A StreamTitle value wins, also an empty one.
    /// - Else a title that is not empty gives "artist - title", or the title alone when the artist is empty.
    /// - Else the result is nil. An empty value is a value with only white space.
    public static func text(streamTitle: String?, artist: String?, title: String?) -> String? {
        if let streamTitle {
            return streamTitle
        }
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        guard let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty else {
            return title
        }
        return "\(artist) - \(title)"
    }

    /// Parses an Icecast StreamTitle. Gives nil for an empty text.
    public static func parse(_ text: String) -> IcyTrack? {
        // Rule 1: Return nil if empty after trimming
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        // Rule 2: Find the first " - " in the original text
        let separator = " - "
        guard let range = text.range(of: separator) else {
            // No " - " found
            return IcyTrack(artist: nil, title: trimmed)
        }

        // Rule 3: Split at the first " - "
        let beforeSeparator = String(text[..<range.lowerBound])
        let afterSeparator = String(text[range.upperBound...])

        let artist = beforeSeparator.trimmingCharacters(in: .whitespacesAndNewlines)
        let titlePart = afterSeparator.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rule 4: If title part is empty, return trimmed full text as title and nil as artist
        if titlePart.isEmpty {
            return IcyTrack(artist: nil, title: trimmed)
        }

        // Rule 5: If artist part is empty, return nil as artist
        let finalArtist = artist.isEmpty ? nil : artist
        return IcyTrack(artist: finalArtist, title: titlePart)
    }
}
