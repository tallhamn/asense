import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status bar
                    statusBar

                    // Sensor cards
                    if viewModel.telemetryService.enabledSensors.isEmpty {
                        ContentUnavailableView(
                            "No Sensors Enabled",
                            systemImage: "sensor",
                            description: Text("Enable sensors in Settings to see live data.")
                        )
                        .padding(.top, 40)
                    } else {
                        sensorCards
                    }
                }
                .padding()
            }
            .navigationTitle("aSense")
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(statusIndicatorColor)
                .frame(width: 10, height: 10)

            Text(viewModel.telemetryService.isRunning ? "Collecting" : "Stopped")
                .font(.subheadline.weight(.medium))

            Spacer()

            Label(viewModel.lastTransmissionText, systemImage: "arrow.up.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.telemetryService.bufferedCount > 0 {
                Label("\(viewModel.telemetryService.bufferedCount)", systemImage: "tray.full")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusIndicatorColor: Color {
        switch viewModel.statusColor {
        case "green": .green
        case "red":   .red
        default:      .gray
        }
    }

    // MARK: - Sensor Cards

    private var sensorCards: some View {
        VStack(spacing: 12) {
            if viewModel.telemetryService.isSensorEnabled(.location) {
                sensorCard(
                    type: .location,
                    value: viewModel.locationText
                )
            }
            if viewModel.telemetryService.isSensorEnabled(.velocity) {
                sensorCard(
                    type: .velocity,
                    value: viewModel.velocityText
                )
            }
            if viewModel.telemetryService.isSensorEnabled(.steps) {
                sensorCard(
                    type: .steps,
                    value: viewModel.stepsText
                )
            }
            if viewModel.telemetryService.isSensorEnabled(.motion) {
                sensorCard(
                    type: .motion,
                    value: viewModel.motionText
                )
            }
            if viewModel.telemetryService.isSensorEnabled(.bluetooth) {
                sensorCard(
                    type: .bluetooth,
                    value: viewModel.bluetoothText
                )
            }

            if let error = viewModel.telemetryService.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func sensorCard(type: SensorType, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(type.displayName, systemImage: type.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let value {
                Text(value)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
