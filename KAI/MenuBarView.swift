import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Button(state.isEngaged ? "● Active — click to pause" : "○ Idle — click to start") { state.toggleEngaged() }
        if state.hotkeyRegistered {
            Text("Shortcut: ⌃⌥K").font(.caption)
        } else {
            Text("Shortcut ⌃⌥K is taken by another app").font(.caption)
        }

        if state.missingRequiredPermissions > 0 {
            Text("\(state.missingRequiredPermissions) permission(s) needed")
        }

        Divider()

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })

        Divider()

        Button("Quit KAI") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
