import SwiftUI
import BackgroundTasks

@main
struct aSenseApp: App {
    @State private var telemetryService = TelemetryService()

    init() {
        KeychainService.shared.ensureKeysExist()
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(telemetryService: telemetryService)
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.momstudios.asense.telemetry-flush",
            using: nil
        ) { task in
            self.handleBackgroundFlush(task: task as! BGProcessingTask)
        }
    }

    private func handleBackgroundFlush(task: BGProcessingTask) {
        let flushTask = Task {
            await telemetryService.collectAndTransmit()
        }

        task.expirationHandler = {
            flushTask.cancel()
        }

        Task {
            _ = await flushTask.value
            task.setTaskCompleted(success: true)
            scheduleBackgroundFlush()
        }
    }

    private func scheduleBackgroundFlush() {
        let request = BGProcessingTaskRequest(
            identifier: "com.momstudios.asense.telemetry-flush"
        )
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
