import Foundation

/// ADR 0021 §The stall budget. It has no clock. The caller gives each second.
///
/// A drop in the played phase starts a budget. The budget counts only the seconds
/// with a satisfied network path. When it counts `limitSeconds`, the drop fails.
public struct StallBudget: Equatable, Sendable {
    public static let limitSeconds = 60

    public private(set) var countedSeconds = 0

    public init() {}

    /// Counts one second. A second with no satisfied path does not count.
    /// Gives true when the counted seconds reach limitSeconds.
    public mutating func tick(pathSatisfied: Bool) -> Bool {
        if pathSatisfied {
            countedSeconds += 1
        }
        return countedSeconds >= Self.limitSeconds
    }
}
