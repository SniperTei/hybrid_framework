// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoconutSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "CoconutSDK", targets: ["CoconutSDK"])
    ],
    dependencies: [
        // HTTP 引擎（native-first；热更新下载走引擎管线：守卫/重试/bytes 模式）
        .package(path: "../CoconutNetwork")
    ],
    targets: [
        .target(
            name: "CoconutSDK",
            dependencies: [
                .product(name: "CoconutNetwork", package: "CoconutNetwork")
            ],
            path: "Sources/CoconutSDK",
            resources: [
                // Offline H5 package (coconut:// scheme) — .copy preserves the
                // coconut-web/<moduleId>/ directory structure in the bundle.
                .copy("Resources/coconut-web")
            ]
        ),
        .testTarget(
            name: "CoconutSDKTests",
            dependencies: [
                "CoconutSDK",
                .product(name: "CoconutNetwork", package: "CoconutNetwork")
            ],
            path: "Tests/CoconutSDKTests"
        )
    ]
)
