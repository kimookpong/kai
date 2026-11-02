import CoreGraphics
import KAITracking

public enum GestureState: Sendable, Equatable {
    /// Not engaged, or no hand in view.
    case idle
    case tracking
    case pinching
}

/// Which finger is pressed against the thumb.
public enum PinchFinger: String, Sendable, Equatable, CaseIterable {
    case index, middle

    /// The name used to look the gesture up in the `ActionMapper`.
    public var gestureName: String {
        switch self {
        case .index: "pinch"
        case .middle: "middlePinch"
        }
    }
}

public enum GestureEvent: Sendable, Equatable {
    /// Filtered pointer position in normalized camera coordinates (mirrored, y up).
    case pointerMoved(CGPoint)
    /// A pinch started. The position is where the pointer was just before the fingers closed.
    case pinchBegan(at: CGPoint, finger: PinchFinger)
    case pinchEnded(finger: PinchFinger)
    case handLost
}

/// Per-frame gesture recognition: filtering, pinch detection and the gesture state machine.
///
/// Fast path: no allocation beyond a small history buffer, no blocking, no dependency on the agent layer.
/// Nothing here touches macOS; it only emits events for the action layer to execute.
///
/// Index and middle fingers sit next to each other, so closing one tends to bring the other nearer the thumb too.
/// Only one pinch can be active: when none is, the finger closer to the thumb wins (a tie goes to the index);
/// while one is held, the other finger is ignored until it is released.
public struct GestureEngine: Sendable {
    public private(set) var state: GestureState = .idle

    private let config: GestureConfig
    private var filterX: OneEuroFilter
    private var filterY: OneEuroFilter
    private var detectors: [PinchFinger: PinchDetector]
    private var activeFinger: PinchFinger?
    private var history: [(time: Double, point: CGPoint)] = []
    private var freezeUntil = 0.0

    private static let scale = 1000.0
    private static let historySeconds = 0.5
    /// A ratio no pinch threshold can reach; feeding it keeps a detector idle.
    private static let open = 10.0

    public init(config: GestureConfig = GestureConfig()) {
        self.config = config
        filterX = OneEuroFilter(minCutoff: config.filterMinCutoff, beta: config.filterBeta)
        filterY = OneEuroFilter(minCutoff: config.filterMinCutoff, beta: config.filterBeta)
        detectors = Dictionary(uniqueKeysWithValues: PinchFinger.allCases.map { ($0, PinchDetector(config: config)) })
    }

    /// `engaged` is the clutch: nothing is recognized while it is false (no Midas touch).
    public mutating func process(_ frame: HandFrame, engaged: Bool) -> [GestureEvent] {
        guard engaged else { return disengage(emitHandLost: false) }
        guard let hand = frame.hand, let anchor = hand.anchor(config.anchor), let indexRatio = hand.pinchRatio else {
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

        let ratios = inputRatios(index: indexRatio, middle: hand.middlePinchRatio)
        var events: [GestureEvent] = []
        for finger in PinchFinger.allCases {
            switch detectors[finger]?.update(ratio: ratios[finger] ?? Self.open, speed: speed) {
            case .began:
                activeFinger = finger
                state = .pinching
                freezeUntil = t + config.freezeSeconds
                events.append(.pinchBegan(at: lookback?.point ?? point, finger: finger))
            case .ended:
                activeFinger = nil
                state = .tracking
                events.append(.pinchEnded(finger: finger))
            case nil:
                break
            }
        }
        if state == .idle { state = .tracking }

        if !(state == .pinching && t < freezeUntil) { events.append(.pointerMoved(point)) }
        return events
    }

    /// Decides which finger gets its real ratio this frame; the other one is held open.
    private func inputRatios(index: Double, middle: Double?) -> [PinchFinger: Double] {
        if let activeFinger {
            let real = activeFinger == .index ? index : (middle ?? Self.open)
            return [activeFinger: real]
        }
        if let middle, middle < index { return [.middle: middle] }
        return [.index: index]
    }

    private mutating func disengage(emitHandLost: Bool) -> [GestureEvent] {
        var events: [GestureEvent] = []
        for finger in PinchFinger.allCases where detectors[finger]?.handLost() == .ended {
            events.append(.pinchEnded(finger: finger))
        }
        if emitHandLost && state != .idle { events.append(.handLost) }
        activeFinger = nil
        state = .idle
        filterX.reset()
        filterY.reset()
        history.removeAll()
        return events
    }
}
