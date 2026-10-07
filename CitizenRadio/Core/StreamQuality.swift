import Foundation

/// ADR 0020 §Stream quality: the choice for the HLS bitrate maximum.
public enum StreamQuality: String, CaseIterable, Equatable, Sendable {
    case auto, medium, low

    /// The maximum in bits each second for preferredPeakBitRate. 0 means no maximum.
    public var peakBitRate: Double {
        switch self {
        case .auto: return 0
        case .medium: return 120_000
        case .low: return 64_000
        }
    }

    /// The text in Settings: "Auto", "Medium", "Low".
    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// ADR 0020 §Stream quality: the saved choice, in `UserDefaults`.
public struct StreamQualitySetting {
    private let defaults: UserDefaults
    private let key = "citizenRadio.streamQuality"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The default is .auto. A stored value that is not a case gives .auto.
    public var quality: StreamQuality {
        get {
            guard let rawValue = defaults.string(forKey: key),
                  let quality = StreamQuality(rawValue: rawValue) else {
                return .auto
            }
            return quality
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
