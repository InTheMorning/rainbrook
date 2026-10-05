import Foundation

/// Measures the audio that AVPlayer has loaded ahead of the play position.
/// ADR 0008 §Display data uses this value for the display delay.
public enum LoadedAudio {
    /// Seconds of loaded audio that playback can use from `currentTime`.
    /// A range that starts after `currentTime` counts from its start, because
    /// AVPlayer can report the first range a little after zero.
    public static func bufferedAhead(currentTime: Double, loadedRanges: [ClosedRange<Double>]) -> Double {
        loadedRanges
            .filter { $0.upperBound > currentTime }
            .map { $0.upperBound - max(currentTime, $0.lowerBound) }
            .max() ?? 0
    }
}
