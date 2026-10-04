import Foundation

public struct StreamStore {
    private let defaults: UserDefaults
    private let key = "citizenRadio.streamURL"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var savedURL: String {
        defaults.string(forKey: key) ?? ""
    }

    @discardableResult
    public func save(_ text: String) throws -> StreamAddress {
        let address = try StreamAddress(text)
        defaults.set(address.url.absoluteString, forKey: key)
        return address
    }

    public func address() throws -> StreamAddress {
        try StreamAddress(savedURL)
    }
}

