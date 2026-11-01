import OSLog

public enum KAILog {
    public static let subsystem = "ai.kai.app"

    public enum Category: String, Sendable {
        case app, config, permissions, camera, tracking, gesture, actions, voice, agent, policy, audit
    }

    public static func logger(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
