import CoreGraphics
import KAIActions
import KAITracking
import Testing

@testable import KAIGesture

private final class FakeTracker: HandTrackingProvider, @unchecked Sendable {
    var onFrame: (@Sendable (HandFrame) -> Void)?
    private(set) var started = false
    private(set) var stopped = false
    func start() throws { started = true }
    func stop() { stopped = true }
}

private final class FakeMouse: MouseControlling {
    enum Call: Equatable { case move(CGPoint), press, release, pressRight, releaseRight }
    private(set) var calls: [Call] = []
    private var down = false
    private var rightDown = false
    func move(to point: CGPoint) { calls.append(.move(point)) }
    func pressLeft() {
        down = true
        calls.append(.press)
    }
    func releaseLeft() {
        guard down else { return }
        down = false
        calls.append(.release)
    }
    func pressRight() {
        rightDown = true
        calls.append(.pressRight)
    }
    func releaseRight() {
        guard rightDown else { return }
        rightDown = false
        calls.append(.releaseRight)
    }
}

private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

private func frame(_ t: Double, ratio: Double = 1.0, middle: Double? = nil) -> HandFrame {
    var joints: [Joint: Landmark] = [
        .wrist: Landmark(x: 0.5, y: 0.2),
        .middleMCP: Landmark(x: 0.5, y: 0.4),
        .thumbTip: Landmark(x: 0.5, y: 0.5),
        .indexTip: Landmark(x: 0.5 + ratio * 0.2, y: 0.5),
        .indexMCP: Landmark(x: 0.5, y: 0.5),
    ]
    if let middle { joints[.middleTip] = Landmark(x: 0.5 + middle * 0.2, y: 0.5) }
    return HandFrame(timestamp: t, hand: HandLandmarks(joints: joints))
}

@Suite struct GestureSessionTests {
    private func make() -> (GestureSession, FakeTracker, FakeMouse) {
        let tracker = FakeTracker()
        let mouse = FakeMouse()
        let session = GestureSession(config: GestureConfig(), tracker: tracker, mouse: mouse, screen: screen)
        return (session, tracker, mouse)
    }

    @Test func startBeginsTrackingAndRoutesFramesToTheMouse() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        #expect(tracker.started)
        tracker.onFrame?(frame(0))
        #expect(mouse.calls.count == 1)
        guard case .move(let p)? = mouse.calls.first else {
            Issue.record("expected a move")
            return
        }
        #expect(abs(p.x - 499.5) < 1e-6 && abs(p.y - 399.5) < 1e-6)
    }

    @Test func pinchMovesThenPressesAndReleasesWhenOpened() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        for i in 0..<5 { tracker.onFrame?(frame(Double(i) / 30)) }
        tracker.onFrame?(frame(5.0 / 30, ratio: 0.2))
        tracker.onFrame?(frame(6.0 / 30, ratio: 0.2))
        let beforeRelease = mouse.calls
        let pressIndex = try #require(beforeRelease.firstIndex(of: .press))
        #expect(pressIndex > 0)
        if case .move = beforeRelease[pressIndex - 1] {} else { Issue.record("press must follow a move") }

        tracker.onFrame?(frame(7.0 / 30, ratio: 0.9))
        let releaseIndex = try #require(mouse.calls.lastIndex(of: .release))
        #expect(releaseIndex > pressIndex)  // the button comes up before the pointer moves on
    }

    @Test func stopReleasesAHeldButtonAndStopsTheCamera() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        for i in 0..<8 { tracker.onFrame?(frame(Double(i) / 30, ratio: i < 5 ? 1.0 : 0.2)) }
        #expect(mouse.calls.contains(.press))
        session.stop()
        #expect(mouse.calls.last == .release)
        #expect(tracker.stopped)
        #expect(tracker.onFrame == nil)
    }

    @Test func middleFingerPinchPressesAndReleasesTheRightButton() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        for i in 0..<8 { tracker.onFrame?(frame(Double(i) / 30, ratio: 0.9, middle: i < 5 ? 0.9 : 0.2)) }
        #expect(mouse.calls.contains(.pressRight))
        #expect(!mouse.calls.contains(.press))
        tracker.onFrame?(frame(9.0 / 30, ratio: 0.9, middle: 0.9))
        #expect(mouse.calls.contains(.releaseRight))
        #expect(!mouse.calls.contains(.release))
    }

    @Test func stopReleasesAHeldRightButton() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        for i in 0..<8 { tracker.onFrame?(frame(Double(i) / 30, ratio: 0.9, middle: i < 5 ? 0.9 : 0.2)) }
        session.stop()
        #expect(mouse.calls.last == .releaseRight)
    }

    @Test func stopWithoutPinchDoesNotRelease() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        tracker.onFrame?(frame(0))
        session.stop()
        #expect(!mouse.calls.contains(.release))
    }

    @Test func lostHandNeverMovesTheMouse() throws {
        let (session, tracker, mouse) = make()
        try session.start()
        tracker.onFrame?(HandFrame(timestamp: 0, hand: nil))
        #expect(mouse.calls.isEmpty)
    }
}
