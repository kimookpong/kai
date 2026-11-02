/// Turns a per-frame pinch ratio into discrete began/ended events.
///
/// Guards that came out of the Phase 0 click test:
/// - hysteresis (`pinchDown` < `pinchUp`) and a frame debounce against flicker;
/// - a speed gate, so a pinch while the pointer is still travelling waits until it slows down;
/// - re-arming: after the hand is lost mid-pinch the fingers must open before another pinch can start,
///   otherwise dropped frames while the fingertips overlap fire the click again and again.
public struct PinchDetector: Sendable {
    public enum Output: Sendable, Equatable { case began, ended }

    private let config: GestureConfig
    public private(set) var isPinched = false
    private var consecutiveFrames = 0
    private var needsRearm = false

    public init(config: GestureConfig) { self.config = config }

    public mutating func update(ratio: Double, speed: Double) -> Output? {
        if needsRearm && ratio > config.pinchUp { needsRearm = false }
        if isPinched {
            guard ratio > config.pinchUp else { return nil }
            isPinched = false
            return .ended
        }
        consecutiveFrames = (!needsRearm && ratio < config.pinchDown) ? consecutiveFrames + 1 : 0
        if consecutiveFrames >= config.pinchFrames && speed <= config.maxPinchSpeed {
            isPinched = true
            consecutiveFrames = 0
            return .began
        }
        return nil
    }

    /// The hand disappeared. Ends an active pinch and requires the fingers to open before the next one.
    public mutating func handLost() -> Output? {
        let wasPinched = isPinched
        isPinched = false
        consecutiveFrames = 0
        needsRearm = true
        return wasPinched ? .ended : nil
    }
}
