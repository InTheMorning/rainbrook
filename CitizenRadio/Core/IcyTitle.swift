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

/// Parses Icecast StreamTitle values.
public enum IcyTitle {
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
