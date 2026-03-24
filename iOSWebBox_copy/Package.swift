// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iOSWebBox",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "HybridSDK",
            targets: ["HybridSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .target(
            name: "HybridSDK",
            dependencies: ["Alamofire"],
            path: "iOSWebBox/HybridSDK",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
