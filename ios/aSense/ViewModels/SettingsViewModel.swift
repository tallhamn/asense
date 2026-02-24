import Foundation
import SwiftUI

@Observable
final class SettingsViewModel {
    let telemetryService: TelemetryService

    var aesKeyBase64: String {
        KeychainService.shared.aesKeyBase64 ?? "Key unavailable"
    }

    var deviceUUID: String {
        KeychainService.shared.deviceUUID ?? "UUID unavailable"
    }

    var apiToken: String {
        get { KeychainService.shared.apiToken ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            KeychainService.shared.apiToken = trimmed.isEmpty ? nil : trimmed
        }
    }

    var transmissionInterval: TimeInterval {
        get { telemetryService.transmissionInterval }
        set { telemetryService.transmissionInterval = newValue }
    }

    var isRunning: Bool {
        get { telemetryService.isRunning }
    }

    init(telemetryService: TelemetryService) {
        self.telemetryService = telemetryService
    }

    func isSensorEnabled(_ type: SensorType) -> Bool {
        telemetryService.isSensorEnabled(type)
    }

    func toggleSensor(_ type: SensorType, enabled: Bool) {
        telemetryService.toggleSensor(type, enabled: enabled)
    }

    func toggleRunning() {
        if telemetryService.isRunning {
            telemetryService.stop()
        } else {
            telemetryService.start()
        }
    }
}
