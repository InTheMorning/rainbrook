import Foundation

public struct ChimeSetting {
    /// ADR 0021 §The chime: in the played phase, a drop must last this time before the chime plays.
    public static let playedPhaseDelaySeconds = 3

    private let defaults: UserDefaults
    private let key = "citizenRadio.chimeWhileConnecting"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }

    /// ADR 0021 §The chime. The chime plays only in the connecting state.
    /// dropSeconds: nil in the start phase, else the seconds since the drop started.
    public static func shouldPlay(state: PlaybackState, enabled: Bool, dropSeconds: Int?) -> Bool {
        guard enabled, state == .connecting else { return false }
        guard let dropSeconds else { return true }
        return dropSeconds >= playedPhaseDelaySeconds
    }
}
