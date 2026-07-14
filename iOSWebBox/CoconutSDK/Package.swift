// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoconutSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "CoconutSDK", targets: ["CoconutSDK"])
    ],
    targets: [
        .target(
            name: "CoconutSDK",
            path: "Sources/CoconutSDK"
        )
    ]
)
