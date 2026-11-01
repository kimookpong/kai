import ApplicationServices
import CoreGraphics

/// Posts mouse events. In dry-run mode only tracks the virtual position.
final class CursorController {
    private let dryRun: Bool
    private let bounds = CGDisplayBounds(CGMainDisplayID())
    private(set) var position: CGPoint
    private(set) var isDown = false

    init(dryRun: Bool) {
        self.dryRun = dryRun
        self.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    static func checkAccessibility() -> Bool { AXIsProcessTrusted() }

    var screenSize: CGSize { bounds.size }

    func move(to p: CGPoint) {
        let clamped = CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX - 1),
                              y: min(max(p.y, bounds.minY), bounds.maxY - 1))
        position = clamped
        post(isDown ? .leftMouseDragged : .mouseMoved)
    }

    func mouseDown() { isDown = true; post(.leftMouseDown) }
    func mouseUp() { isDown = false; post(.leftMouseUp) }

    private func post(_ type: CGEventType) {
        guard !dryRun else { return }
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: position, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
