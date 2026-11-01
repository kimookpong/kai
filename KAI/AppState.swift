import AppKit
import KAICore
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppState {
    private(set) var permissions: [Permission: PermissionStatus] = [:]
    private(set) var config: KAIConfig
    var isEngaged = false
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    let events = EventBus()
    private let checker: PermissionChecking = SystemPermissionChecker()
    private let store = ConfigStore.standard()
    private let log = KAILog.logger(.app)
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    init() {
        do {
            config = try store.load()
        } catch {
            log.error("Config load failed, using defaults: \(error.localizedDescription, privacy: .public)")
            config = KAIConfig()
        }
        refreshPermissions()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
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

    /// Number of permissions the core features need that are not yet granted.
    var missingRequiredPermissions: Int {
        [Permission.accessibility, .camera].filter { permissions[$0] != .granted }.count
    }
}
