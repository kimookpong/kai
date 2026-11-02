import CoreGraphics
import KAITracking

public enum GestureState: Sendable, Equatable {
    /// Not engaged, or no hand in view.
    case idle
    case tracking
    case pinching
}

public enum GestureEvent: Sendable, Equatable {
    /// Filtered pointer position in normalized camera coordinates (mirrored, y up).
    case pointerMoved(CGPoint)
    /// A pinch started. The position is where the pointer was just before the fingers closed.
    case pinchBegan(at: CGPoint)
    case pinchEnded
    case handLost
}

/// Per-frame gesture recognition: filtering, pinch detection and the gesture state machine.
///
/// Fast path: no allocation beyond a small history buffer, no blocking, no dependency on the agent layer.
/// Nothing here touches macOS; it only emits events for the action layer to execute.
public struct GestureEngine: Sendable {
    public private(set) var state: GestureState = .idle

    private let config: GestureConfig
    private var filterX: OneEuroFilter
    private var filterY: OneEuroFilter
    private var pinch: PinchDetector
    private var history: [(time: Double, point: CGPoint)] = []
    private var freezeUntil = 0.0

    private static let scale = 1000.0
    private static let historySeconds = 0.5

    public init(config: GestureConfig = GestureConfig()) {
        self.config = config
        filterX = OneEuroFilter(minCutoff: config.filterMinCutoff, beta: config.filterBeta)
        filterY = OneEuroFilter(minCutoff: config.filterMinCutoff, beta: config.filterBeta)
        pinch = PinchDetector(config: config)
    }

    /// `engaged` is the clutch: nothing is recognized while it is false (no Midas touch).
    public mutating func process(_ frame: HandFrame, engaged: Bool) -> [GestureEvent] {
        guard engaged else { return disengage(emitHandLost: false) }
        guard let hand = frame.hand, let anchor = hand.anchor(config.anchor), let ratio = hand.pinchRatio else {
            return disengage(emitHandLost: true)
        }

        let t = frame.timestamp
        let point = CGPoint(
            x: filterX.filter(anchor.x * Self.scale, at: t) / Self.scale,
            y: filterY.filter(anchor.y * Self.scale, at: t) / Self.scale)
        history.append((t, point))
        history.removeAll { t - $0.time > Self.historySeconds }

        let lookback = history.first { t - $0.time <= config.latchSeconds }
        var speed = 0.0
        if let lookback, t > lookback.time {
            speed = Double(hypot(point.x - lookback.point.x, point.y - lookback.point.y)) / (t - lookback.time)
        }

        var events: [GestureEvent] = []
        switch pinch.update(ratio: ratio, speed: speed) {
        case .began:
            state = .pinching
            freezeUntil = t + config.freezeSeconds
            events.append(.pinchBegan(at: lookback?.point ?? point))
        case .ended:
            state = .tracking
            events.append(.pinchEnded)
        case nil:
            if state == .idle { state = .tracking }
        }

        if !(state == .pinching && t < freezeUntil) { events.append(.pointerMoved(point)) }
        return events
    }

    private mutating func disengage(emitHandLost: Bool) -> [GestureEvent] {
        var events: [GestureEvent] = []
        if pinch.handLost() == .ended { events.append(.pinchEnded) }
        if emitHandLost && state != .idle { events.append(.handLost) }
        state = .idle
        filterX.reset()
        filterY.reset()
        history.removeAll()
        return events
    }
}
