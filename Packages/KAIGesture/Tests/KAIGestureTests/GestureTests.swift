import CoreGraphics
import KAITracking
import Testing

@testable import KAIGesture

/// A hand whose index knuckle is at `at`, with the pinch ratio set directly (hand size 0.2).
private func frame(
    _ t: Double, at: CGPoint = CGPoint(x: 0.5, y: 0.5), ratio: Double = 1.0, middle: Double? = nil
) -> HandFrame {
    let size = 0.2
    var joints: [Joint: Landmark] = [
        .wrist: Landmark(x: 0.5, y: 0.2),
        .middleMCP: Landmark(x: 0.5, y: 0.2 + size),
        .thumbTip: Landmark(x: 0.5, y: 0.5),
        .indexTip: Landmark(x: 0.5 + ratio * size, y: 0.5),
        .indexMCP: Landmark(x: at.x, y: at.y),
    ]
    if let middle { joints[.middleTip] = Landmark(x: 0.5 + middle * size, y: 0.5) }
    return HandFrame(timestamp: t, hand: HandLandmarks(joints: joints))
}

private func isPointerMove(_ e: GestureEvent) -> Bool {
    if case .pointerMoved = e { true } else { false }
}

private func began(_ events: [GestureEvent]) -> PinchFinger? {
    for case .pinchBegan(_, let finger) in events { return finger }
    return nil
}

private func noHand(_ t: Double) -> HandFrame { HandFrame(timestamp: t, hand: nil) }

@Suite struct OneEuroFilterTests {
    @Test func reducesNoiseOnAStillSignal() {
        var filter = OneEuroFilter(minCutoff: 1.0, beta: 0.05)
        var noisy: [Double] = [], smooth: [Double] = []
        for i in 0..<120 {
            let value = 500 + (i % 2 == 0 ? 3.0 : -3.0)
            let out = filter.filter(value, at: Double(i) / 30)
            if i >= 30 {
                noisy.append(value - 500)
                smooth.append(out - 500)
            }
        }
        func rms(_ v: [Double]) -> Double { (v.map { $0 * $0 }.reduce(0, +) / Double(v.count)).squareRoot() }
        #expect(rms(smooth) < rms(noisy) / 2)
    }

    @Test func followsFastMovementClosely() {
        var filter = OneEuroFilter(minCutoff: 1.0, beta: 0.05)
        var last = 0.0, truth = 0.0
        for i in 0..<90 {
            truth = Double(i) / 30 * 600
            last = filter.filter(truth, at: Double(i) / 30)
        }
        #expect(truth - last < 15)
    }

    @Test func resetForgetsHistory() {
        var filter = OneEuroFilter()
        _ = filter.filter(0, at: 0)
        _ = filter.filter(0, at: 0.033)
        filter.reset()
        #expect(filter.filter(900, at: 5) == 900)
    }
}

@Suite struct PinchDetectorTests {
    private func detector() -> PinchDetector { PinchDetector(config: GestureConfig()) }

    @Test func needsConsecutiveFramesToBegin() {
        var d = detector()
        #expect(d.update(ratio: 0.2, speed: 0) == nil)
        #expect(d.update(ratio: 0.2, speed: 0) == .began)
    }

    @Test func singleLowFrameDoesNotBegin() {
        var d = detector()
        #expect(d.update(ratio: 0.2, speed: 0) == nil)
        #expect(d.update(ratio: 0.8, speed: 0) == nil)
        #expect(d.update(ratio: 0.2, speed: 0) == nil)
    }

    @Test func hysteresisKeepsPinchBetweenThresholds() {
        var d = detector()
        _ = d.update(ratio: 0.2, speed: 0)
        _ = d.update(ratio: 0.2, speed: 0)
        #expect(d.update(ratio: 0.40, speed: 0) == nil)  // above down, below up
        #expect(d.update(ratio: 0.50, speed: 0) == .ended)
    }

    @Test func waitsForPointerToSlowDown() {
        var d = detector()
        #expect(d.update(ratio: 0.2, speed: 1.0) == nil)
        #expect(d.update(ratio: 0.2, speed: 1.0) == nil)
        #expect(d.update(ratio: 0.2, speed: 0.05) == .began)
    }

    @Test func lostHandEndsPinchAndBlocksRetriggerUntilFingersOpen() {
        var d = detector()
        _ = d.update(ratio: 0.2, speed: 0)
        _ = d.update(ratio: 0.2, speed: 0)
        #expect(d.handLost() == .ended)
        // Hand comes back still pinched: must not click again.
        for _ in 0..<5 { #expect(d.update(ratio: 0.2, speed: 0) == nil) }
        // Fingers open, then a fresh pinch works.
        #expect(d.update(ratio: 0.9, speed: 0) == nil)
        _ = d.update(ratio: 0.2, speed: 0)
        #expect(d.update(ratio: 0.2, speed: 0) == .began)
    }

    @Test func handLostWithoutPinchEmitsNothing() {
        var d = detector()
        #expect(d.handLost() == nil)
    }
}

@Suite struct GestureEngineTests {
    @Test func ignoresEverythingWhenNotEngaged() {
        var engine = GestureEngine()
        for i in 0..<10 {
            #expect(engine.process(frame(Double(i) / 30, ratio: 0.1), engaged: false).isEmpty)
        }
        #expect(engine.state == .idle)
    }

    @Test func movesPointerWhenEngaged() {
        var engine = GestureEngine()
        let events = engine.process(frame(0), engaged: true)
        #expect(events == [.pointerMoved(CGPoint(x: 0.5, y: 0.5))])
        #expect(engine.state == .tracking)
    }

    @Test func pinchProducesBeganThenEndedAndFreezesPointer() {
        var engine = GestureEngine()
        var all: [[GestureEvent]] = []
        for i in 0..<5 { all.append(engine.process(frame(Double(i) / 30), engaged: true)) }
        all.append(engine.process(frame(5.0 / 30, ratio: 0.2), engaged: true))
        let began = engine.process(frame(6.0 / 30, ratio: 0.2), engaged: true)
        #expect(began.contains(.pinchBegan(at: CGPoint(x: 0.5, y: 0.5), finger: .index)))
        #expect(!began.contains(where: isPointerMove))  // frozen
        #expect(engine.state == .pinching)

        let ended = engine.process(frame(7.0 / 30, ratio: 0.9), engaged: true)
        #expect(ended.contains(.pinchEnded(finger: .index)))
        #expect(engine.state == .tracking)
    }

    @Test func pinchLatchesPositionBeforeTheFingersMoveIt() {
        var engine = GestureEngine()
        var t = 0.0
        for _ in 0..<10 {
            _ = engine.process(frame(t), engaged: true)
            t += 1.0 / 30
        }
        // Closing the fingers drags the knuckle down a little over the next frames.
        _ = engine.process(frame(t, at: CGPoint(x: 0.5, y: 0.495), ratio: 0.2), engaged: true)
        t += 1.0 / 30
        let events = engine.process(frame(t, at: CGPoint(x: 0.5, y: 0.49), ratio: 0.2), engaged: true)
        guard
            case .pinchBegan(let at, _)? = events.first(where: {
                if case .pinchBegan = $0 { true } else { false }
            })
        else {
            Issue.record("expected pinchBegan")
            return
        }
        #expect(at.y > 0.495)  // not the drifted position
    }

    @Test func disengagingMidPinchReleasesTheButton() {
        var engine = GestureEngine()
        for i in 0..<8 { _ = engine.process(frame(Double(i) / 30, ratio: i < 5 ? 1.0 : 0.2), engaged: true) }
        #expect(engine.state == .pinching)
        #expect(engine.process(frame(9.0 / 30, ratio: 0.2), engaged: false) == [.pinchEnded(finger: .index)])
        #expect(engine.state == .idle)
    }

    @Test func lostHandEmitsEndedThenHandLost() {
        var engine = GestureEngine()
        for i in 0..<8 { _ = engine.process(frame(Double(i) / 30, ratio: i < 5 ? 1.0 : 0.2), engaged: true) }
        #expect(engine.process(noHand(9.0 / 30), engaged: true) == [.pinchEnded(finger: .index), .handLost])
        #expect(engine.state == .idle)
    }

    @Test func lostHandWhileIdleIsSilent() {
        var engine = GestureEngine()
        #expect(engine.process(noHand(0), engaged: true).isEmpty)
    }

    @Test func reacquiredHandStartsFreshWithoutSmoothingFromOldPosition() {
        var engine = GestureEngine()
        _ = engine.process(frame(0, at: CGPoint(x: 0.2, y: 0.2)), engaged: true)
        _ = engine.process(noHand(0.1), engaged: true)
        let events = engine.process(frame(2, at: CGPoint(x: 0.8, y: 0.8)), engaged: true)
        #expect(events == [.pointerMoved(CGPoint(x: 0.8, y: 0.8))])
    }
}

@Suite struct MiddleFingerTests {
    /// Runs frames 0..<n with the given ratios and returns all events.
    private func run(
        _ engine: inout GestureEngine, from start: Int = 0, count: Int, index: Double, middle: Double?
    ) -> [GestureEvent] {
        var all: [GestureEvent] = []
        for i in start..<(start + count) {
            all += engine.process(frame(Double(i) / 30, ratio: index, middle: middle), engaged: true)
        }
        return all
    }

    @Test func middleFingerPinchBeginsAMiddlePinch() {
        var engine = GestureEngine()
        let events = run(&engine, count: 6, index: 0.9, middle: 0.2)
        #expect(began(events) == .middle)
    }

    @Test func indexPinchWithMiddleFingerExtendedStaysAnIndexPinch() {
        var engine = GestureEngine()
        let events = run(&engine, count: 6, index: 0.2, middle: 0.9)
        #expect(began(events) == .index)
    }

    @Test func closerFingerWinsWhenBothAreNearTheThumb() {
        var engine = GestureEngine()
        let events = run(&engine, count: 6, index: 0.25, middle: 0.15)
        #expect(began(events) == .middle)
    }

    @Test func tieGoesToTheIndexFinger() {
        var engine = GestureEngine()
        let events = run(&engine, count: 6, index: 0.2, middle: 0.2)
        #expect(began(events) == .index)
    }

    @Test func heldIndexPinchIgnoresMiddleFingerUntilReleased() {
        var engine = GestureEngine()
        let start = run(&engine, count: 6, index: 0.2, middle: 0.9)
        #expect(began(start) == .index)

        // The middle finger now curls in even closer than the index, while the index pinch is still held.
        let hold = run(&engine, from: 6, count: 6, index: 0.2, middle: 0.1)
        #expect(began(hold) == nil)
        #expect(!hold.contains(.pinchEnded(finger: .index)))
        #expect(engine.state == .pinching)

        let release = run(&engine, from: 12, count: 1, index: 0.9, middle: 0.9)
        #expect(release.contains(.pinchEnded(finger: .index)))
    }

    @Test func middlePinchEndsWithItsOwnFingerEvent() {
        var engine = GestureEngine()
        _ = run(&engine, count: 6, index: 0.9, middle: 0.2)
        let release = run(&engine, from: 6, count: 1, index: 0.9, middle: 0.9)
        #expect(release.contains(.pinchEnded(finger: .middle)))
    }

    @Test func lostHandReleasesAMiddlePinch() {
        var engine = GestureEngine()
        _ = run(&engine, count: 6, index: 0.9, middle: 0.2)
        #expect(engine.process(noHand(7.0 / 30), engaged: true) == [.pinchEnded(finger: .middle), .handLost])
    }

    @Test func handWithoutMiddleTipStillSupportsIndexPinch() {
        var engine = GestureEngine()
        let events = run(&engine, count: 6, index: 0.2, middle: nil)
        #expect(began(events) == .index)
    }
}

@Suite struct ActionMapperTests {
    @Test func defaultsPinchToLeftButton() {
        #expect(ActionMapper().action(for: "pinch") == .leftButton)
    }

    @Test func defaultsMiddlePinchToRightButton() {
        #expect(ActionMapper().action(for: PinchFinger.middle.gestureName) == .rightButton)
    }

    @Test func unmappedGestureDoesNothing() {
        #expect(ActionMapper().action(for: "wave") == GestureAction.none)
    }

    @Test func userCanRemap() {
        var mapper = ActionMapper()
        mapper.mapping["pinch"] = .rightButton
        #expect(mapper.action(for: "pinch") == .rightButton)
    }
}
