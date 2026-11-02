@preconcurrency import AVFoundation
import Vision

/// Camera capture plus Apple Vision hand pose. Frames are delivered on a private queue, never the main thread.
///
/// Joints below their confidence threshold are left out, so `HandLandmarks.anchor` / `pinchRatio` return nil and
/// the gesture engine treats the frame as "no hand". Thumb and index tips use a lower threshold because they
/// overlap while pinching, which lowers Vision's confidence; the Phase 0 click test showed that dropping those
/// frames released and re-fired the click.
public final class AppleVisionTracker: NSObject, HandTrackingProvider, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    /// Set before `start()`. Called on the camera queue.
    public var onFrame: (@Sendable (HandFrame) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "ai.kai.camera", qos: .userInteractive)
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()
    private let jointConfidence: Float
    private let tipConfidence: Float
    private var isConfigured = false
    private var device: AVCaptureDevice?

    public enum TrackerError: Error, Equatable {
        case noCamera, cannotAddInput, cannotAddOutput
    }

    public init(jointConfidence: Float = 0.3, tipConfidence: Float = 0.1) {
        self.jointConfidence = jointConfidence
        self.tipConfidence = tipConfidence
    }

    public func start() throws {
        if !isConfigured { try configure() }
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    public func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Low power drops the camera towards 5 fps; turning it off restores the device default.
    /// AVFoundation raises an Objective-C exception (which Swift cannot catch) for a frame duration the active
    /// format does not support, so the target rate is clamped to the supported ranges first.
    public func setLowPower(_ on: Bool) {
        queue.async { [weak self] in
            guard let device = self?.device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            guard on else {
                device.activeVideoMinFrameDuration = .invalid
                return
            }
            let ranges = device.activeFormat.videoSupportedFrameRateRanges
            guard let lowest = ranges.map(\.minFrameRate).min(), let highest = ranges.map(\.maxFrameRate).max(),
                let rate = Self.lowPowerRate(lowest: lowest, highest: highest)
            else { return }
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: rate)
        }
    }

    /// The whole-number rate closest to `target` that the format supports, or nil if none does.
    /// The MacBook Pro camera supports only 15 to 30 fps at 640x480, so low power there means 15 fps.
    public static func lowPowerRate(lowest: Double, highest: Double, target: Double = 5) -> Int32? {
        let floor = lowest.rounded(.up), ceiling = highest.rounded(.down)
        guard floor <= ceiling else { return nil }
        let rate = Int32(min(max(target, floor), ceiling))
        return rate > 0 ? rate : nil
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(for: .video) else { throw TrackerError.noCamera }
        self.device = device
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .vga640x480
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw TrackerError.cannotAddInput }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw TrackerError.cannotAddOutput }
        session.addOutput(output)
        isConfigured = true
    }

    public func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up, options: [:])
        try? handler.perform([request])
        let hand = request.results?.first.map(landmarks(from:))
        onFrame?(HandFrame(timestamp: timestamp, hand: hand))
    }

    private static let joints: [(Joint, VNHumanHandPoseObservation.JointName, isTip: Bool)] = [
        (.wrist, .wrist, false), (.thumbTip, .thumbTip, true), (.indexTip, .indexTip, true),
        (.indexMCP, .indexMCP, false), (.middleMCP, .middleMCP, false), (.middleTip, .middleTip, true),
        (.ringMCP, .ringMCP, false), (.littleMCP, .littleMCP, false),
    ]

    private func landmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks {
        var result: [Joint: Landmark] = [:]
        for (joint, name, isTip) in Self.joints {
            guard let p = try? observation.recognizedPoint(name),
                p.confidence >= (isTip ? tipConfidence : jointConfidence)
            else { continue }
            // Mirror x so that moving the hand right increases x, like looking in a mirror.
            result[joint] = Landmark(x: 1 - p.location.x, y: p.location.y, confidence: p.confidence)
        }
        return HandLandmarks(joints: result)
    }
}
