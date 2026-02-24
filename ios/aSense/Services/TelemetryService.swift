import Foundation
import SwiftUI

@Observable
final class TelemetryService {
    // MARK: - Sensor services
    let locationService = LocationService()
    let motionService = MotionService()
    let bluetoothService = BluetoothService()

    // MARK: - Configuration (persisted)
    var enabledSensors: Set<SensorType> {
        didSet { saveEnabledSensors() }
    }
    var transmissionInterval: TimeInterval {
        didSet { UserDefaults.standard.set(transmissionInterval, forKey: "transmissionInterval") }
    }

    // MARK: - State
    var isRunning = false
    var lastTransmissionDate: Date?
    var lastError: String?
    var bufferedCount: Int { BufferService.shared.count }

    private var transmitTask: Task<Void, Never>?
    private let endpoint = URL(string: "https://sense.momstudios.com/api/telemetry")!

    init() {
        // Load persisted settings
        if let raw = UserDefaults.standard.array(forKey: "enabledSensors") as? [String] {
            enabledSensors = Set(raw.compactMap { SensorType(rawValue: $0) })
        } else {
            enabledSensors = []
        }
        let interval = UserDefaults.standard.double(forKey: "transmissionInterval")
        transmissionInterval = interval > 0 ? interval : 60
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startSensors()
        transmitTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.collectAndTransmit()
                guard let interval = self?.transmissionInterval else { break }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        isRunning = false
        transmitTask?.cancel()
        transmitTask = nil
        stopSensors()
    }

    // MARK: - Sensor management

    func isSensorEnabled(_ type: SensorType) -> Bool {
        enabledSensors.contains(type)
    }

    func toggleSensor(_ type: SensorType, enabled: Bool) {
        if enabled {
            enabledSensors.insert(type)
        } else {
            enabledSensors.remove(type)
        }
        if isRunning {
            updateSensorStates()
        }
    }

    private func startSensors() {
        updateSensorStates()
    }

    private func stopSensors() {
        locationService.stop()
        motionService.stop()
        bluetoothService.stop()
    }

    private func updateSensorStates() {
        let needsLocation = enabledSensors.contains(.location) || enabledSensors.contains(.velocity)
        if needsLocation { locationService.start() } else { locationService.stop() }

        let needsMotion = enabledSensors.contains(.steps) || enabledSensors.contains(.motion)
        if needsMotion { motionService.start() } else { motionService.stop() }

        if enabledSensors.contains(.bluetooth) { bluetoothService.start() } else { bluetoothService.stop() }
    }

    // MARK: - Collection & Transmission

    func collectAndTransmit() async {
        guard !enabledSensors.isEmpty else { return }

        let readings = buildReadings()
        let payload = TelemetryPayload(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            sensors: readings
        )

        guard let jsonData = try? JSONEncoder().encode(payload),
              let key = KeychainService.shared.aesKeyData,
              let encrypted = try? EncryptionService.encrypt(data: jsonData, using: key),
              let deviceID = KeychainService.shared.deviceUUID
        else {
            lastError = "Encryption failed"
            return
        }

        // Try to send
        let success = await send(encrypted: encrypted, deviceID: deviceID)

        if success {
            lastTransmissionDate = Date()
            lastError = nil
            // Flush buffered blobs
            await flushBuffer(deviceID: deviceID)
        } else {
            BufferService.shared.save(encrypted)
        }
    }

    private func buildReadings() -> SensorReadings {
        var readings = SensorReadings()

        if enabledSensors.contains(.location) {
            readings.location = locationService.currentLocation
        }
        if enabledSensors.contains(.velocity) {
            readings.velocity = locationService.currentVelocity
        }
        if enabledSensors.contains(.steps) {
            readings.steps = motionService.currentSteps
        }
        if enabledSensors.contains(.motion) {
            readings.motion = motionService.currentMotion
        }
        if enabledSensors.contains(.bluetooth) {
            readings.bluetooth = bluetoothService.currentBluetooth
        }

        return readings
    }

    private func send(encrypted: Data, deviceID: String) async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        if let token = KeychainService.shared.apiToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encrypted

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 201
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func flushBuffer(deviceID: String) async {
        let buffered = BufferService.shared.loadAll()
        for item in buffered {
            let success = await send(encrypted: item.data, deviceID: deviceID)
            if success {
                BufferService.shared.remove(at: item.url)
            } else {
                break // stop flushing on first failure
            }
        }
    }

    // MARK: - Persistence helpers

    private func saveEnabledSensors() {
        let raw = enabledSensors.map(\.rawValue)
        UserDefaults.standard.set(raw, forKey: "enabledSensors")
    }
}
