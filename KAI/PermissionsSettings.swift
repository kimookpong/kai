import AVFoundation
import AppKit
import KAICore
import SwiftUI

struct PermissionsSettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            ForEach(Permission.allCases, id: \.self) { p in
                PermissionRow(permission: p, status: state.permissions[p] ?? .unknown)
            }
        }
        .formStyle(.grouped)
        .onAppear { state.refreshPermissions() }
    }
}

private struct PermissionRow: View {
    @Environment(AppState.self) private var state
    let permission: Permission
    let status: PermissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(permission.title).font(.headline)
                Spacer()
                Label(status.label, systemImage: status.symbol)
                    .foregroundStyle(status.color)
                    .font(.callout)
            }
            Text(permission.rationale).font(.callout).foregroundStyle(.secondary)
            if status != .granted {
                HStack {
                    if status == .notDetermined || permission == .accessibility {
                        Button("Allow") { PermissionRequester.request(permission) { state.refreshPermissions() } }
                    }
                    Button("Open System Settings") { PermissionRequester.openSettings(permission) }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Triggers the system prompt or jumps to the right System Settings pane.
@MainActor
enum PermissionRequester {
    static func request(_ p: Permission, completion: @escaping @MainActor () -> Void) {
        switch p {
        case .accessibility:
            let key = "AXTrustedCheckOptionPrompt" as CFString
            AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
            completion()
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { _ in Task { @MainActor in completion() } }
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { _ in Task { @MainActor in completion() } }
        case .screenRecording:
            CGRequestScreenCaptureAccess()
            completion()
        case .automation:
            openSettings(p)
        }
    }

    static func openSettings(_ p: Permission) {
        let anchor: String =
            switch p {
            case .accessibility: "Privacy_Accessibility"
            case .camera: "Privacy_Camera"
            case .microphone: "Privacy_Microphone"
            case .screenRecording: "Privacy_ScreenCapture"
            case .automation: "Privacy_Automation"
            }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension Permission {
    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .screenRecording: "Screen Recording"
        case .automation: "Automation"
        }
    }
}

extension PermissionStatus {
    var label: String {
        switch self {
        case .granted: "Granted"
        case .denied: "Not granted"
        case .notDetermined: "Not asked yet"
        case .unknown: "Unknown"
        }
    }
    var symbol: String {
        switch self {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined, .unknown: "questionmark.circle"
        }
    }
    var color: Color {
        switch self {
        case .granted: .green
        case .denied: .red
        case .notDetermined, .unknown: .secondary
        }
    }
}
