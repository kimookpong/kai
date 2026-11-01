// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KAICore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KAICore", targets: ["KAICore"])],
    targets: [
        .target(name: "KAICore"),
        .testTarget(name: "KAICoreTests", dependencies: ["KAICore"]),
    ]
)
