// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KAIActions",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KAIActions", targets: ["KAIActions"])],
    targets: [
        .target(name: "KAIActions"),
        .testTarget(name: "KAIActionsTests", dependencies: ["KAIActions"]),
    ]
)
