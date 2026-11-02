import KAITracking

/// Tunable gesture parameters. Defaults are the Phase 0 spike results.
public struct GestureConfig: Sendable, Equatable {
    public var anchor: AnchorKind = .mcp
    public var filterMinCutoff = 1.0
    public var filterBeta = 0.05
    /// Thumb-index distance / hand size below which the fingers count as pinched.
    public var pinchDown = 0.30
    /// Ratio above which a pinch is released. Higher than `pinchDown` so a hovering ratio cannot flicker.
    public var pinchUp = 0.45
    /// Consecutive frames below `pinchDown` before a pinch starts.
    public var pinchFrames = 2
    /// A pinch waits until the pointer is slower than this, in frame widths per second.
    /// 0.16 matches the spike's 400 px/s on a ~1500 px wide screen.
    public var maxPinchSpeed = 0.16
    /// The pointer holds still this long after a pinch starts, so the click lands where it was aimed.
    public var freezeSeconds = 0.15
    /// How far back the click position is taken from, to undo the pointer drift caused by closing the fingers.
    public var latchSeconds = 0.1

    public init() {}
}
