// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Orchard",
    defaultLocalization: "el",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OrchardDomain",
            targets: ["OrchardDomain"]
        )
    ],
    targets: [
        .target(
            name: "OrchardDomain",
            path: "Domain"
        ),
        .testTarget(
            name: "OrchardTests",
            dependencies: ["OrchardDomain"],
            path: "Tests/OrchardTests"
        )
    ]
)
