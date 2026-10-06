import Foundation

/// ADR 0012 §Settings: the auto-boost settings stored in `UserDefaults`.
public struct BoostSettings {
    /// The boost amounts the operator can select, in sats.
    public static let amountChoices = [21, 50, 100, 250, 500, 1000]
    /// The default boost amount, in sats.
    public static let defaultAmountSats = 100

    private let defaults: UserDefaults
    private let isEnabledKey = "citizenRadio.autoBoost.isEnabled"
    private let amountSatsKey = "citizenRadio.autoBoost.amountSats"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True when auto-boost is on. The default is false.
    public var isEnabled: Bool {
        get { defaults.object(forKey: isEnabledKey) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: isEnabledKey) }
    }

    /// The boost amount for each track, in sats. The default is 100.
    /// A stored value that is not in `amountChoices` gives 100.
    public var amountSats: Int {
        get {
            guard let stored = defaults.object(forKey: amountSatsKey) as? Int,
                  Self.amountChoices.contains(stored) else {
                return Self.defaultAmountSats
            }
            return stored
        }
        nonmutating set { defaults.set(newValue, forKey: amountSatsKey) }
    }
}
