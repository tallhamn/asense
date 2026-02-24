import SwiftUI

struct SensorToggleRow: View {
    let sensorType: SensorType
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label(sensorType.displayName, systemImage: sensorType.icon)
        }
    }
}
