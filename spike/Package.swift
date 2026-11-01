// swift-tools-version: 6.0
import PackageDescription

// Phase 0 feasibility spike. Throwaway: not imported by the main app.
let package = Package(
    name: "KAISpike",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KAISpike",
            path: "Sources/KAISpike",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
