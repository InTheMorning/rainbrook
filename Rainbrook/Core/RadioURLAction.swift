import Foundation

public enum RadioURLAction: String, Sendable {
    case play
    case stop

    public init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "rainbrook",
              components.user == nil, components.password == nil,
              components.port == nil, components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let action = components.host?.lowercased() else { return nil }
        self.init(rawValue: action)
    }
}
