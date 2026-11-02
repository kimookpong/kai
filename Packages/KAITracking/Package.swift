// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KAITracking",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KAITracking", targets: ["KAITracking"])],
    targets: [
        .target(name: "KAITracking"),
        .testTarget(name: "KAITrackingTests", dependencies: ["KAITracking"]),
    ]
)
