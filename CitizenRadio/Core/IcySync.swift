import Foundation

/// ADR 0011: display states are early, and the ICY text releases them.
/// ADR 0024: the key of a state with a song line is that song line.
public struct IcySync: Equatable, Sendable {
    /// The highest number of display states that the list keeps.
    public static let capacity = 4
    /// The minimum count of normalized ICY text characters for a prefix match.
    public static let minimumPrefixCharacters = 8

    /// True after the first ICY text, also an empty one.
    public private(set) var hasIcy = false
    /// The newest state whose key matches the ICY text, or nil.
    public private(set) var relayTrack: TrackDisplay?
    /// The parsed ICY text, or nil for an empty text or before the first ICY text.
    public private(set) var icyTrack: IcyTrack?

    /// The display states, newest first. The list holds a maximum of `capacity` states.
    private var states: [TrackDisplay] = []
    /// The raw text from the last call to `receiveIcyText`, or nil before that call.
    private var icyText: String?

    /// Creates an IcySync with an empty list and no ICY text.
    public init() {}

    /// TrackLines.select(relay: relayTrack, icy: icyTrack)
    public var lines: TrackLines {
        TrackLines.select(relay: relayTrack, icy: icyTrack)
    }

    /// Adds a display state from the snapshot or the stream.
    /// A nil state (`{"track": null}`) is not added. Selects again after the add.
    public mutating func receive(_ track: TrackDisplay?) {
        if let track {
            let newKey = Self.key(of: track)
            // A state with an equal key replaces the older state, at the front.
            states.removeAll { Self.key(of: $0) == newKey }
            states.insert(track, at: 0)
            if states.count > Self.capacity {
                states.removeLast(states.count - Self.capacity)
            }
        }
        select()
    }

    /// Sets the ICY text from a StreamTitle item. An empty text is a valid input.
    /// Selects again after the set.
    public mutating func receiveIcyText(_ text: String) {
        hasIcy = true
        icyText = text
        select()
    }

    /// Removes all display states. The ICY text stays. Selects again after the clear.
    public mutating func clearStates() {
        states.removeAll()
        select()
    }

    /// ADR 0017 §The fallback: starts a new ICY session. After this call `hasIcy` is false,
    /// there is no ICY text and no selection. The list of display states stays.
    public mutating func resetIcy() {
        hasIcy = false
        icyText = nil
        select()
    }

    /// Selects the ICY track and the relay track from the list and the current ICY text.
    private mutating func select() {
        guard hasIcy, let icyText else {
            relayTrack = nil
            icyTrack = nil
            return
        }

        let normalizedIcyText = Self.normalize(icyText)
        guard !normalizedIcyText.isEmpty else {
            relayTrack = nil
            icyTrack = nil
            return
        }

        icyTrack = IcyTitle.parse(icyText)
        relayTrack = Self.match(normalizedIcyText, in: states)
    }

    /// Finds the newest state whose key equals the ICY text, or else starts with it.
    private static func match(_ normalizedIcyText: String, in states: [TrackDisplay]) -> TrackDisplay? {
        if let exact = states.first(where: { key(of: $0) == normalizedIcyText }) {
            return exact
        }

        guard normalizedIcyText.count >= minimumPrefixCharacters,
              hasCharacterAfterFirstSeparator(normalizedIcyText) else {
            return nil
        }

        return states.first(where: { key(of: $0).hasPrefix(normalizedIcyText) })
    }

    /// True when the text has a minimum of one character after its first " - ".
    private static func hasCharacterAfterFirstSeparator(_ text: String) -> Bool {
        guard let range = text.range(of: " - ") else {
            return false
        }
        return !text[range.upperBound...].isEmpty
    }

    /// Trims, changes each run of white space to one space, applies Unicode NFC, and lowercases.
    public static func normalize(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// ADR 0024: normalize(songLine) when the state has a song line.
    /// Else ADR 0011: normalize("\(artist) - \(title)").
    public static func key(of track: TrackDisplay) -> String {
        if let songLine = track.songLine {
            return normalize(songLine)
        }
        return normalize("\(track.artist) - \(track.title)")
    }
}
