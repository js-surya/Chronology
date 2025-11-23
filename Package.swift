// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Chronology",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Chronology", targets: ["Chronology"])
    ],
    targets: [
        .executableTarget(
            name: "Chronology",
            path: "Sources/Chronology"
        ),
        .testTarget(
            name: "ChronologyTests",
            dependencies: ["Chronology"],
            path: "Tests/ChronologyTests"
        )
    ]
)
