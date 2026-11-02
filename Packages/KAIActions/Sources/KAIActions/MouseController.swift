import CoreGraphics
import Foundation

/// Something that can move the pointer and press the primary button. Lets the gesture glue be tested without macOS.
public protocol MouseControlling: AnyObject {
    func move(to point: CGPoint)
    func pressLeft()
    func releaseLeft()
    func pressRight()
    func releaseRight()
}

/// Posts real mouse events through CGEvent. Requires the Accessibility permission to take effect.
/// Not thread-safe: call from a single queue (the camera queue).
public final class MouseController: MouseControlling, @unchecked Sendable {
    public private(set) var position: CGPoint
    public private(set) var isLeftDown = false
    public private(set) var isRightDown = false
    private var clicks = ClickCounter()
    private var clickCount = 1

    public init(start: CGPoint = CGPoint(x: 0, y: 0)) { position = start }

    public func move(to point: CGPoint) {
        position = point
        if isLeftDown {
            post(.leftMouseDragged)
        } else if isRightDown {
            post(.rightMouseDragged)
        } else {
            post(.mouseMoved)
        }
    }

    public func pressLeft() {
        guard !isLeftDown else { return }
        isLeftDown = true
        clickCount = clicks.register(at: position, time: ProcessInfo.processInfo.systemUptime)
        post(.leftMouseDown)
    }

    /// Always safe to call; does nothing when the button is already up.
    public func releaseLeft() {
        guard isLeftDown else { return }
        isLeftDown = false
        post(.leftMouseUp)
    }

    public func pressRight() {
        guard !isRightDown else { return }
        isRightDown = true
        post(.rightMouseDown)
    }

    public func releaseRight() {
        guard isRightDown else { return }
        isRightDown = false
        post(.rightMouseUp)
    }

    private func post(_ type: CGEventType) {
        guard
            let event = CGEvent(
                mouseEventSource: nil, mouseType: type, mouseCursorPosition: position,
                mouseButton: isRightEvent(type) ? .right : .left)
        else { return }
        if type == .leftMouseDown || type == .leftMouseUp {
            event.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        }
        event.post(tap: .cghidEventTap)
    }

    private func isRightEvent(_ type: CGEventType) -> Bool {
        type == .rightMouseDown || type == .rightMouseUp || type == .rightMouseDragged
    }
}
