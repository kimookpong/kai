import Foundation

/// One Euro Filter (Casiez et al., CHI 2012). Smooth at low speed, responsive at high speed.
final class OneEuroFilter {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double

    private var xPrev: Double?
    private var dxPrev = 0.0
    private var tPrev = 0.0

    init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    func reset() { xPrev = nil; dxPrev = 0 }

    func filter(_ x: Double, at t: Double) -> Double {
        guard let prev = xPrev else {
            xPrev = x; tPrev = t
            return x
        }
        let dt = max(t - tPrev, 1e-4)
        let dx = (x - prev) / dt
        let edx = lowPass(dx, dxPrev, alpha(dt, dCutoff))
        let cutoff = minCutoff + beta * abs(edx)
        let result = lowPass(x, prev, alpha(dt, cutoff))
        xPrev = result; dxPrev = edx; tPrev = t
        return result
    }

    private func alpha(_ dt: Double, _ cutoff: Double) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    private func lowPass(_ x: Double, _ prev: Double, _ a: Double) -> Double {
        a * x + (1 - a) * prev
    }
}
