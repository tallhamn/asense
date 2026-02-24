import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Collection toggle
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.isRunning },
                        set: { _ in viewModel.toggleRunning() }
                    )) {
                        Label("Collecting", systemImage: viewModel.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    }
                    .tint(.green)
                }

                // MARK: - Sensors
                Section("Sensors") {
                    ForEach(SensorType.allCases) { sensor in
                        SensorToggleRow(
                            sensorType: sensor,
                            isEnabled: Binding(
                                get: { viewModel.isSensorEnabled(sensor) },
                                set: { viewModel.toggleSensor(sensor, enabled: $0) }
                            )
                        )
                    }
                }

                // MARK: - Transmission
                Section {
                    FrequencySliderView(
                        interval: Binding(
                            get: { viewModel.transmissionInterval },
                            set: { viewModel.transmissionInterval = $0 }
                        )
                    )
                }

                // MARK: - Encryption Key
                Section {
                    KeyExportView(base64Key: viewModel.aesKeyBase64)
                }

                // MARK: - API Token
                Section("Server") {
                    SecureField("API Token", text: Binding(
                        get: { viewModel.apiToken },
                        set: { viewModel.apiToken = $0 }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                // MARK: - Device
                Section("Device") {
                    LabeledContent("Device ID") {
                        Text(viewModel.deviceUUID)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    LabeledContent("Buffered") {
                        Text("\(viewModel.telemetryService.bufferedCount) blobs")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
