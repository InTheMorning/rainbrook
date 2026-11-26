public struct PlaybackRequest: Sendable {
    public private(set) var wantsPlayback = false
    private var resumeAfterInterruption = false

    public init() {}

    public mutating func play() {
        wantsPlayback = true
        resumeAfterInterruption = false
    }

    public mutating func stop() {
        wantsPlayback = false
        resumeAfterInterruption = false
    }

    public mutating func interruptionBegan() {
        resumeAfterInterruption = resumeAfterInterruption || wantsPlayback
        wantsPlayback = false
    }

    public mutating func interruptionEnded(shouldResume: Bool, sameOutput: Bool) -> Bool {
        let resume = resumeAfterInterruption && shouldResume && sameOutput
        resumeAfterInterruption = false
        wantsPlayback = resume
        return resume
    }
}

