import Foundation

@Observable
final class DashboardViewModel {
    let telemetryService: TelemetryService

    init(telemetryService: TelemetryService) {
        self.telemetryService = telemetryService
    }

    // MARK: - Formatted properties

    var locationText: String? {
        guard let loc = telemetryService.locationService.currentLocation else { return nil }
        let lat = String(format: "%.6f", loc.lat)
        let lon = String(format: "%.6f", loc.lon)
        let alt = String(format: "%.1f m", loc.altitude)
        let acc = String(format: "%.1f m", loc.accuracy)
        return "\(lat), \(lon)\nAlt: \(alt)  Acc: \(acc)"
    }

    var velocityText: String? {
        guard let vel = telemetryService.locationService.currentVelocity else { return nil }
        let mph = vel.speed * 2.23694
        let speed = String(format: "%.1f mph", mph)
        let course = String(format: "%.0f\u{00B0}", vel.course)
        return "\(speed)  Heading: \(course)"
    }

    var stepsText: String? {
        guard let steps = telemetryService.motionService.currentSteps else { return nil }
        let count = NumberFormatter.localizedString(from: NSNumber(value: steps.count), number: .decimal)
        let dist = String(format: "%.0f m", steps.distance)
        var text = "\(count) steps  \(dist)"
        if steps.floorsUp > 0 || steps.floorsDown > 0 {
            text += "\nFloors: \(steps.floorsUp) up, \(steps.floorsDown) down"
        }
        return text
    }

    var motionText: String? {
        guard let motion = telemetryService.motionService.currentMotion else { return nil }
        return "\(motion.state.capitalized) (\(motion.confidence) confidence)"
    }

    var bluetoothText: String? {
        guard let bt = telemetryService.bluetoothService.currentBluetooth else { return nil }
        if bt.devices.isEmpty { return "No devices nearby" }
        return bt.devices.prefix(5).map { device in
            "\(device.name)  \(device.rssi) dBm"
        }.joined(separator: "\n")
    }

    var lastTransmissionText: String {
        guard let date = telemetryService.lastTransmissionDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var statusColor: String {
        if telemetryService.lastError != nil { return "red" }
        if telemetryService.isRunning { return "green" }
        return "gray"
    }
}
