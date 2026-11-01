import Foundation

/// User-adjustable settings. Defaults come from the Phase 0 spike and are meant to be overwritten by its results.
public struct KAIConfig: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var schemaVersion: Int = KAIConfig.currentVersion
    public var gesture = Gesture()
    public var privacy = Privacy()

    public init() {}

    public struct Gesture: Codable, Sendable, Equatable {
        public var anchor = "mcp"
        public var mapping = "absolute"
        public var filterMinCutoff = 1.0
        public var filterBeta = 0.05
        public var pinchDown = 0.30
        public var pinchUp = 0.45
        public var freezeMs = 150.0
        public init() {}
    }

    public struct Privacy: Codable, Sendable, Equatable {
        public var allowCloudAI = false
        public init() {}
    }
}

public enum ConfigError: Error, Equatable {
    case newerThanSupported(found: Int, supported: Int)
}

/// JSON config stored in Application Support/KAI. Location is injectable for tests.
public struct ConfigStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func standard() -> ConfigStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ConfigStore(url: base.appendingPathComponent("KAI/config.json"))
    }

    /// Missing file yields defaults. A file written by a newer KAI is refused rather than overwritten.
    public func load() throws -> KAIConfig {
        guard FileManager.default.fileExists(atPath: url.path) else { return KAIConfig() }
        let data = try Data(contentsOf: url)
        let version = try JSONDecoder().decode(VersionProbe.self, from: data).schemaVersion
        if version > KAIConfig.currentVersion {
            throw ConfigError.newerThanSupported(found: version, supported: KAIConfig.currentVersion)
        }
        let migrated = try Self.migrate(data, from: version)
        return try JSONDecoder().decode(KAIConfig.self, from: migrated)
    }

    public func save(_ config: KAIConfig) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }

    /// Add a case per schema bump, transforming the raw JSON up one version at a time.
    static func migrate(_ data: Data, from version: Int) throws -> Data {
        data
    }

    private struct VersionProbe: Decodable { let schemaVersion: Int }
}
