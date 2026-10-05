import Foundation

/// A simplified summary of one network path update.
/// ADR 0008 §Transport: a path change starts a reconnect at once.
public struct NetworkPathSummary: Equatable, Sendable {
    public let isSatisfied: Bool
    /// The interface names, in the order that the system gives.
    public let interfaces: [String]

    public init(isSatisfied: Bool, interfaces: [String]) {
        self.isSatisfied = isSatisfied
        self.interfaces = interfaces
    }

    /// Tells if the client must reconnect, for this path change.
    /// It gives true when the new path is satisfied, and the old path was not
    /// satisfied or used different interfaces.
    /// It gives false when `old` is nil, because the first path is not a change.
    public static func shouldReconnect(from old: NetworkPathSummary?, to new: NetworkPathSummary) -> Bool {
        guard new.isSatisfied else {
            return false
        }
        guard let old else {
            return false
        }
        guard old.isSatisfied else {
            return true
        }
        return old.interfaces != new.interfaces
    }
}
