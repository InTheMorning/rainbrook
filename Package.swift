// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rainbrook",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Rainbrook", targets: ["Rainbrook"])],
    dependencies: [
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.23.2"),
        .package(url: "https://github.com/apple/swift-crypto", "4.0.0"..<"6.0.0")
    ],
    targets: [
        .target(
            name: "Rainbrook",
            dependencies: ["RainbrookCore", "RainbrookBuildValues"],
            path: "Rainbrook",
            exclude: [
                "Assets.xcassets",
                "Core",
                "Info.plist",
                "PrivacyInfo.xcprivacy",
                "forcdchime.wav"
            ]
        ),
        .target(
            name: "RainbrookCore",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CryptoExtras", package: "swift-crypto")
            ],
            path: "Rainbrook/Core"
        ),
        // musicindex ADR 0083 R-VERSION-1: the git revision and the build time of the app.
        .target(
            name: "RainbrookBuildValues",
            path: "Tools/RainbrookBuildValues",
            plugins: ["BuildValuesPlugin"]
        ),
        .executableTarget(name: "BuildValuesTool", path: "Tools/BuildValuesTool"),
        .plugin(
            name: "BuildValuesPlugin",
            capability: .buildTool(),
            dependencies: ["BuildValuesTool"],
            path: "Plugins/BuildValuesPlugin"
        ),
        .testTarget(
            name: "RainbrookCoreTests",
            dependencies: ["RainbrookCore"],
            path: "Tests/RainbrookCoreTests",
            resources: [.copy("Vectors")]
        )
    ],
    swiftLanguageModes: [.v6]
)
