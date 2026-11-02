import CoreGraphics
import Testing

@testable import KAITracking

private func hand(thumb: (Double, Double), index: (Double, Double)) -> HandLandmarks {
    HandLandmarks(joints: [
        .wrist: Landmark(x: 0.5, y: 0.2),
        .middleMCP: Landmark(x: 0.5, y: 0.4),  // hand size 0.2
        .thumbTip: Landmark(x: thumb.0, y: thumb.1),
        .indexTip: Landmark(x: index.0, y: index.1),
        .indexMCP: Landmark(x: 0.45, y: 0.4),
        .ringMCP: Landmark(x: 0.55, y: 0.4),
        .littleMCP: Landmark(x: 0.6, y: 0.38),
    ])
}

@Suite struct HandLandmarksTests {
    @Test func middlePinchRatioMeasuresThumbToMiddleTip() throws {
        var h = hand(thumb: (0.5, 0.5), index: (0.9, 0.5))
        h.joints[.middleTip] = Landmark(x: 0.54, y: 0.5)  // 0.04 apart, hand size 0.2
        let ratio = try #require(h.middlePinchRatio)
        #expect(abs(ratio - 0.2) < 1e-9)
    }

    @Test func middlePinchRatioIsNilWithoutMiddleTip() {
        #expect(hand(thumb: (0.5, 0.5), index: (0.56, 0.5)).middlePinchRatio == nil)
    }

    @Test func pinchRatioIsRelativeToHandSize() throws {
        let h = hand(thumb: (0.5, 0.5), index: (0.56, 0.5))  // 0.06 apart, hand size 0.2
        #expect(abs(try #require(h.pinchRatio) - 0.3) < 1e-9)
    }

    @Test func pinchRatioIgnoresDistanceFromCamera() throws {
        let near = hand(thumb: (0.5, 0.5), index: (0.56, 0.5))
        // Same pose seen from twice as far: every distance halves.
        let far = HandLandmarks(joints: [
            .wrist: Landmark(x: 0.5, y: 0.2), .middleMCP: Landmark(x: 0.5, y: 0.3),
            .thumbTip: Landmark(x: 0.5, y: 0.35), .indexTip: Landmark(x: 0.53, y: 0.35),
        ])
        let nearRatio = try #require(near.pinchRatio)
        let farRatio = try #require(far.pinchRatio)
        #expect(abs(nearRatio - farRatio) < 1e-9)
    }

    @Test func pinchRatioIsNilWithMissingJointOrTinyHand() {
        #expect(HandLandmarks(joints: [:]).pinchRatio == nil)
        let tiny = HandLandmarks(joints: [
            .wrist: Landmark(x: 0.5, y: 0.5), .middleMCP: Landmark(x: 0.5, y: 0.505),
            .thumbTip: Landmark(x: 0.5, y: 0.5), .indexTip: Landmark(x: 0.5, y: 0.5),
        ])
        #expect(tiny.pinchRatio == nil)
    }

    @Test func anchorsPickTheRightLandmark() throws {
        let h = hand(thumb: (0.5, 0.5), index: (0.56, 0.5))
        #expect(h.anchor(.tip) == CGPoint(x: 0.56, y: 0.5))
        #expect(h.anchor(.mcp) == CGPoint(x: 0.45, y: 0.4))
        let palm = try #require(h.anchor(.palm))
        #expect(abs(palm.x - 0.52) < 1e-9)
        #expect(abs(palm.y - 0.356) < 1e-9)
    }

    @Test func palmAnchorNeedsAllFiveJoints() {
        var h = hand(thumb: (0.5, 0.5), index: (0.56, 0.5))
        h.joints[.ringMCP] = nil
        #expect(h.anchor(.palm) == nil)
    }
}

@Suite struct LowPowerRateTests {
    @Test func usesTheTargetWhenTheCameraSupportsIt() {
        #expect(AppleVisionTracker.lowPowerRate(lowest: 1, highest: 30) == 5)
    }

    @Test func clampsUpToTheCameraMinimum() {
        #expect(AppleVisionTracker.lowPowerRate(lowest: 15, highest: 30) == 15)
    }

    @Test func roundsFractionalMinimumUp() {
        #expect(AppleVisionTracker.lowPowerRate(lowest: 7.5, highest: 30) == 8)
    }

    @Test func returnsNilWhenNoWholeRateFits() {
        #expect(AppleVisionTracker.lowPowerRate(lowest: 10.2, highest: 10.8) == nil)
    }
}
