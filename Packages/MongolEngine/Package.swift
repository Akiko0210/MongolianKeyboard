// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MongolEngine",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MongolEngine",
            targets: ["MongolEngine"]
        )
    ],
    targets: [
        .target(
            name: "MongolEngine",
            path: "Sources/MongolEngine"
        ),
        .testTarget(
            name: "MongolEngineTests",
            dependencies: ["MongolEngine"],
            path: "Tests/MongolEngineTests"
        )
    ]
)
