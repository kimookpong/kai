import CoreGraphics
import Foundation
import KAIActions
import KAIGesture
import KAITracking

/// Connects camera frames to the mouse: tracker -> gesture engine -> action mapper -> mouse.
///
/// Fast path. `handle` runs on the camera queue and never touches the main thread or the event bus.
/// All state used by `handle` is created in `init`/`start` before frames flow and only touched on that queue.
public final class GestureSession: @unchecked Sendable {
    private let tracker: HandTrackingProvider
    private let mouse: MouseControlling
    private let pointer: PointerMapper
    private let actions: ActionMapper
    private let gestureConfig: GestureConfig
    private var engine: GestureEngine
    private let lowPowerAfter: Double
    private var lastHandTime: Double?
    private var isLowPower = false
    /// The action each finger pressed, so the matching button is the one released.
    private var held: [PinchFinger: GestureAction] = [:]

    public init(
        config: GestureConfig,
        tracker: HandTrackingProvider = AppleVisionTracker(),
        mouse: MouseControlling = MouseController(),
        screen: CGRect = CGDisplayBounds(CGMainDisplayID()),
        actions: ActionMapper = ActionMapper(),
        lowPowerAfter: Double = 2.0
    ) {
        self.lowPowerAfter = lowPowerAfter
        gestureConfig = config
        engine = GestureEngine(config: config)
        self.tracker = tracker
        self.mouse = mouse
        self.actions = actions
        pointer = PointerMapper(screen: screen)
    }

    public func start() throws {
        engine = GestureEngine(config: gestureConfig)
        lastHandTime = nil
        isLowPower = false
        tracker.onFrame = { [weak self] frame in self?.handle(frame) }
        try tracker.start()
    }

    /// Stops the camera and makes sure no mouse button stays held.
    public func stop() {
        tracker.onFrame = nil
        tracker.stop()
        mouse.releaseLeft()
        mouse.releaseRight()
    }

    public func handle(_ frame: HandFrame) {
        updatePower(for: frame)
        for event in engine.process(frame, engaged: true) {
            switch event {
            case .pointerMoved(let p):
                mouse.move(to: pointer.screenPoint(forNormalized: p))
            case .pinchBegan(let p, let finger):
                mouse.move(to: pointer.screenPoint(forNormalized: p))
                let action = actions.action(for: finger.gestureName)
                held[finger] = action
                switch action {
                case .leftButton: mouse.pressLeft()
                case .rightButton: mouse.pressRight()
                case .none: break
                }
            case .pinchEnded(let finger):
                switch held.removeValue(forKey: finger) {
                case .leftButton: mouse.releaseLeft()
                case .rightButton: mouse.releaseRight()
                case .some(.none), nil: break
                }
            case .handLost:
                break
            }
        }
    }

    /// Drops the camera rate when the hand has been out of view for a while and restores it when it returns.
    /// The first frame counts as the last time a hand was seen, so a session that starts with no hand also idles.
    private func updatePower(for frame: HandFrame) {
        if frame.hand != nil || lastHandTime == nil { lastHandTime = frame.timestamp }
        let handVisible = frame.hand != nil
        if handVisible, isLowPower {
            isLowPower = false
            tracker.setLowPower(false)
        } else if !handVisible, !isLowPower, let seen = lastHandTime, frame.timestamp - seen > lowPowerAfter {
            isLowPower = true
            tracker.setLowPower(true)
        }
    }
}
