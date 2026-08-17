// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TwigDock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TwigDock", targets: ["TwigDock"])
    ],
    targets: [
        .executableTarget(
            name: "TwigDock",
            path: "Sources/TwigDock"
        ),
        .testTarget(
            name: "TwigDockTests",
            dependencies: ["TwigDock"],
            path: "Tests/TwigDockTests"
        )
    ]
)
