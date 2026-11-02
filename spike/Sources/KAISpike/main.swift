import AppKit
import AVFoundation
import Foundation

let config = Config.parse(CommandLine.arguments)
let metrics = Metrics()
let cursor = CursorController(dryRun: config.dryRun)
let tracker = HandTracker(anchor: config.anchor, minConfidence: config.minConfidence)
let filterX = OneEuroFilter(minCutoff: config.minCutoff, beta: config.beta)
let filterY = OneEuroFilter(minCutoff: config.minCutoff, beta: config.beta)

if config.selfTest {
    // Hand held still with 3px of noise, then a fast 600px/s sweep. 30 fps.
    var g = SystemRandomNumberGenerator()
    let fx = OneEuroFilter(minCutoff: config.minCutoff, beta: config.beta)
    var rawErr: [Double] = [], filtErr: [Double] = [], lag = 0.0
    for i in 0..<300 {
        let t = Double(i) / 30
        let truth = i < 150 ? 500.0 : 500.0 + 600 * (t - 5)
        let noisy = truth + Double.random(in: -3...3, using: &g)
        let out = fx.filter(noisy, at: t)
        if i >= 30 && i < 150 { rawErr.append(noisy - truth); filtErr.append(out - truth) }
        if i == 299 { lag = truth - out }
    }
    func rms(_ v: [Double]) -> Double { (v.map { $0 * $0 }.reduce(0, +) / Double(v.count)).squareRoot() }
    print(String(format: "still: raw rms %.2f px → filtered rms %.2f px", rms(rawErr), rms(filtErr)))
    print(String(format: "sweep 600 px/s: steady-state lag %.1f px", lag))
    exit(0)
}

print("anchor=\(config.anchor.rawValue) mode=\(config.mode.rawValue) dryRun=\(config.dryRun) minCutoff=\(config.minCutoff) beta=\(config.beta)")
if !config.dryRun && !CursorController.checkAccessibility() {
    print("⚠️  Accessibility permission missing for this process — mouse events will be ignored.")
    print("   System Settings → Privacy & Security → Accessibility → enable your terminal app.")
}

// MARK: pipeline state (touched only on the camera queue)
var pinched = false
var pinchFrames = 0
/// After losing the hand mid-pinch, the fingers must open before another click can fire.
var needsRearm = false
/// Cursor speed (px/s over the previous 100 ms) at the moment the last pinch fired. Read by ClickTest.
var lastClickSpeed = 0.0
var freezeUntil = 0.0
var frozenAt = CGPoint.zero
var lastNorm: CGPoint?
var history: [(t: Double, p: CGPoint)] = []

// Jitter capture
var stillStart: Double?
var stillRaw: [CGPoint] = []
var stillFiltered: [CGPoint] = []
let stillWait = 6.0, stillLen = 5.0
let wallStart = CFAbsoluteTimeGetCurrent()

func lerpToScreen(_ n: CGPoint) -> CGPoint {
    let span = config.regionHi - config.regionLo
    let nx = min(max((n.x - config.regionLo) / span, 0), 1)
    let ny = min(max((n.y - config.regionLo) / span, 0), 1)
    let s = cursor.screenSize
    return CGPoint(x: nx * s.width, y: (1 - ny) * s.height)
}

func std(_ v: [Double]) -> Double {
    guard v.count > 1 else { return .nan }
    let m = v.reduce(0, +) / Double(v.count)
    return (v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count - 1)).squareRoot()
}

tracker.onSample = { sample, visionSeconds in
    metrics.recordFrame(hand: sample != nil, visionSeconds: visionSeconds, confidence: sample?.confidence)
    guard let s = sample else {
        if pinched { cursor.mouseUp(); pinched = false; needsRearm = true }
        pinchFrames = 0
        filterX.reset(); filterY.reset(); lastNorm = nil
        return
    }
    let t = s.captureTime
    // Filter in milli-frame units (~1000 per frame width) so beta behaves like the pixel-based selftest.
    let nx = filterX.filter(s.anchor.x * 1000, at: t) / 1000
    let ny = filterY.filter(s.anchor.y * 1000, at: t) / 1000
    let norm = CGPoint(x: nx, y: ny)

    var target: CGPoint
    switch config.mode {
    case .absolute:
        target = lerpToScreen(norm)
    case .relative:
        defer { lastNorm = norm }
        guard let prev = lastNorm else { return }
        target = CGPoint(x: cursor.position.x + (norm.x - prev.x) * config.relativeGain,
                         y: cursor.position.y - (norm.y - prev.y) * config.relativeGain)
    }

    history.append((t, target))
    history.removeAll { t - $0.t > 0.5 }

    // Cursor speed over the previous 100 ms.
    let past = history.first(where: { t - $0.t <= 0.1 })
    var speed = 0.0
    if let past, t > past.t { speed = Double(hypot(target.x - past.p.x, target.y - past.p.y)) / (t - past.t) }

    // Pinch with hysteresis, debounce and a speed gate; freeze the cursor so the click lands where the user aimed.
    if needsRearm && s.pinchRatio > config.pinchUp { needsRearm = false }
    if !pinched {
        pinchFrames = (!needsRearm && s.pinchRatio < config.pinchDown) ? pinchFrames + 1 : 0
    }
    if !pinched && pinchFrames >= config.pinchFrames && speed <= config.maxClickSpeed {
        pinched = true
        pinchFrames = 0
        frozenAt = past?.p ?? target
        lastClickSpeed = speed
        freezeUntil = t + config.freezeMs / 1000
        cursor.move(to: frozenAt)
        cursor.mouseDown()
        metrics.recordClick()
    } else if pinched && s.pinchRatio > config.pinchUp {
        pinched = false
        cursor.mouseUp()
    }
    if !(pinched && t < freezeUntil) { cursor.move(to: target) }

    metrics.recordLatency(captureTime: t)

    if config.stillTest {
        let elapsed = CFAbsoluteTimeGetCurrent() - wallStart
        if elapsed >= stillWait && elapsed < stillWait + stillLen {
            let screen = lerpToScreen(CGPoint(x: s.anchor.x, y: s.anchor.y))
            stillRaw.append(screen)
            stillFiltered.append(lerpToScreen(norm))
        }
    }
}

func finish(extra: String? = nil) {
    tracker.stop()
    if pinched { cursor.mouseUp() }
    print("\n" + metrics.report())
    if !tracker.drops.isEmpty {
        print("--- DROPPED FRAMES ---")
        for (k, v) in tracker.drops.sorted(by: { $0.value > $1.value }) { print("\(v)\t\(k)") }
    }
    if let extra { print(extra) }
    if config.stillTest {
        print("--- JITTER (hand held still, \(stillRaw.count) samples) ---")
        func line(_ name: String, _ pts: [CGPoint]) {
            let sx: Double = std(pts.map { Double($0.x) })
            let sy: Double = std(pts.map { Double($0.y) })
            print(name + String(format: " σx %.2f px · σy %.2f px", sx, sy))
        }
        line("raw     ", stillRaw)
        line("filtered", stillFiltered)
        // Frame-to-frame step size: high-frequency noise, independent of slow hand drift.
        func step(_ name: String, _ pts: [CGPoint]) {
            let d = zip(pts.dropFirst(), pts).map { Double(hypot($0.x - $1.x, $0.y - $1.y)) }
            guard !d.isEmpty else { return }
            let rms = (d.map { $0 * $0 }.reduce(0, +) / Double(d.count)).squareRoot()
            print(name + String(format: " frame-to-frame step: rms %.2f px · p95 %.2f px", rms, Metrics.percentile(d, 0.95)))
        }
        step("raw     ", stillRaw)
        step("filtered", stillFiltered)
    }
    exit(0)
}

AVCaptureDevice.requestAccess(for: .video) { granted in
    guard granted else {
        print("Camera permission denied. Enable it for your terminal app in System Settings → Privacy & Security → Camera.")
        exit(1)
    }
    do { try tracker.start() } catch { print("error: \(error.localizedDescription)"); exit(1) }
    if config.stillTest { print("still test: hold your hand steady — capture starts in \(Int(stillWait))s for \(Int(stillLen))s") }
}

signal(SIGINT, SIG_IGN)
let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigSource.setEventHandler { finish() }
sigSource.resume()

let tick = DispatchSource.makeTimerSource(queue: .main)
tick.schedule(deadline: .now() + 1, repeating: 1)
tick.setEventHandler {
    let elapsed = CFAbsoluteTimeGetCurrent() - wallStart
    if let d = config.duration, elapsed >= d { finish() }
    if config.stillTest, elapsed >= stillWait + stillLen { finish() }
}
tick.resume()

if config.clickTest {
    guard !config.dryRun else { print("--click-test needs live events; drop --dry-run"); exit(1) }
    _ = NSApplication.shared
    let test = ClickTest { report in finish(extra: report) }
    DispatchQueue.main.async { test.start() }
    NSApp.run()
} else {
    dispatchMain()
}
