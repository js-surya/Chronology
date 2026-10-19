// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Chronology",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .executable(name: "Chronology", targets: ["Chronology"]),
        // Shared by the Mac app and the iOS/iPadOS app + widget (iOS/Chronology.xcodeproj)
        .library(name: "ChronologyCore", targets: ["ChronologyCore"])
    ],
    targets: [
        .target(
            name: "ChronologyCore",
            path: "Sources/ChronologyCore"
        ),
        .executableTarget(
            name: "Chronology",
            dependencies: ["ChronologyCore"],
            path: "Sources/Chronology"
        ),
        .testTarget(
            name: "ChronologyCoreTests",
            dependencies: ["ChronologyCore"],
            path: "Tests/ChronologyCoreTests"
        )
    ]
)
