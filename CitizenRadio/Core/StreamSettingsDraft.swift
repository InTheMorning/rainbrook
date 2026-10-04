import Foundation

public struct StreamSettingsDraft: Equatable, Sendable {
    public var text: String
    public var chimeEnabled: Bool
    public var bufferSeconds: Int
    public let savedURL: String
    public let savedChimeEnabled: Bool
    public let savedBufferSeconds: Int

    public init(savedURL: String, chimeEnabled: Bool, bufferSeconds: Int) {
        self.text = savedURL
        self.chimeEnabled = chimeEnabled
        self.bufferSeconds = bufferSeconds
        self.savedURL = savedURL
        self.savedChimeEnabled = chimeEnabled
        self.savedBufferSeconds = bufferSeconds
    }

    public var urlChanged: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != savedURL
    }

    public var canSave: Bool {
        if urlChanged {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return chimeEnabled != savedChimeEnabled || bufferSeconds != savedBufferSeconds
    }
}
