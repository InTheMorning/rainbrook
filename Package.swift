// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CitizenRadio",
    platforms: [.iOS(.v17)],
    products: [.library(name: "CitizenRadio", targets: ["CitizenRadio"])],
    targets: [
        .target(
            name: "CitizenRadio",
            dependencies: ["CitizenRadioCore"],
            path: "CitizenRadio",
            exclude: [
                "Assets.xcassets",
                "Core",
                "Info.plist",
                "PrivacyInfo.xcprivacy",
                "forcdchime.wav"
            ]
        ),
        .target(name: "CitizenRadioCore", path: "CitizenRadio/Core"),
        .testTarget(
            name: "CitizenRadioCoreTests",
            dependencies: ["CitizenRadioCore"],
            path: "Tests/CitizenRadioCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
