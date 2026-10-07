import Foundation

/// ADR 0020 §Stream quality: the choice for the HLS variant.
/// Each choice plays one fixed variant of the master playlist.
public enum StreamQuality: String, CaseIterable, Equatable, Sendable {
    // The sequence of the cases is the sequence in the Settings picker.
    case high, medium, low

    /// The maximum in bits each second. nil means no maximum (high).
    public var maximumBandwidth: Int? {
        switch self {
        case .high: return nil
        case .medium: return 120_000
        case .low: return 64_000
        }
    }

    /// preferredPeakBitRate when the app plays the URL as it is. 0 means no maximum.
    public var peakBitRate: Double {
        switch self {
        case .high: return 0
        case .medium: return 120_000
        case .low: return 64_000
        }
    }

    /// The text in Settings: "High", "Medium", "Low".
    public var label: String {
        switch self {
        case .high: return "High"
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

    /// The default is .medium. A stored value that is not a case, for example "auto" from a previous version, gives .medium.
    public var quality: StreamQuality {
        get {
            guard let rawValue = defaults.string(forKey: key),
                  let quality = StreamQuality(rawValue: rawValue) else {
                return .medium
            }
            return quality
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}

/// ADR 0020 §The HLS live offset: the distance behind the live edge, in seconds.
/// The player keeps this audio as its buffer.
public enum HLSBuffer: Int, CaseIterable, Equatable, Sendable {
    case seconds10 = 10, seconds30 = 30, seconds60 = 60, seconds90 = 90

    public var seconds: Int { rawValue }

    /// The text in Settings, for example "30 seconds".
    public var label: String { "\(rawValue) seconds" }
}

/// ADR 0020 §The HLS live offset: the saved choice, in `UserDefaults`.
public struct HLSBufferSetting {
    private let defaults: UserDefaults
    private let key = "citizenRadio.hlsBufferSeconds"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The default is 30 seconds. A stored value that is not a case gives 30 seconds.
    public var buffer: HLSBuffer {
        get {
            guard let stored = defaults.object(forKey: key) as? Int,
                  let buffer = HLSBuffer(rawValue: stored) else {
                return .seconds30
            }
            return buffer
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
