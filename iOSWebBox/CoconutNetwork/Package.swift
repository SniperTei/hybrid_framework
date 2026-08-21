// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoconutNetwork",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "CoconutNetwork", targets: ["CoconutNetwork"])
    ],
    targets: [
        .target(
            name: "CoconutNetwork",
            path: "Sources/CoconutNetwork"
        ),
        .testTarget(
            name: "CoconutNetworkTests",
            dependencies: ["CoconutNetwork"],
            path: "Tests/CoconutNetworkTests"
        )
    ]
)
