public struct PlayerScreenModel: Equatable, Sendable {
    public enum Control: Equatable, Sendable {
        case play
        case stop
    }

    /// ADR 0021 §The status: the status during a drop with no network path.
    public static let waitingForNetworkStatus = "Waiting for the network"

    /// The status line, or nil while the stream plays. ADR 0014 §Player screen: the Stop button shows that state.
    public let status: String?
    public let control: Control
    public let isControlEnabled: Bool

    /// waitingForNetwork: true during a drop with no satisfied path.
    public init(state: PlaybackState, hasSavedStream: Bool, waitingForNetwork: Bool = false) {
        control = state.canStop ? .stop : .play
        isControlEnabled = control == .stop || hasSavedStream
        if let message = state.errorMessage {
            status = message
        } else if !hasSavedStream && !state.canStop {
            status = "Add a station in Settings"
        } else if waitingForNetwork && state == .connecting {
            status = Self.waitingForNetworkStatus
        } else if state == .playing {
            status = nil
        } else {
            status = state.title
        }
    }
}
