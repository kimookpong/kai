import Foundation

/// Events exchanged between subsystems. Payloads stay small and Sendable.
/// Not for the fast path: cursor movement must not go through this bus.
public enum KAIEvent: Sendable, Equatable {
    case permissionChanged(Permission, PermissionStatus)
    case engagementChanged(isEngaged: Bool)
    case gestureDetected(name: String)
    case voiceCommandReceived(text: String)
    case applicationChanged(bundleID: String)
    case agentActionRequested(tool: String)
    case toolExecutionCompleted(tool: String, success: Bool)
}

/// Typed multi-subscriber event bus built on AsyncStream.
public actor EventBus {
    private var continuations: [UUID: AsyncStream<KAIEvent>.Continuation] = [:]

    public init() {}

    public func publish(_ event: KAIEvent) {
        for continuation in continuations.values { continuation.yield(event) }
    }

    /// Each call returns an independent stream. It is removed when the consumer stops iterating.
    public func subscribe(bufferingNewest limit: Int = 64) -> AsyncStream<KAIEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<KAIEvent>.makeStream(bufferingPolicy: .bufferingNewest(limit))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(id) }
        }
        return stream
    }

    public var subscriberCount: Int { continuations.count }

    private func remove(_ id: UUID) { continuations[id] = nil }
}
