// swift-tools-version: 5.9

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
