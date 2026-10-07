public struct PlayerScreenModel: Equatable, Sendable {
    public enum Control: Equatable, Sendable {
        case play
        case stop
    }

    /// ADR 0021 §The status: the status during a drop with no network path.
    public static let waitingForNetworkStatus = "Waiting for the network"

    public let status: String
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
        } else {
            status = state.title
        }
    }
}
