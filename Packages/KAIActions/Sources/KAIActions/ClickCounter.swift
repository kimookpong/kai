import CoreGraphics

/// Counts consecutive clicks the way the system does: a click close in time and place to the previous one
/// is the next click of a multi-click. macOS only treats synthetic events as a double click when the event
/// carries the right click count, so the mouse controller sets it from here.
public struct ClickCounter: Sendable {
    public var interval: Double
    public var distance: Double
    private var lastTime: Double?
    private var lastPoint = CGPoint.zero
    private var count = 0

    public init(interval: Double = 0.5, distance: Double = 8) {
        self.interval = interval
        self.distance = distance
    }

    /// Registers a button press and returns its click count (1 for a single click, 2 for a double click, ...).
    public mutating func register(at point: CGPoint, time: Double) -> Int {
        if let lastTime, time - lastTime <= interval,
            hypot(point.x - lastPoint.x, point.y - lastPoint.y) <= distance
        {
            count += 1
        } else {
            count = 1
        }
        lastTime = time
        lastPoint = point
        return count
    }
}
