// swift-tools-version: 6.2

import PackageDescription

let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "TwitchKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TwitchKit", targets: ["TwitchKit"]),
        .executable(name: "TwitchKitSmokeTest", targets: ["TwitchKitSmokeTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "TwitchKit",
            path: "Sources/TwitchKit",
            swiftSettings: strictSettings
        ),
        .executableTarget(
            name: "TwitchKitSmokeTest",
            dependencies: ["TwitchKit"],
            path: "Examples/SmokeTest",
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "TwitchKitTests",
            dependencies: ["TwitchKit"],
            path: "Tests/TwitchKitTests",
            swiftSettings: strictSettings
        ),
    ]
)
