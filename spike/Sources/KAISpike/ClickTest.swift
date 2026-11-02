import AppKit

/// Full-screen target-clicking test (P0-09). 10 trials each at 24 / 44 / 64 pt, shuffled.
/// Works with real mouse events, including the ones KAI posts.
final class ClickTest {
    struct Trial { let size: CGFloat; var center: CGPoint; var hit = false; var error: CGFloat = 0; var dx: CGFloat = 0; var dy: CGFloat = 0; var ms: Double = 0; var speed: Double = 0 }

    private var trials: [Trial] = []
    private var index = 0
    private var shownAt = CFAbsoluteTimeGetCurrent()
    private let window: NSWindow
    private let view: TargetView
    private let onDone: (String) -> Void

    init(onDone: @escaping (String) -> Void) {
        self.onDone = onDone
        let frame = NSScreen.main!.frame
        view = TargetView(frame: CGRect(origin: .zero, size: frame.size))
        window = KeyWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .floating
        window.backgroundColor = NSColor(white: 0.08, alpha: 1)
        window.contentView = view
        window.makeFirstResponder(view)

        let margin: CGFloat = 100
        for size in [24, 44, 64] as [CGFloat] {
            for _ in 0..<10 {
                let c = CGPoint(x: .random(in: margin...(frame.width - margin)),
                                y: .random(in: margin...(frame.height - margin)))
                trials.append(Trial(size: size, center: c))
            }
        }
        trials.shuffle()
        view.onClick = { [weak self] p in self?.handleClick(p) }
        view.onEscape = { [weak self] in self?.finish() }
    }

    func start() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        show()
    }

    private func show() {
        view.target = (trials[index].center, trials[index].size)
        view.status = "\(index + 1) / \(trials.count) · Esc to quit"
        view.needsDisplay = true
        shownAt = CFAbsoluteTimeGetCurrent()
    }

    private func handleClick(_ p: CGPoint) {
        var t = trials[index]
        t.dx = p.x - t.center.x
        t.dy = p.y - t.center.y
        t.error = hypot(t.dx, t.dy)
        t.speed = lastClickSpeed
        t.hit = t.error <= t.size / 2
        t.ms = (CFAbsoluteTimeGetCurrent() - shownAt) * 1000
        trials[index] = t
        index += 1
        if index >= trials.count { finish() } else { show() }
    }

    private func finish() {
        let done = Array(trials.prefix(index))
        var lines = ["--- CLICK TEST (\(done.count) trials) ---"]
        for size in [24, 44, 64] as [CGFloat] {
            let t = done.filter { $0.size == size }
            guard !t.isEmpty else { continue }
            let hits = t.filter(\.hit).count
            let err = t.map { Double($0.error) }.reduce(0, +) / Double(t.count)
            let ms = t.map(\.ms).reduce(0, +) / Double(t.count)
            lines.append(String(format: "%2.0f pt: hit %d/%d (%.0f%%) · mean error %.1f px · mean time %.0f ms",
                                size, hits, t.count, Double(hits) / Double(t.count) * 100, err, ms))
        }
        if !done.isEmpty {
            func mean(_ v: [Double]) -> Double { v.reduce(0, +) / Double(v.count) }
            func sd(_ v: [Double]) -> Double {
                let m = mean(v)
                return (v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(v.count - 1, 1))).squareRoot()
            }
            let dxs = done.map { Double($0.dx) }, dys = done.map { Double($0.dy) }
            let errs = done.map { Double($0.error) }.sorted()
            lines.append(String(format: "bias (mean signed offset, +x right / +y down): dx %+.0f px · dy %+.0f px", mean(dxs), mean(dys)))
            lines.append(String(format: "scatter (std):                                  dx %.0f px · dy %.0f px", sd(dxs), sd(dys)))
            lines.append(String(format: "median error %.0f px", errs[errs.count / 2]))
            lines.append("per trial (size, dx, dy, cursor speed px/s at click):")
            for t in done { lines.append(String(format: "  %2.0f  %+5.0f %+5.0f  %6.0f", t.size, t.dx, t.dy, t.speed)) }
        }
        onDone(lines.joined(separator: "\n"))
    }
}

private final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class TargetView: NSView {
    var target: (center: CGPoint, size: CGFloat)?
    var status = ""
    var onClick: ((CGPoint) -> Void)?
    var onEscape: (() -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        if let t = target {
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: CGRect(x: t.center.x - t.size / 2, y: t.center.y - t.size / 2,
                                        width: t.size, height: t.size)).fill()
        }
        (status as NSString).draw(at: CGPoint(x: 20, y: 20),
                                  withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 14)])
    }

    override func mouseDown(with event: NSEvent) { onClick?(convert(event.locationInWindow, from: nil)) }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onEscape?() } }
}
