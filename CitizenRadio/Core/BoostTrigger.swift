import Foundation

/// ADR 0012 §The trigger: decides when the listener heard a track from its start to its end.
///
/// The inputs are the ICY texts of the session and the end of the session.
/// The trigger has no clock and no I/O. It compares texts after `IcySync.normalize`.
public struct BoostTrigger: Equatable, Sendable {
    /// A candidate that reached its end.
    public struct Completed: Equatable, Sendable {
        /// The ICY text of the completed candidate, as received.
        public let icyText: String
        /// The newest relay track that ICY sync selected while the track played, or nil.
        public let track: TrackDisplay?
    }

    /// Holds the ICY text of a candidate and its newest selected relay track.
    private struct Candidate: Equatable, Sendable {
        let icyText: String
        var track: TrackDisplay?
    }

    /// True after the first ICY text of the session.
    private var hasPresentText = false
    /// The normalized text that plays, or nil before the first text of the session.
    private var presentText: String?
    /// The normalized text before `presentText`, or nil.
    private var previousText: String?
    /// The candidate that runs, or nil.
    private var candidate: Candidate?

    public init() {}

    /// Gives a completed candidate, or nil.
    public mutating func receiveIcyText(_ text: String) -> Completed? {
        let normalized = IcySync.normalize(text)

        // The first ICY text of a session starts no candidate. It becomes the current text.
        guard hasPresentText else {
            hasPresentText = true
            presentText = normalized
            previousText = nil
            candidate = nil
            return nil
        }

        // A text equal to the current text changes nothing.
        guard normalized != presentText else {
            return nil
        }

        if candidate != nil, normalized == previousText {
            // The reconnect repeat (ADR 0010): the listener hears the end of the prior
            // track again. Drop the candidate. The current text is P, and the text
            // before it is T.
            previousText = presentText
            presentText = normalized
            candidate = nil
            return nil
        }

        // A text that is not T and not P completes the candidate, if one runs. An empty
        // text also completes it. The next candidate then starts for the new text, if
        // it is non-empty.
        let completed = candidate.map { Completed(icyText: $0.icyText, track: $0.track) }
        previousText = presentText
        presentText = normalized
        candidate = normalized.isEmpty ? nil : Candidate(icyText: text, track: nil)
        return completed
    }

    /// The relay track that ICY sync selects now. Nil is a valid input and keeps the last non-nil track.
    public mutating func selectedTrack(_ track: TrackDisplay?) {
        guard let track else {
            return
        }
        candidate?.track = track
    }

    /// Stop, a playback error or a change of the Track info event. Drops the candidate and starts a new session.
    public mutating func endSession() {
        hasPresentText = false
        presentText = nil
        previousText = nil
        candidate = nil
    }
}
