import CoreGraphics

public enum Joint: String, Sendable, CaseIterable {
    case wrist, thumbTip, indexMCP, indexTip, middleMCP, middleTip, ringMCP, littleMCP
}

/// A joint position in normalized camera coordinates. Providers deliver these already mirrored
/// (moving the hand right increases x) with y pointing up, so consumers never deal with camera orientation.
public struct Landmark: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var confidence: Float

    public init(x: Double, y: Double, confidence: Float = 1) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

/// Which landmark drives the pointer. `mcp` (index knuckle) was the most accurate in the Phase 0 spike;
/// `tip` drifts downward when the fingers pinch.
public enum AnchorKind: String, Sendable, Codable, CaseIterable {
    case tip, mcp, palm
}

public struct HandLandmarks: Sendable, Equatable {
    public var joints: [Joint: Landmark]

    public init(joints: [Joint: Landmark]) { self.joints = joints }

    public func point(_ joint: Joint) -> Landmark? { joints[joint] }

    public func anchor(_ kind: AnchorKind) -> CGPoint? {
        switch kind {
        case .tip:
            return cgPoint(.indexTip)
        case .mcp:
            return cgPoint(.indexMCP)
        case .palm:
            let parts: [Joint] = [.wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP]
            let landmarks = parts.compactMap { joints[$0] }
            guard landmarks.count == parts.count else { return nil }
            let n = Double(landmarks.count)
            return CGPoint(x: landmarks.map(\.x).reduce(0, +) / n, y: landmarks.map(\.y).reduce(0, +) / n)
        }
    }

    /// Thumb-to-index distance divided by hand size (wrist to middle knuckle), so it is independent of
    /// how far the hand is from the camera. Nil when a joint is missing or the hand is too small to trust.
    public var pinchRatio: Double? { pinchRatio(to: .indexTip) }

    /// Same as `pinchRatio` but thumb to middle fingertip.
    public var middlePinchRatio: Double? { pinchRatio(to: .middleTip) }

    private func pinchRatio(to finger: Joint) -> Double? {
        guard let wrist = joints[.wrist], let middle = joints[.middleMCP],
            let thumb = joints[.thumbTip], let tip = joints[finger]
        else { return nil }
        let handSize = hypot(wrist.x - middle.x, wrist.y - middle.y)
        guard handSize > 0.01 else { return nil }
        return hypot(thumb.x - tip.x, thumb.y - tip.y) / handSize
    }

    private func cgPoint(_ joint: Joint) -> CGPoint? {
        joints[joint].map { CGPoint(x: $0.x, y: $0.y) }
    }
}

/// One camera frame's result. `hand` is nil when no hand was found.
public struct HandFrame: Sendable, Equatable {
    /// Capture time in seconds on a monotonic clock.
    public var timestamp: Double
    public var hand: HandLandmarks?

    public init(timestamp: Double, hand: HandLandmarks?) {
        self.timestamp = timestamp
        self.hand = hand
    }
}

/// Source of hand frames (Apple Vision today, possibly MediaPipe later).
/// Delivery is a callback rather than an AsyncStream because this sits on the real-time path.
public protocol HandTrackingProvider: AnyObject {
    var onFrame: (@Sendable (HandFrame) -> Void)? { get set }
    func start() throws
    func stop()
    /// Lowers the capture rate while no hand is in view, trading reaction time for CPU and battery.
    func setLowPower(_ on: Bool)
}
