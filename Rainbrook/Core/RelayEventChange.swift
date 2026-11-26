import Foundation

/// Task stations-task-003: what the relay clients do when the app reads the event of the selected station again.
///
/// The app reads the event when playback starts and when the settings sheet closes.
/// A different event stops the clients and clears the display states, the relay track and the boost session
/// (ADR 0013 §The trigger). An equal event changes nothing, so the second read starts no second client.
public struct RelayEventChange: Equatable, Sendable {
    /// True when the clients stop, and the display states, the relay track and the boost session clear.
    public let clearsRelay: Bool
    /// True when a display client starts after the change.
    public let startsClient: Bool

    public init(clearsRelay: Bool, startsClient: Bool) {
        self.clearsRelay = clearsRelay
        self.startsClient = startsClient
    }

    /// - current: the event of the clients now, or nil.
    /// - new: the event of the selected station, or nil when it has no valid **Live value address**.
    /// - playbackActive: true while the state is connecting or playing.
    /// - clientExists: true when a display client exists. A client that stopped on a relay error also exists.
    public static func decide(
        current: RelayEvent?, new: RelayEvent?, playbackActive: Bool, clientExists: Bool
    ) -> RelayEventChange {
        let changed = current != new
        let clientAfterChange = clientExists && !changed
        return RelayEventChange(
            clearsRelay: changed,
            startsClient: playbackActive && new != nil && !clientAfterChange
        )
    }
}
