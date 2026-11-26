import Foundation

/// Display delay rule for streamed display state.
public enum DisplayTiming {
    /// The longest delay. A larger buffered value is not correct. The app does not wait longer.
    public static let maximumSeconds: Double = 60

    /// Compute the wait time before the app applies a streamed display state.
    /// The app applies zero delay to values that are not finite or that are 0 or less.
    /// Otherwise, the app applies the value in seconds, with `maximumSeconds` as the maximum.
    /// The result keeps fractions of a second as milliseconds.
    public static func delay(bufferedAhead: Double) -> Duration {
        // Guard for non-finite or non-positive values.
        guard bufferedAhead.isFinite && bufferedAhead > 0 else {
            return .zero
        }

        // Clamp to maximum and convert to Duration.
        let clampedSeconds = min(bufferedAhead, maximumSeconds)
        return .milliseconds(Int64((clampedSeconds * 1000).rounded()))
    }
}
