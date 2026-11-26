import Foundation

/// ADR 0011: display states are early, and the ICY text releases them.
/// ADR 0024: the key of a state with a song line is that song line.
/// ADR 0027: when the ICY text gives no match, the ID3 title alone can give the match.
/// ADR 0030: on HLS, a segment frame with a play ID releases the held state with the same play ID.
public struct IcySync: Equatable, Sendable {
    /// The highest number of display states that the list keeps (ADR 0030 §The list).
    public static let capacity = 8
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
    /// The ID3 title alone of the last ICY text, or nil (ADR 0027).
    private var icyTitleAlone: String?
    /// The segment frame of the last ICY text, or nil when that group had no frame (ADR 0030).
    private var segmentFrame: SegmentFrame?
    /// True after the first segment frame with a play ID in this ICY session (ADR 0030 rule 11).
    private var hasPlayIdFrame = false
    /// ADR 0028: the keys of the states whose value block ended. A state of the key had a value block, and a newer
    /// state of the same key has none. The publisher sends this during a jingle and between songs.
    private var valueEndedKeys: Set<String> = []
    /// ADR 0028 rule 13: the value ends that wait for the play time of the audio, with the number of each hold.
    private var heldValueEnds: [String: UInt64] = [:]
    private var nextHoldNumber: UInt64 = 0

    /// ADR 0028 rule 13: a value end that waits for the play time. `releaseValueEnd(_:)` applies it.
    public struct HeldValueEnd: Equatable, Sendable {
        public let key: String
        let number: UInt64
    }

    /// Creates an IcySync with an empty list and no ICY text.
    public init() {}

    /// TrackLines.select(relay: relayTrack, icy: icyTrack)
    public var lines: TrackLines {
        TrackLines.select(relay: relayTrack, icy: icyTrack)
    }

    /// The relay track of the screen, the boost model and the log (task boost-pairing-task-002).
    /// After the first ICY text, the track that the ICY text selects.
    /// Before it, `timedTrack`: the relay track of the timed apply (ADR 0008), which the screen shows.
    public func track(withoutIcy timedTrack: TrackDisplay?) -> TrackDisplay? {
        hasIcy ? relayTrack : timedTrack
    }

    /// ADR 0028: true when the track has no value block and the value block of its key ended.
    public func valueEnded(_ track: TrackDisplay?) -> Bool {
        guard let track, track.value == nil else { return false }
        return valueEndedKeys.contains(Self.key(of: track))
    }

    /// Adds a display state from the snapshot or the stream.
    /// A nil state (`{"track": null}`) is not added. Selects again after the add.
    /// ADR 0028 rule 13: with `holdValueEnd`, a value end does not apply now. The result is the held value end,
    /// and `releaseValueEnd(_:)` applies it at the play time of the audio.
    @discardableResult
    public mutating func receive(_ track: TrackDisplay?, holdValueEnd: Bool = false) -> HeldValueEnd? {
        var held: HeldValueEnd?
        if let track {
            let newKey = Self.key(of: track)
            // ADR 0028: a state with no value block after a state of the same key with a value block.
            if track.value != nil {
                valueEndedKeys.remove(newKey)
                heldValueEnds[newKey] = nil
            } else if states.first(where: { Self.key(of: $0) == newKey })?.value != nil {
                // ADR 0030 rule 8: compare with the newest state of the key, because the list can hold more than one.
                if holdValueEnd {
                    nextHoldNumber &+= 1
                    heldValueEnds[newKey] = nextHoldNumber
                    held = HeldValueEnd(key: newKey, number: nextHoldNumber)
                } else {
                    valueEndedKeys.insert(newKey)
                }
            }
            // A state with an equal identity replaces the older state, at the front (ADR 0030 §The list).
            let newIdentity = Self.identity(of: track)
            states.removeAll { Self.identity(of: $0) == newIdentity }
            states.insert(track, at: 0)
            if states.count > Self.capacity {
                states.removeLast(states.count - Self.capacity)
            }
            let keptKeys = Set(states.map(Self.key(of:)))
            valueEndedKeys.formIntersection(keptKeys)
            heldValueEnds = heldValueEnds.filter { keptKeys.contains($0.key) }
        }
        select()
        return held
    }

    /// ADR 0028 rule 13: applies a held value end. Gives true when the value end applies now.
    /// A newer state of the key with a value block, a different ICY text, or a clear cancels the hold.
    @discardableResult
    public mutating func releaseValueEnd(_ held: HeldValueEnd) -> Bool {
        guard heldValueEnds[held.key] == held.number else { return false }
        heldValueEnds[held.key] = nil
        valueEndedKeys.insert(held.key)
        return true
    }

    /// Sets the ICY text from a StreamTitle item. An empty text is a valid input.
    /// `titleAlone` is the ID3 title alone when the text joins an artist and a title (ADR 0027).
    /// `segmentFrame` is the `musicindex.hls/2` frame of the same group, or nil (ADR 0030).
    /// Selects again after the set.
    public mutating func receiveIcyText(_ text: String, titleAlone: String? = nil, segmentFrame: SegmentFrame? = nil) {
        // ADR 0028: a different ICY text starts a new song, so the ended value blocks of earlier songs are old.
        if let icyText, Self.normalize(icyText) != Self.normalize(text) {
            valueEndedKeys.removeAll()
            heldValueEnds.removeAll()
        }
        hasIcy = true
        icyText = text
        icyTitleAlone = titleAlone
        self.segmentFrame = segmentFrame
        if segmentFrame?.playId != nil {
            hasPlayIdFrame = true
        }
        select()
    }

    /// Removes all display states. The ICY text stays. Selects again after the clear.
    public mutating func clearStates() {
        states.removeAll()
        // ADR 0030 rule 12: a clear also ends the released state of rule 9.2.
        relayTrack = nil
        valueEndedKeys.removeAll()
        heldValueEnds.removeAll()
        select()
    }

    /// ADR 0017 §The fallback: starts a new ICY session. After this call `hasIcy` is false,
    /// there is no ICY text and no selection. The list of display states stays.
    public mutating func resetIcy() {
        hasIcy = false
        icyText = nil
        icyTitleAlone = nil
        segmentFrame = nil
        hasPlayIdFrame = false
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
        if let playId = segmentFrame?.playId {
            relayTrack = frameSelection(playId: playId, normalizedIcyText: normalizedIcyText)
        } else if segmentFrame == nil && hasPlayIdFrame {
            // Rule 11: after the first frame of the session, a group with no frame uses rules 9.2 and 9.3.
            relayTrack = frameSelection(playId: nil, normalizedIcyText: normalizedIcyText)
        } else {
            relayTrack = icyMatch(normalizedIcyText, in: states)
        }
    }

    /// ADR 0030 §The selection: rules 9.1 to 9.3. With no play ID, the selection starts at rule 9.2.
    private func frameSelection(playId: String?, normalizedIcyText: String) -> TrackDisplay? {
        // Rule 9.1: the frame releases the held state with the same play ID.
        if let playId, let released = states.first(where: { $0.playId == playId }) {
            return released
        }
        // Rule 9.2: a frame that names no held state keeps a released state while the ICY text names it.
        // The newest state in the list with the same play ID replaces it.
        if let present = relayTrack, let presentPlayId = present.playId,
           icyMatch(normalizedIcyText, in: [present]) != nil {
            return states.first(where: { $0.playId == presentPlayId }) ?? present
        }
        // Rule 9.3: else the ICY rule selects from the states with no play ID. A state with a play ID waits for its frame.
        return icyMatch(normalizedIcyText, in: states.filter { $0.playId == nil })
    }

    /// ADR 0011 and ADR 0027: the match of the ICY text, else the match of the ID3 title alone.
    private func icyMatch(_ normalizedIcyText: String, in states: [TrackDisplay]) -> TrackDisplay? {
        Self.match(normalizedIcyText, in: states) ?? titleAloneMatch(in: states)
    }

    /// ADR 0027: the match of the ID3 title alone, when the ICY text gives no match.
    private func titleAloneMatch(in states: [TrackDisplay]) -> TrackDisplay? {
        guard let icyTitleAlone else { return nil }
        let normalizedTitle = Self.normalize(icyTitleAlone)
        guard !normalizedTitle.isEmpty else { return nil }
        return Self.match(normalizedTitle, in: states)
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

    /// ADR 0030 §The list: the play ID when the state has one, else the key.
    /// A state replaces an older state with an equal identity.
    static func identity(of track: TrackDisplay) -> String {
        if let playId = track.playId {
            return "playId:" + playId
        }
        return "key:" + key(of: track)
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
