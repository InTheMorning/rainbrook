import Foundation

/// ADR 0022 §The artwork retry. No clock.
///
/// When an artwork load gives no image, the app loads the same artwork again after these intervals.
/// After the last interval, the app stops until the artwork changes.
public enum ArtworkRetry {
    /// The intervals in seconds before retry 1 to 4.
    public static let delays: [Int] = [2, 5, 10, 30]

    /// The delay before attempt `attempt` (1 is the first retry), or nil after the last.
    public static func delay(beforeRetry attempt: Int) -> Int? {
        guard attempt >= 1, attempt <= delays.count else { return nil }
        return delays[attempt - 1]
    }
}
