public enum PlaybackState: Equatable, Sendable {
    case stopped
    case connecting
    case playing
    case interrupted
    case failed(String)

    public var title: String {
        switch self {
        case .stopped: return "Ready to play"
        case .connecting: return "Connecting"
        case .playing: return "Playing live"
        case .interrupted: return "Playback interrupted"
        case .failed: return "Cannot play the stream"
        }
    }

    public var canStop: Bool {
        switch self {
        case .connecting, .playing, .interrupted: return true
        case .stopped, .failed: return false
        }
    }

    public var errorMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}
