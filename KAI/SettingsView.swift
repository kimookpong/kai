import KAICore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            PermissionsSettings().tabItem { Label("Permissions", systemImage: "lock.shield") }
            PrivacySettings().tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 520, height: 420)
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: state.setLaunchAtLogin))
        }
        .formStyle(.grouped)
    }
}

private struct PrivacySettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Toggle("Allow cloud AI", isOn: Binding(
                get: { state.config.privacy.allowCloudAI },
                set: { v in state.update { $0.privacy.allowCloudAI = v } }
            ))
            Text("Off by default. When off, nothing leaves this Mac. Camera frames are never saved or uploaded.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
