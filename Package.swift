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
        ),
        .library(
            name: "OrchardServices",
            targets: ["OrchardServices"]
        )
    ],
    targets: [
        .target(
            name: "OrchardDomain",
            path: "Domain"
        ),
        .target(
            name: "OrchardServices",
            dependencies: ["OrchardDomain"],
            path: "Services"
        ),
        .testTarget(
            name: "OrchardTests",
            dependencies: ["OrchardDomain", "OrchardServices"],
            path: "Tests/OrchardTests"
        )
    ]
)
