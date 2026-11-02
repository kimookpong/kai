import CoreGraphics

/// Something that can move the pointer and press the primary button. Lets the gesture glue be tested without macOS.
public protocol MouseControlling: AnyObject {
    func move(to point: CGPoint)
    func pressLeft()
    func releaseLeft()
}

/// Posts real mouse events through CGEvent. Requires the Accessibility permission to take effect.
/// Not thread-safe: call from a single queue (the camera queue).
public final class MouseController: MouseControlling, @unchecked Sendable {
    public private(set) var position: CGPoint
    public private(set) var isLeftDown = false

    public init(start: CGPoint = CGPoint(x: 0, y: 0)) { position = start }

    public func move(to point: CGPoint) {
        position = point
        post(isLeftDown ? .leftMouseDragged : .mouseMoved)
    }

    public func pressLeft() {
        guard !isLeftDown else { return }
        isLeftDown = true
        post(.leftMouseDown)
    }

    /// Always safe to call; does nothing when the button is already up.
    public func releaseLeft() {
        guard isLeftDown else { return }
        isLeftDown = false
        post(.leftMouseUp)
    }

    private func post(_ type: CGEventType) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: position, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
