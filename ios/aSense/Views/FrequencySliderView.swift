import SwiftUI

struct FrequencySliderView: View {
    @Binding var interval: TimeInterval

    private static let stops: [(TimeInterval, String)] = [
        (10, "10s"),
        (30, "30s"),
        (60, "1m"),
        (300, "5m"),
        (900, "15m"),
    ]

    private var currentIndex: Double {
        Double(Self.stops.firstIndex { $0.0 == interval } ?? 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transmission Frequency")
                .font(.headline)

            HStack {
                ForEach(Array(Self.stops.enumerated()), id: \.offset) { _, stop in
                    Text(stop.1)
                        .font(.caption2)
                        .foregroundStyle(interval == stop.0 ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            Slider(
                value: Binding(
                    get: { currentIndex },
                    set: { newValue in
                        let idx = Int(newValue.rounded())
                        let clamped = min(max(idx, 0), Self.stops.count - 1)
                        interval = Self.stops[clamped].0
                    }
                ),
                in: 0...Double(Self.stops.count - 1),
                step: 1
            )
        }
    }
}
