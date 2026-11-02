import SwiftUI

@main
struct KAIApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra("KAI", systemImage: state.menuBarSymbol) {
            MenuBarView().environment(state)
        }
        Settings {
            SettingsView().environment(state)
        }
    }
}
