// musicindex ADR 0083 R-VERSION-1: gives the git revision and the build time to the module
// RainbrookBuildValues. The command runs again when a Swift file of the app, Package.swift, HEAD, the file of
// the branch or the Git index changes. Thus the build time is the time of the last run of the command, as in the
// Rust crate `musicindex-build-info`.
import Foundation
import PackagePlugin

@main
struct BuildValuesPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let packageDirectory = context.package.directoryURL
        let output = context.pluginWorkDirectoryURL.appending(path: "GeneratedBuildValues.swift")
        var inputs = [packageDirectory.appending(path: "Package.swift")]
        inputs += Self.swiftFiles(in: packageDirectory.appending(path: "Rainbrook"))
        inputs += Self.gitFiles(in: packageDirectory.appending(path: ".git"))
        return [
            .buildCommand(
                displayName: "Write the build values of Rainbrook",
                executable: try context.tool(named: "BuildValuesTool").url,
                arguments: [packageDirectory.path(percentEncoded: false), output.path(percentEncoded: false)],
                environment: Self.passedEnvironment(),
                inputFiles: inputs,
                outputFiles: [output]
            )
        ]
    }

    /// The Swift files of the app sources.
    private static func swiftFiles(in directory: URL) -> [URL] {
        guard let items = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return items.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// HEAD, the Git index and the file of the branch, when they exist.
    private static func gitFiles(in gitDirectory: URL) -> [URL] {
        var files = [gitDirectory.appending(path: "HEAD"), gitDirectory.appending(path: "index")]
        // A commit changes the file of the branch, not HEAD.
        if let head = try? String(contentsOf: gitDirectory.appending(path: "HEAD"), encoding: .utf8),
           head.hasPrefix("ref: ") {
            let reference = head.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            files.append(gitDirectory.appending(path: reference))
        }
        return files.filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    /// The input values of R-VERSION-8 item 1 when they are set, and the values that Git needs.
    private static func passedEnvironment() -> [String: String] {
        let environment = ProcessInfo.processInfo.environment
        var passed: [String: String] = [:]
        for name in ["RAINBROOK_GIT_REVISION", "RAINBROOK_BUILT_AT", "PATH", "HOME"] {
            if let value = environment[name] {
                passed[name] = value
            }
        }
        return passed
    }
}
