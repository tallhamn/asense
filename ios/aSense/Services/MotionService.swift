import Foundation
import CoreMotion

@Observable
final class MotionService {
    var currentSteps: StepsData?
    var currentMotion: MotionData?

    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private var active = false

    func start() {
        guard !active else { return }
        active = true
        startPedometer()
        startActivityUpdates()
    }

    func stop() {
        guard active else { return }
        active = false
        pedometer.stopUpdates()
        activityManager.stopActivityUpdates()
        currentSteps = nil
        currentMotion = nil
    }

    // MARK: - Pedometer

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { [weak self] data, _ in
            guard let data else { return }
            Task { @MainActor in
                self?.currentSteps = StepsData(
                    count: data.numberOfSteps.intValue,
                    distance: data.distance?.doubleValue ?? 0,
                    floorsUp: data.floorsAscended?.intValue ?? 0,
                    floorsDown: data.floorsDescended?.intValue ?? 0
                )
            }
        }
    }

    // MARK: - Motion Activity

    private func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }

            let state: String
            if activity.automotive {
                state = "driving"
            } else if activity.cycling {
                state = "cycling"
            } else if activity.running {
                state = "running"
            } else if activity.walking {
                state = "walking"
            } else if activity.stationary {
                state = "stationary"
            } else {
                state = "unknown"
            }

            let confidence: String
            switch activity.confidence {
            case .high:   confidence = "high"
            case .medium: confidence = "medium"
            case .low:    confidence = "low"
            @unknown default: confidence = "unknown"
            }

            self?.currentMotion = MotionData(state: state, confidence: confidence)
        }
    }
}
