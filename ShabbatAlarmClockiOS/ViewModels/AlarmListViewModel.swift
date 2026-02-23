import Foundation
import UserNotifications
import Combine

@MainActor
final class AlarmListViewModel: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []
    @Published var showAddAlarm = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var alertMessage: String?
    @Published var showAlert = false

    private let repository: AlarmRepository
    private let notificationService: NotificationService

    // Main initializer (no default dependency expressions = avoids Swift concurrency warnings)
    init(repository: AlarmRepository, notificationService: NotificationService) {
        self.repository = repository
        self.notificationService = notificationService
    }

    // Convenience initializer for normal app usage
    convenience init() {
        self.init(
            repository: AlarmRepository(),
            notificationService: NotificationService()
        )
    }

    func onAppear() {
        alarms = repository.load().sorted(by: sortAlarms)

        Task {
            await refreshNotificationStatus()
            await rescheduleEnabledAlarmsIfPossible()
        }
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notificationService.authorizationStatus()
    }

    func requestNotificationPermissionIfNeeded() {
        Task {
            do {
                let granted = try await notificationService.requestAuthorization()
                await refreshNotificationStatus()

                if !granted {
                    presentAlert("Notifications were not allowed. You can still save alarms, but they won’t ring until notifications are enabled.")
                    return
                }

                let criticalSetting = await notificationService.criticalAlertSetting()
                if criticalSetting != .enabled {
                    presentAlert("To play alarms when Ring/Silent is off, Critical Alerts must be enabled for this app (Signing & Capabilities entitlement + Settings > Notifications > ShabbatAlarmClockiOS).")
                }

                await rescheduleEnabledAlarmsIfPossible()
            } catch {
                presentAlert("Failed to request notification permission: \(error.localizedDescription)")
            }
        }
    }

    func addAlarm(time: Date, label: String, weekday: Int) {
        var newAlarm = Alarm(
            time: time,
            label: label,
            isEnabled: true,
            weekday: weekday
        )

        if !(notificationStatus == .authorized || notificationStatus == .provisional) {
            newAlarm.isEnabled = false
            presentAlert("Alarm saved, but notifications are not enabled. Turn them on in Settings to activate alarms.")
        }

        alarms.append(newAlarm)
        alarms.sort(by: sortAlarms)
        persist()

        if newAlarm.isEnabled {
            Task {
                do {
                    try await notificationService.schedule(alarm: newAlarm)
                } catch {
                    handleSchedulingError(for: newAlarm.id, error: error)
                }
            }
        }
    }

    func toggleAlarm(id: UUID, isEnabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }

        alarms[index].isEnabled = isEnabled
        let alarm = alarms[index]
        persist()

        if isEnabled {
            Task {
                do {
                    try await notificationService.schedule(alarm: alarm)
                } catch {
                    handleSchedulingError(for: id, error: error)
                }
            }
        } else {
            notificationService.cancel(alarmID: id)
        }
    }

    func deleteAlarms(at offsets: IndexSet) {
        let idsToCancel = offsets.map { alarms[$0].id }
        notificationService.cancelAll(ids: idsToCancel)

        // Avoid remove(atOffsets:) so ViewModel doesn't need SwiftUI import
        for index in offsets.sorted(by: >) {
            alarms.remove(at: index)
        }

        persist()
    }

    private func handleSchedulingError(for alarmID: UUID, error: Error) {
        if let index = alarms.firstIndex(where: { $0.id == alarmID }) {
            alarms[index].isEnabled = false
            persist()
        }
        presentAlert("Couldn’t schedule alarm: \(error.localizedDescription)")
    }

    private func persist() {
        repository.save(alarms)
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    private func sortAlarms(_ lhs: Alarm, _ rhs: Alarm) -> Bool {
        if lhs.weekday != rhs.weekday {
            return lhs.weekday < rhs.weekday
        }

        let cal = Calendar.current
        let l = cal.dateComponents([.hour, .minute], from: lhs.time)
        let r = cal.dateComponents([.hour, .minute], from: rhs.time)

        let lMinutes = (l.hour ?? 0) * 60 + (l.minute ?? 0)
        let rMinutes = (r.hour ?? 0) * 60 + (r.minute ?? 0)

        return lMinutes < rMinutes
    }

    private func rescheduleEnabledAlarmsIfPossible() async {
        guard notificationStatus == .authorized || notificationStatus == .provisional else { return }

        for alarm in alarms where alarm.isEnabled {
            do {
                try await notificationService.schedule(alarm: alarm)
            } catch {
                handleSchedulingError(for: alarm.id, error: error)
            }
        }
    }
}
