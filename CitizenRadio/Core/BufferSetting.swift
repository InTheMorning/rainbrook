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

    /// Seconds of loaded audio that playback can use from `currentTime`.
    /// A range that starts after `currentTime` counts from its start, because
    /// AVPlayer can report the first range a little after zero.
    public static func bufferedAhead(currentTime: Double, loadedRanges: [ClosedRange<Double>]) -> Double {
        loadedRanges
            .filter { $0.upperBound > currentTime }
            .map { $0.upperBound - max(currentTime, $0.lowerBound) }
            .max() ?? 0
    }

    public static func isReady(bufferedAhead: Double, target: Int) -> Bool {
        bufferedAhead >= Double(target)
    }

    /// Seconds the player waits for the buffer before it starts without it.
    public static func maxWaitSeconds(target: Int) -> Int {
        target + 5
    }

    public static func shouldStart(bufferedAhead: Double, target: Int, waitExpired: Bool) -> Bool {
        waitExpired || isReady(bufferedAhead: bufferedAhead, target: target)
    }

    public static func timeoutSeconds(target: Int) -> Int {
        baseTimeoutSeconds + target
    }
}
