import Foundation

struct TelemetryPayload: Codable {
    let timestamp: String
    let sensors: SensorReadings
}

struct SensorReadings: Codable {
    var location: LocationData?
    var velocity: VelocityData?
    var steps: StepsData?
    var motion: MotionData?
    var bluetooth: BluetoothData?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let location  { try container.encode(location, forKey: .location) }
        if let velocity  { try container.encode(velocity, forKey: .velocity) }
        if let steps     { try container.encode(steps, forKey: .steps) }
        if let motion    { try container.encode(motion, forKey: .motion) }
        if let bluetooth { try container.encode(bluetooth, forKey: .bluetooth) }
    }
}

struct LocationData: Codable {
    let lat: Double
    let lon: Double
    let altitude: Double
    let accuracy: Double
}

struct VelocityData: Codable {
    let speed: Double
    let course: Double
}

struct StepsData: Codable {
    let count: Int
    let distance: Double
    let floorsUp: Int
    let floorsDown: Int

    enum CodingKeys: String, CodingKey {
        case count, distance
        case floorsUp = "floors_up"
        case floorsDown = "floors_down"
    }
}

struct MotionData: Codable {
    let state: String
    let confidence: String
}

struct BluetoothData: Codable {
    let devices: [BluetoothDeviceData]
}

struct BluetoothDeviceData: Codable {
    let name: String
    let rssi: Int
    let uuid: String
}
