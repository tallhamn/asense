import SwiftUI

struct ContentView: View {
    let telemetryService: TelemetryService

    var body: some View {
        TabView {
            DashboardView(
                viewModel: DashboardViewModel(telemetryService: telemetryService)
            )
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }

            SettingsView(
                viewModel: SettingsViewModel(telemetryService: telemetryService)
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
