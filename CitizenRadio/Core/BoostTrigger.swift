import Foundation

/// ADR 0012 §The trigger: decides when the listener heard a track from its start to its end.
/// ADR 0016 §The switch back: tells a real switch back from a reconnect repeat by the block.
/// ADR 0016 §The minimum play time: gives the play time of the completed candidate.
///
/// The inputs are the ICY texts of the session, the relay track of each text, and the end of
/// the session. The trigger has no clock of its own. The caller gives the time of each text, on
/// a monotonic clock. The trigger compares texts after `IcySync.normalize`.
public struct BoostTrigger: Equatable, Sendable {
    /// A candidate that reached its end.
    public struct Completed: Equatable, Sendable {
        /// The ICY text of the completed candidate, as received.
        public let icyText: String
        /// The newest relay track that ICY sync selected while the track played, or nil.
        public let track: TrackDisplay?
        /// The seconds from the ICY text of the candidate to the ICY text that completed it.
        public let playedSeconds: Double
    }

    /// Holds the ICY text of a candidate, its newest selected relay track, and its start time.
    private struct Candidate: Equatable, Sendable {
        let icyText: String
        var track: TrackDisplay?
        let startTime: Double
    }

    /// True after the first ICY text of the session.
    private var hasPresentText = false
    /// The normalized text that plays, or nil before the first text of the session.
    private var presentText: String?
    /// The normalized text before `presentText`, or nil.
    private var previousText: String?
    /// The block of the newest selected track for `presentText`, or nil.
    private var presentBlock: String?
    /// The block of the newest selected track for `previousText`, or nil.
    private var previousBlock: String?
    /// The candidate that runs, or nil.
    private var candidate: Candidate?

    public init() {}

    /// Gives a completed candidate, or nil.
    /// `track` is the relay track that ICY sync selects for `text`, or nil.
    /// `time` is seconds on a monotonic clock. The caller gives it.
    public mutating func receiveIcyText(_ text: String, track: TrackDisplay?, at time: Double) -> Completed? {
        let normalized = IcySync.normalize(text)
        let block = track?.value?.blockGuid

        // The first ICY text of a session starts no candidate. It becomes the current text.
        guard hasPresentText else {
            hasPresentText = true
            presentText = normalized
            previousText = nil
            presentBlock = block
            previousBlock = nil
            candidate = nil
            return nil
        }

        // A text equal to the current text changes nothing.
        guard normalized != presentText else {
            return nil
        }

        if let runningCandidate = candidate, normalized == previousText {
            // A change back to the text before the running candidate (ADR 0016 §The switch back).
            if let earlierBlock = previousBlock, let newBlock = block, earlierBlock != newBlock {
                // Both blocks are known and different: a real switch back, not a reconnect
                // repeat. Complete the candidate with its play time. The texts and the blocks
                // shift as for a new text. A new candidate starts for the text that plays now.
                let completed = Completed(
                    icyText: runningCandidate.icyText,
                    track: runningCandidate.track,
                    playedSeconds: time - runningCandidate.startTime
                )
                previousText = presentText
                previousBlock = presentBlock
                presentText = normalized
                presentBlock = newBlock
                candidate = Candidate(icyText: text, track: track, startTime: time)
                return completed
            }
            // One or both blocks are not known, or they are equal: the reconnect repeat
            // (ADR 0010). Drop the candidate. The two texts and the two blocks change places.
            previousText = presentText
            presentText = normalized
            swap(&previousBlock, &presentBlock)
            candidate = nil
            return nil
        }

        // A text that is not T and not P completes the candidate, if one runs. An empty
        // text also completes it. The next candidate then starts for the new text, if
        // it is non-empty.
        let completed = candidate.map {
            Completed(icyText: $0.icyText, track: $0.track, playedSeconds: time - $0.startTime)
        }
        previousText = presentText
        previousBlock = presentBlock
        presentText = normalized
        presentBlock = block
        candidate = normalized.isEmpty ? nil : Candidate(icyText: text, track: track, startTime: time)
        return completed
    }

    /// The relay track that ICY sync selects now. Nil is a valid input and keeps the last non-nil track.
    /// A track with a block sets the block of the present text (ADR 0016 §The switch back).
    public mutating func selectedTrack(_ track: TrackDisplay?) {
        guard let track else {
            return
        }
        if let block = track.value?.blockGuid {
            presentBlock = block
        }
        candidate?.track = track
    }

    /// Stop, a playback error or a change of the live value address. Drops the candidate,
    /// clears the blocks, and starts a new session.
    public mutating func endSession() {
        hasPresentText = false
        presentText = nil
        previousText = nil
        presentBlock = nil
        previousBlock = nil
        candidate = nil
    }
}
