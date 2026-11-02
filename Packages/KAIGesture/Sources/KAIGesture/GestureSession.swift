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

    public init(
        config: GestureConfig,
        tracker: HandTrackingProvider = AppleVisionTracker(),
        mouse: MouseControlling = MouseController(),
        screen: CGRect = CGDisplayBounds(CGMainDisplayID()),
        actions: ActionMapper = ActionMapper()
    ) {
        gestureConfig = config
        engine = GestureEngine(config: config)
        self.tracker = tracker
        self.mouse = mouse
        self.actions = actions
        pointer = PointerMapper(screen: screen)
    }

    public func start() throws {
        engine = GestureEngine(config: gestureConfig)
        tracker.onFrame = { [weak self] frame in self?.handle(frame) }
        try tracker.start()
    }

    /// Stops the camera and makes sure no mouse button stays held.
    public func stop() {
        tracker.onFrame = nil
        tracker.stop()
        mouse.releaseLeft()
    }

    public func handle(_ frame: HandFrame) {
        for event in engine.process(frame, engaged: true) {
            switch event {
            case .pointerMoved(let p):
                mouse.move(to: pointer.screenPoint(forNormalized: p))
            case .pinchBegan(let p):
                mouse.move(to: pointer.screenPoint(forNormalized: p))
                if actions.action(for: "pinch") == .leftButton { mouse.pressLeft() }
            case .pinchEnded:
                mouse.releaseLeft()
            case .handLost:
                break
            }
        }
    }
}
