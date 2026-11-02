import CoreGraphics

/// Maps a normalized camera position (mirrored, y up) to a point on screen (y down).
///
/// Only the middle `region` of the camera frame is used, so the hand does not have to reach the frame edges
/// to reach the screen edges. Phase 0 used 0.2 to 0.8; a narrower region amplifies hand tremor.
public struct PointerMapper: Sendable, Equatable {
    public var screen: CGRect
    public var regionLow: Double
    public var regionHigh: Double

    public init(screen: CGRect, regionLow: Double = 0.2, regionHigh: Double = 0.8) {
        self.screen = screen
        self.regionLow = regionLow
        self.regionHigh = regionHigh
    }

    public func screenPoint(forNormalized p: CGPoint) -> CGPoint {
        let span = regionHigh - regionLow
        let nx = min(max((p.x - regionLow) / span, 0), 1)
        let ny = min(max((p.y - regionLow) / span, 0), 1)
        return CGPoint(
            x: screen.minX + nx * (screen.width - 1),
            y: screen.minY + (1 - ny) * (screen.height - 1))
    }
}
