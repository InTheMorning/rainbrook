public struct PlayerScreenModel: Equatable, Sendable {
    public enum Control: Equatable, Sendable {
        case play
        case stop
    }

    public let status: String
    public let control: Control
    public let isControlEnabled: Bool

    public init(state: PlaybackState, hasSavedStream: Bool) {
        control = state.canStop ? .stop : .play
        isControlEnabled = control == .stop || hasSavedStream
        if let message = state.errorMessage {
            status = message
        } else if !hasSavedStream && !state.canStop {
            status = "Add a station in Settings"
        } else {
            status = state.title
        }
    }
}
