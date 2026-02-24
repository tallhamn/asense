import Foundation
import CoreBluetooth

@Observable
final class BluetoothService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var currentBluetooth: BluetoothData? {
        let list = Array(devices.values)
            .sorted { $0.rssi > $1.rssi }
            .map { BluetoothDeviceData(name: $0.name, rssi: $0.rssi, uuid: $0.uuid) }
        return list.isEmpty ? nil : BluetoothData(devices: list)
    }

    private var centralManager: CBCentralManager!
    private var devices: [String: DiscoveredDevice] = [:]
    private var active = false
    private var cleanupTask: Task<Void, Never>?

    private struct DiscoveredDevice {
        let name: String
        let rssi: Int
        let uuid: String
        let lastSeen: Date
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
    }

    func start() {
        guard !active else { return }
        active = true
        if centralManager.state == .poweredOn {
            beginScanning()
        }
    }

    func stop() {
        guard active else { return }
        active = false
        centralManager.stopScan()
        cleanupTask?.cancel()
        cleanupTask = nil
        devices.removeAll()
    }

    private func beginScanning() {
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        startCleanup()
    }

    private func startCleanup() {
        cleanupTask?.cancel()
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await MainActor.run {
                    self?.removeStaleDevices()
                }
            }
        }
    }

    private func removeStaleDevices() {
        let cutoff = Date().addingTimeInterval(-30)
        devices = devices.filter { $0.value.lastSeen > cutoff }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn, active {
            beginScanning()
        } else {
            central.stopScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let uuid = peripheral.identifier.uuidString
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown"

        devices[uuid] = DiscoveredDevice(
            name: name,
            rssi: RSSI.intValue,
            uuid: uuid,
            lastSeen: Date()
        )
    }
}
