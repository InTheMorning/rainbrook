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
