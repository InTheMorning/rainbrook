import Foundation

public struct BufferSetting {
    public static let defaultSeconds = 3
    public static let choices = [0, 2, 3, 5, 10, 15, 30]
    public static let baseTimeoutSeconds = 20

    private let defaults: UserDefaults
    private let key = "citizenRadio.bufferSeconds"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var seconds: Int {
        get {
            guard let value = defaults.object(forKey: key) as? Int, Self.choices.contains(value) else {
                return Self.defaultSeconds
            }
            return value
        }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }

    /// Seconds of loaded audio after `currentTime` in the range that contains it.
    public static func bufferedAhead(currentTime: Double, loadedRanges: [ClosedRange<Double>]) -> Double {
        guard let range = loadedRanges.first(where: { $0.contains(currentTime) }) else { return 0 }
        return range.upperBound - currentTime
    }

    public static func isReady(bufferedAhead: Double, target: Int) -> Bool {
        bufferedAhead >= Double(target)
    }

    public static func timeoutSeconds(target: Int) -> Int {
        baseTimeoutSeconds + target
    }
}
