import ApplicationServices
import AVFoundation
import CoreGraphics

public enum Permission: String, Sendable, CaseIterable, Codable {
    case accessibility, camera, microphone, screenRecording, automation

    /// Why KAI needs it, shown during onboarding. Keep honest and specific.
    public var rationale: String {
        switch self {
        case .accessibility: "Move the cursor, click and type on your behalf, and read what is under the pointer."
        case .camera: "Track your hand so you can control the Mac by gesture. Frames are processed on this Mac and never saved."
        case .microphone: "Listen for voice commands while you hold the talk key."
        case .screenRecording: "Look at the part of the screen you point at so KAI can understand it. Only used when you ask."
        case .automation: "Control other apps such as Finder and Music through AppleScript."
        }
    }
}

public enum PermissionStatus: String, Sendable, Codable {
    case granted, denied, notDetermined
    /// macOS offers no reliable way to query this without triggering a prompt.
    case unknown
}

public protocol PermissionChecking: Sendable {
    func status(for permission: Permission) -> PermissionStatus
}

public struct SystemPermissionChecker: PermissionChecking {
    public init() {}

    public func status(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .denied
        case .camera:
            return Self.map(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            return Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .denied
        case .automation:
            return .unknown
        }
    }

    private static func map(_ s: AVAuthorizationStatus) -> PermissionStatus {
        switch s {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}
