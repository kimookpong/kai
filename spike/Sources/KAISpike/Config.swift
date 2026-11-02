import Foundation

enum Anchor: String { case tip, mcp, palm }
enum MapMode: String { case absolute, relative }

struct Config {
    var anchor: Anchor = .mcp
    var mode: MapMode = .absolute
    var dryRun = false
    var duration: Double?
    var minCutoff = 1.0
    var beta = 0.05
    var stillTest = false
    var selfTest = false
    var minConfidence: Float = 0.3
    var clickTest = false
    /// Active region of the camera frame mapped to the full screen (normalized, mirrored).
    var regionLo = 0.2
    var regionHi = 0.8
    var relativeGain = 2500.0
    var pinchDown = 0.30
    var pinchUp = 0.45
    var freezeMs = 150.0
    var pinchFrames = 2
    /// Ignore a pinch while the cursor is faster than this (px/s); fires once it slows down.
    var maxClickSpeed = 400.0

    static func parse(_ args: [String]) -> Config {
        var c = Config()
        var i = 1
        func next() -> String? { i += 1; return i < args.count ? args[i] : nil }
        while i < args.count {
            switch args[i] {
            case "--anchor": if let v = next(), let a = Anchor(rawValue: v) { c.anchor = a }
            case "--mode": if let v = next(), let m = MapMode(rawValue: v) { c.mode = m }
            case "--dry-run": c.dryRun = true
            case "--duration": if let v = next() { c.duration = Double(v) }
            case "--min-cutoff": if let v = next(), let d = Double(v) { c.minCutoff = d }
            case "--beta": if let v = next(), let d = Double(v) { c.beta = d }
            case "--still-test": c.stillTest = true
            case "--min-conf": if let v = next(), let d = Float(v) { c.minConfidence = d }
            case "--pinch-frames": if let v = next(), let n = Int(v) { c.pinchFrames = max(1, n) }
            case "--max-click-speed": if let v = next(), let d = Double(v) { c.maxClickSpeed = d }
            case "--selftest": c.selfTest = true
            case "--click-test": c.clickTest = true
            case "--help", "-h": printUsage(); exit(0)
            default: FileHandle.standardError.write(Data("unknown arg: \(args[i])\n".utf8))
            }
            i += 1
        }
        return c
    }

    static func printUsage() {
        print("""
        kai-spike — Phase 0 hand tracking feasibility spike

          --anchor tip|mcp|palm      cursor anchor landmark (default mcp)
          --mode absolute|relative   mapping mode (default absolute)
          --dry-run                  track and measure, do not post mouse events
          --duration <sec>           stop after N seconds and print report
          --still-test               hold hand still: measure jitter (3s wait, 5s capture)
          --click-test               full-screen target test: 30 trials at 24/44/64 pt (needs live events)
          --min-conf <0-1>           minimum joint confidence (default 0.3)
          --pinch-frames <n>         consecutive frames below threshold to count as a pinch (default 2)
          --max-click-speed <px/s>   hold a pinch until cursor is slower than this (default 400)
          --selftest                 verify One Euro filter on synthetic noise (no camera)
          --min-cutoff <hz>          One Euro min cutoff (default 1.0)
          --beta <v>                 One Euro beta (default 0.05)

        Ctrl-C prints the summary report.
        """)
    }
}
