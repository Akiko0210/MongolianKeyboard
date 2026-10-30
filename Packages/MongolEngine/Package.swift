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
        ),
        .executable(
            name: "mongolgen",
            targets: ["mongolgen"]
        )
    ],
    targets: [
        .target(
            name: "MongolEngine",
            path: "Sources/MongolEngine",
            resources: [
                .copy("Resources/lexicon.tsv"),
                .copy("Resources/bigrams.tsv"),
                .copy("Resources/orthography.tsv")
            ]
        ),
        .executableTarget(
            name: "mongolgen",
            dependencies: ["MongolEngine"],
            path: "Sources/mongolgen"
        ),
        .testTarget(
            name: "MongolEngineTests",
            dependencies: ["MongolEngine"],
            path: "Tests/MongolEngineTests",
            resources: [.process("Fixtures")]
        )
    ]
)
