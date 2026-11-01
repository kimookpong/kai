import Darwin
import Foundation

final class Metrics {
    private let lock = NSLock()
    private var latenciesMs: [Double] = []
    private var visionMs: [Double] = []
    private var frames = 0
    private var framesWithHand = 0
    private var startWall = CFAbsoluteTimeGetCurrent()
    private var startCPU = Metrics.cpuSeconds()
    private var confidences: [Float] = []
    private(set) var clicks = 0

    static func cpuSeconds() -> Double {
        var u = rusage()
        getrusage(RUSAGE_SELF, &u)
        func s(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1e6 }
        return s(u.ru_utime) + s(u.ru_stime)
    }

    func recordFrame(hand: Bool, visionSeconds: Double, confidence: Float?) {
        lock.lock(); defer { lock.unlock() }
        frames += 1
        visionMs.append(visionSeconds * 1000)
        if hand { framesWithHand += 1 }
        if let c = confidence { confidences.append(c) }
    }

    func recordLatency(captureTime: Double) {
        let now = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
        lock.lock(); defer { lock.unlock() }
        latenciesMs.append((now - captureTime) * 1000)
    }

    func recordClick() { lock.lock(); clicks += 1; lock.unlock() }

    static func percentile(_ v: [Double], _ p: Double) -> Double {
        guard !v.isEmpty else { return .nan }
        let s = v.sorted()
        return s[min(s.count - 1, Int(Double(s.count) * p))]
    }

    func report(label: String = "SUMMARY") -> String {
        lock.lock(); defer { lock.unlock() }
        let wall = CFAbsoluteTimeGetCurrent() - startWall
        let cpu = (Metrics.cpuSeconds() - startCPU) / wall * 100
        func f(_ x: Double) -> String { x.isNaN ? "n/a" : String(format: "%.1f", x) }
        return """
        --- \(label) (\(f(wall))s) ---
        fps:               \(f(Double(frames) / wall))
        hand detected:     \(f(frames == 0 ? 0 : Double(framesWithHand) / Double(frames) * 100))% of frames
        vision inference:  p50 \(f(Metrics.percentile(visionMs, 0.5))) ms · p95 \(f(Metrics.percentile(visionMs, 0.95))) ms
        latency (capture→post): p50 \(f(Metrics.percentile(latenciesMs, 0.5))) ms · p95 \(f(Metrics.percentile(latenciesMs, 0.95))) ms
        cpu:               \(f(cpu))% of one core
        clicks:            \(clicks)
        """
    }

    func resetWindow() {
        lock.lock(); defer { lock.unlock() }
        latenciesMs.removeAll(); visionMs.removeAll(); frames = 0; framesWithHand = 0
        confidences.removeAll(); clicks = 0
        startWall = CFAbsoluteTimeGetCurrent(); startCPU = Metrics.cpuSeconds()
    }
}

import CoreMedia
