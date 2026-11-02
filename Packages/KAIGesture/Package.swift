// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KAIGesture",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KAIGesture", targets: ["KAIGesture"])],
    dependencies: [.package(path: "../KAITracking"), .package(path: "../KAIActions")],
    targets: [
        .target(name: "KAIGesture", dependencies: ["KAITracking", "KAIActions"]),
        .testTarget(name: "KAIGestureTests", dependencies: ["KAIGesture"]),
    ]
)
