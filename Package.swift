// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "CodexQuota",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexQuotaCore", targets: ["CodexQuotaCore"]),
        .executable(name: "CodexQuotaApp", targets: ["CodexQuotaApp"])
    ],
    targets: [
        .target(name: "CodexQuotaCore"),
        .executableTarget(
            name: "CodexQuotaApp",
            dependencies: ["CodexQuotaCore"]
        ),
        .testTarget(
            name: "CodexQuotaCoreTests",
            dependencies: ["CodexQuotaCore"]
        )
    ]
)
