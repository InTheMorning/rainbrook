// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CitizenRadioCore",
    products: [.library(name: "CitizenRadioCore", targets: ["CitizenRadioCore"])],
    targets: [
        .target(name: "CitizenRadioCore", path: "CitizenRadio/Core"),
        .testTarget(
            name: "CitizenRadioCoreTests",
            dependencies: ["CitizenRadioCore"],
            path: "Tests/CitizenRadioCoreTests"
        )
    ]
)

