import Foundation

public struct ChimeSetting {
    private let defaults: UserDefaults
    private let key = "citizenRadio.chimeWhileConnecting"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }

    public static func shouldPlay(state: PlaybackState, enabled: Bool) -> Bool {
        enabled && state == .connecting
    }
}
