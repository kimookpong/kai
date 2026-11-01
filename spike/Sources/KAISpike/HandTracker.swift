import AVFoundation
import Vision

struct HandSample {
    /// Normalized, mirrored so moving the hand right moves x up. Origin bottom-left (Vision convention).
    var anchor: CGPoint
    var pinchRatio: Double
    var confidence: Float
    /// Host-clock time the frame was captured, seconds.
    var captureTime: Double
}

/// Camera capture + Apple Vision hand pose. Runs entirely off the main thread.
final class HandTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "kai.spike.camera", qos: .userInteractive)
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()
    private let anchor: Anchor

    /// Called on the camera queue. nil sample means no hand in frame.
    var onSample: ((HandSample?, _ visionSeconds: Double) -> Void)?

    init(anchor: Anchor) { self.anchor = anchor }

    func start() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw NSError(domain: "KAISpike", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera found"])
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "KAISpike", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            throw NSError(domain: "KAISpike", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera output"])
        }
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
        print("camera: \(device.localizedName)")
    }

    func stop() { session.stopRunning() }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let captureTime = CMTimeGetSeconds(pts)

        let t0 = CFAbsoluteTimeGetCurrent()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up, options: [:])
        try? handler.perform([request])
        let visionSeconds = CFAbsoluteTimeGetCurrent() - t0

        guard let obs = request.results?.first, let sample = makeSample(obs, captureTime: captureTime) else {
            onSample?(nil, visionSeconds)
            return
        }
        onSample?(sample, visionSeconds)
    }

    private func makeSample(_ obs: VNHumanHandPoseObservation, captureTime: Double) -> HandSample? {
        func pt(_ j: VNHumanHandPoseObservation.JointName, min: Float = 0.3) -> (CGPoint, Float)? {
            guard let p = try? obs.recognizedPoint(j), p.confidence >= min else { return nil }
            return (p.location, p.confidence)
        }
        guard let (wrist, _) = pt(.wrist), let (middleMCP, _) = pt(.middleMCP),
              let (thumbTip, _) = pt(.thumbTip), let (indexTip, conf) = pt(.indexTip) else { return nil }

        let raw: CGPoint
        switch anchor {
        case .tip:
            raw = indexTip
        case .mcp:
            guard let (p, _) = pt(.indexMCP) else { return nil }
            raw = p
        case .palm:
            let joints: [VNHumanHandPoseObservation.JointName] = [.wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP]
            let pts = joints.compactMap { pt($0)?.0 }
            guard pts.count == joints.count else { return nil }
            raw = CGPoint(x: pts.map(\.x).reduce(0, +) / Double(pts.count),
                          y: pts.map(\.y).reduce(0, +) / Double(pts.count))
        }
        let handSize = hypot(wrist.x - middleMCP.x, wrist.y - middleMCP.y)
        guard handSize > 0.01 else { return nil }
        let pinch = hypot(thumbTip.x - indexTip.x, thumbTip.y - indexTip.y) / handSize
        return HandSample(anchor: CGPoint(x: 1 - raw.x, y: raw.y),
                          pinchRatio: pinch, confidence: conf, captureTime: captureTime)
    }
}
