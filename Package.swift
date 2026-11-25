// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CitizenRadio",
    platforms: [.iOS(.v17)],
    products: [.library(name: "CitizenRadio", targets: ["CitizenRadio"])],
    dependencies: [
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.23.2"),
        .package(url: "https://github.com/apple/swift-crypto", "4.0.0"..<"6.0.0")
    ],
    targets: [
        .target(
            name: "CitizenRadio",
            dependencies: ["CitizenRadioCore", "CitizenRadioBuildValues"],
            path: "CitizenRadio",
            exclude: [
                "Assets.xcassets",
                "Core",
                "Info.plist",
                "PrivacyInfo.xcprivacy",
                "forcdchime.wav"
            ]
        ),
        .target(
            name: "CitizenRadioCore",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CryptoExtras", package: "swift-crypto")
            ],
            path: "CitizenRadio/Core"
        ),
        // musicindex ADR 0083 R-VERSION-1: the git revision and the build time of the app.
        .target(
            name: "CitizenRadioBuildValues",
            path: "Tools/CitizenRadioBuildValues",
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
            name: "CitizenRadioCoreTests",
            dependencies: ["CitizenRadioCore"],
            path: "Tests/CitizenRadioCoreTests",
            resources: [.copy("Vectors")]
        )
    ],
    swiftLanguageModes: [.v6]
)
