import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Text(state.isEngaged ? "● Active" : "○ Idle")

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
