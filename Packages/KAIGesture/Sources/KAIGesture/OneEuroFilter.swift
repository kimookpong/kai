import Foundation

/// One Euro Filter (Casiez et al., CHI 2012): smooth at low speed, responsive at high speed.
/// Feed it values in a scale where typical speeds are tens to hundreds of units per second;
/// the gesture engine uses milli-frame units (1000 per frame width) for that reason.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var dCutoff: Double

    private var previous: Double?
    private var previousDerivative = 0.0
    private var previousTime = 0.0

    public init(minCutoff: Double = 1.0, beta: Double = 0.05, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    public mutating func reset() {
        previous = nil
        previousDerivative = 0
    }

    public mutating func filter(_ value: Double, at time: Double) -> Double {
        guard let prev = previous else {
            previous = value
            previousTime = time
            return value
        }
        let dt = max(time - previousTime, 1e-4)
        let derivative = lowPass((value - prev) / dt, previousDerivative, alpha(dt, dCutoff))
        let cutoff = minCutoff + beta * abs(derivative)
        let result = lowPass(value, prev, alpha(dt, cutoff))
        previous = result
        previousDerivative = derivative
        previousTime = time
        return result
    }

    private func alpha(_ dt: Double, _ cutoff: Double) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    private func lowPass(_ x: Double, _ prev: Double, _ a: Double) -> Double { a * x + (1 - a) * prev }
}
