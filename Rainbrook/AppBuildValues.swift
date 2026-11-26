import Foundation
#if SWIFT_PACKAGE
import RainbrookCore
#endif
#if canImport(RainbrookBuildValues)
import RainbrookBuildValues
#endif

/// musicindex ADR 0083: the build values of this build. Each surface uses this value.
/// The version comes from `CFBundleShortVersionString`. The SwiftPM build (xtool) gives the git revision and the
/// build time through the module `RainbrookBuildValues`. A build with no such module has no git revision and
/// no build time, so the line has no parentheses (R-VERSION-8 item 3).
enum AppBuildValues {
    static let current: BuildValues = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        #if canImport(RainbrookBuildValues)
        return BuildValues(
            name: "Rainbrook", version: version,
            gitRevision: GeneratedBuildValues.gitRevision, builtAt: GeneratedBuildValues.builtAt
        )
        #else
        return BuildValues(name: "Rainbrook", version: version, gitRevision: nil, builtAt: nil)
        #endif
    }()
}
