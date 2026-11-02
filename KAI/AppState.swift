import AppKit
import Carbon.HIToolbox
import KAICore
import KAIGesture
import KAITracking
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppState {
    private(set) var permissions: [Permission: PermissionStatus] = [:]
    private(set) var config: KAIConfig
    private(set) var isEngaged = false
    /// Why engagement failed, shown in the menu. Cleared on the next attempt.
    private(set) var engagementError: String?
    @ObservationIgnored private var session: GestureSession?
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    let events = EventBus()
    private let checker: PermissionChecking = SystemPermissionChecker()
    private let store = ConfigStore.standard()
    private let log = KAILog.logger(.app)
    @ObservationIgnored private var activationObserver: NSObjectProtocol?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?
    @ObservationIgnored private let hotkey = HotkeyManager()
    private(set) var hotkeyRegistered = false

    init() {
        do {
            config = try store.load()
        } catch {
            log.error("Config load failed, using defaults: \(error.localizedDescription, privacy: .public)")
            config = KAIConfig()
        }
        refreshPermissions()
        // Control + Option + K toggles engagement.
        hotkeyRegistered = hotkey.register(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey)) {
            [weak self] in
            self?.toggleEngaged()
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setEngaged(false) }
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
    }

    func toggleEngaged() { setEngaged(!isEngaged) }

    /// Engaging starts the camera and takes control of the pointer; disengaging stops the camera.
    func setEngaged(_ on: Bool) {
        engagementError = nil
        guard on != isEngaged else { return }
        if on {
            refreshPermissions()
            let ax = permissions[.accessibility]?.rawValue ?? "?"
            let cam = permissions[.camera]?.rawValue ?? "?"
            log.info("Engage requested: accessibility=\(ax, privacy: .public) camera=\(cam, privacy: .public)")
            guard permissions[.accessibility] == .granted else {
                fail("Accessibility permission is needed to control the pointer.")
                PermissionRequester.request(.accessibility) { [weak self] in self?.refreshPermissions() }
                return
            }
            switch permissions[.camera] {
            case .granted:
                break
            case .notDetermined:
                PermissionRequester.request(.camera) { [weak self] in
                    guard let self else { return }
                    refreshPermissions()
                    if permissions[.camera] == .granted {
                        setEngaged(true)
                    } else {
                        fail("Camera access was not granted.")
                    }
                }
                return
            default:
                fail("Camera permission is needed to track your hand.")
                PermissionRequester.openSettings(.camera)
                return
            }
            let newSession = GestureSession(config: gestureConfig())
            do { try newSession.start() } catch {
                log.error("Could not start gesture session: \(error.localizedDescription, privacy: .public)")
                fail("Could not start the camera.")
                return
            }
            session = newSession
        } else {
            session?.stop()
            session = nil
        }
        isEngaged = on
        log.info("Engaged: \(on, privacy: .public)")
        let events = events
        Task { await events.publish(.engagementChanged(isEngaged: on)) }
    }

    /// Reports why engaging failed: logged, shown in the menu, flagged by the menu bar icon, and audible.
    private func fail(_ message: String) {
        log.error("Engage failed: \(message, privacy: .public)")
        engagementError = message
        NSSound.beep()
    }

    private func gestureConfig() -> GestureConfig {
        var g = GestureConfig()
        let c = config.gesture
        g.anchor = AnchorKind(rawValue: c.anchor) ?? .mcp
        g.filterMinCutoff = c.filterMinCutoff
        g.filterBeta = c.filterBeta
        g.pinchDown = c.pinchDown
        g.pinchUp = c.pinchUp
        g.freezeSeconds = c.freezeMs / 1000
        return g
    }

    func refreshPermissions() {
        for p in Permission.allCases {
            let new = checker.status(for: p)
            if permissions[p] != new {
                permissions[p] = new
                let events = events
                Task { await events.publish(.permissionChanged(p, new)) }
            }
        }
    }

    func update(_ change: (inout KAIConfig) -> Void) {
        var c = config
        change(&c)
        config = c
        do { try store.save(c) } catch {
            log.error("Config save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("Launch at login failed: \(error.localizedDescription, privacy: .public)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var menuBarSymbol: String {
        if engagementError != nil { return "exclamationmark.triangle" }
        return isEngaged ? "hand.point.up.left.fill" : "hand.point.up.left"
    }

    /// Number of permissions the core features need that are not yet granted.
    var missingRequiredPermissions: Int {
        [Permission.accessibility, .camera].filter { permissions[$0] != .granted }.count
    }
}
