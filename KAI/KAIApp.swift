import SwiftUI

@main
struct KAIApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra("KAI", systemImage: state.isEngaged ? "hand.point.up.left.fill" : "hand.point.up.left") {
            MenuBarView().environment(state)
        }
        Settings {
            SettingsView().environment(state)
        }
    }
}
