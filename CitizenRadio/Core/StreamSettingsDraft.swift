import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var text: String
    public var chimeEnabled: Bool
    public let savedURL: String
    public let savedChimeEnabled: Bool

    public init(savedURL: String, chimeEnabled: Bool) {
        self.text = savedURL
        self.chimeEnabled = chimeEnabled
        self.savedURL = savedURL
        self.savedChimeEnabled = chimeEnabled
    }

    public var urlChanged: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != savedURL
    }

    public var canSave: Bool {
        if urlChanged {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return chimeEnabled != savedChimeEnabled
    }
}
