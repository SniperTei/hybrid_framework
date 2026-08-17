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
            path: "Sources/CoconutSDK",
            resources: [
                // Offline H5 package (coconut:// scheme) — .copy preserves the
                // coconut-web/<moduleId>/ directory structure in the bundle.
                .copy("Resources/coconut-web")
            ]
        ),
        .testTarget(
            name: "CoconutSDKTests",
            dependencies: ["CoconutSDK"],
            path: "Tests/CoconutSDKTests"
        )
    ]
)
