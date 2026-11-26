import Foundation

/// musicindex ADR 0083: the build values of the app and its version line.
/// The Rust crate `musicindex-build-info` of musicindex-lib gives the same line form to the Rust apps.
public struct BuildValues: Equatable, Sendable {
    /// The name of the app in the line.
    public let name: String
    /// The version of the app (`CFBundleShortVersionString`), or nil.
    public let version: String?
    /// The short hash of the commit, with `-dirty` for a build with uncommitted changes, or nil (R-VERSION-1).
    public let gitRevision: String?
    /// The build time in UTC, in the form `2026-11-25T18:00:00Z`, or nil (R-VERSION-1).
    public let builtAt: String?

    /// An empty value gives nil.
    public init(name: String, version: String?, gitRevision: String?, builtAt: String?) {
        self.name = name
        self.version = Self.known(version)
        self.gitRevision = Self.known(gitRevision)
        self.builtAt = Self.known(builtAt)
    }

    /// R-VERSION-2 and R-VERSION-8 item 3: `Rainbrook 0.1.0 (a1b2c3d, 2026-11-25)`.
    /// The parentheses contain only the known values. With no known value, the line has no parentheses.
    public var versionLine: String {
        let head = [name, version].compactMap { $0 }.joined(separator: " ")
        let date = builtAt.map { String($0.prefix(10)) }
        let known = [gitRevision, date].compactMap { $0 }
        return known.isEmpty ? head : "\(head) (\(known.joined(separator: ", ")))"
    }

    private static func known(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
