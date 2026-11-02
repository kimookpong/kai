// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KAIGesture",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KAIGesture", targets: ["KAIGesture"])],
    dependencies: [.package(path: "../KAITracking")],
    targets: [
        .target(name: "KAIGesture", dependencies: ["KAITracking"]),
        .testTarget(name: "KAIGestureTests", dependencies: ["KAIGesture"]),
    ]
)
