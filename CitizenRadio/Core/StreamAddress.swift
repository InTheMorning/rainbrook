import Foundation

public struct StreamAddress: Equatable, Sendable {
    public let url: URL

    public init(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard !trimmed.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              let url = components.url else {
            throw ValidationError.invalidURL
        }
        guard components.user == nil, components.password == nil else {
            throw ValidationError.credentials
        }
        guard components.fragment == nil else { throw ValidationError.fragment }
        if let port = components.port, !(1...65535).contains(port) {
            throw ValidationError.invalidURL
        }
        self.url = url
    }

    public enum ValidationError: LocalizedError, Equatable {
        case empty
        case invalidURL
        case credentials
        case fragment

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Open CitizenRadio and save your stream URL first."
            case .invalidURL:
                return "Enter a complete HTTP or HTTPS stream URL."
            case .credentials:
                return "Use a stream URL without a username or password."
            case .fragment:
                return "Remove the fragment after the # character from the stream URL."
            }
        }
    }
}

