import Foundation

/// ADR 0013 §Settings: the auto-boost settings stored in `UserDefaults`.
public struct BoostSettings {
    /// The correct range of the boost amount, in sats.
    public static let amountRange = 1...100_000
    /// The default boost amount, in sats.
    public static let defaultAmountSats = 100
    /// The maximum length of the boost message, in characters.
    public static let maxMessageLength = 200
    /// The maximum length of the sender name and the app name, in characters.
    public static let maxNameLength = 64
    /// The default app name.
    public static let defaultAppName = "CitizenRadio"

    private let defaults: UserDefaults
    private let isEnabledKey = "citizenRadio.autoBoost.isEnabled"
    private let amountSatsKey = "citizenRadio.autoBoost.amountSats"
    private let messageKey = "citizenRadio.autoBoost.message"
    private let senderNameKey = "citizenRadio.autoBoost.senderName"
    private let appNameKey = "citizenRadio.autoBoost.appName"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True when auto-boost is on. The default is false.
    public var isEnabled: Bool {
        get { defaults.object(forKey: isEnabledKey) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: isEnabledKey) }
    }

    /// The boost amount for each track, in sats. The default is 100.
    /// A stored value that is not in `amountRange` gives the default.
    public var amountSats: Int {
        get {
            guard let stored = defaults.object(forKey: amountSatsKey) as? Int,
                  Self.amountRange.contains(stored) else {
                return Self.defaultAmountSats
            }
            return stored
        }
        nonmutating set { defaults.set(newValue, forKey: amountSatsKey) }
    }

    /// The message of each auto-boost. The default is empty.
    /// The setter cuts the text to `maxMessageLength` characters.
    public var message: String {
        get { defaults.string(forKey: messageKey) ?? "" }
        nonmutating set {
            defaults.set(String(newValue.prefix(Self.maxMessageLength)), forKey: messageKey)
        }
    }

    /// The sender name in each boost. The default is empty.
    /// The setter cuts the text to `maxNameLength` characters.
    public var senderName: String {
        get { defaults.string(forKey: senderNameKey) ?? "" }
        nonmutating set {
            defaults.set(String(newValue.prefix(Self.maxNameLength)), forKey: senderNameKey)
        }
    }

    /// The app name in each boost. The default is "CitizenRadio".
    /// An empty or white-space value gives the default. The setter cuts the text to `maxNameLength`.
    public var appName: String {
        get { defaults.string(forKey: appNameKey) ?? Self.defaultAppName }
        nonmutating set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                defaults.set(Self.defaultAppName, forKey: appNameKey)
            } else {
                defaults.set(String(trimmed.prefix(Self.maxNameLength)), forKey: appNameKey)
            }
        }
    }

    /// A whole number in `amountRange`, after trimming white space. Else nil.
    public static func parseAmount(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), amountRange.contains(value) else {
            return nil
        }
        return value
    }
}
