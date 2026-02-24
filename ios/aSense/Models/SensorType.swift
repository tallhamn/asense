import Foundation

enum SensorType: String, CaseIterable, Identifiable {
    case location
    case velocity
    case steps
    case motion
    case bluetooth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .location:  "Location"
        case .velocity:  "Velocity"
        case .steps:     "Steps"
        case .motion:    "Motion"
        case .bluetooth: "Bluetooth"
        }
    }

    var icon: String {
        switch self {
        case .location:  "location.fill"
        case .velocity:  "speedometer"
        case .steps:     "figure.walk"
        case .motion:    "move.3d"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        }
    }
}
