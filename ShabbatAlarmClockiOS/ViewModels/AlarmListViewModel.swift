import Foundation
import UserNotifications
import Combine

@MainActor
final class AlarmListViewModel: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []
    @Published var showAddAlarm = false
    @Published var editingAlarm: Alarm?
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
        reconcileOneTimeAlarms()

        Task {
            await refreshNotificationStatus()
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
                }
            } catch {
                presentAlert("Failed to request notification permission: \(error.localizedDescription)")
            }
        }
    }

    func addAlarm(time: Date, label: String, weekday: Int, sound: AlarmSound, repeatsWeekly: Bool) {
        var newAlarm = Alarm(
            time: time,
            label: label,
            isEnabled: true,
            weekday: weekday,
            sound: sound,
            repeatsWeekly: repeatsWeekly
        )

        if !repeatsWeekly {
            newAlarm.scheduledDate = newAlarm.nextTriggerDate()
        }

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

    func editAlarm(_ alarm: Alarm) {
        editingAlarm = alarm
    }

    func updateAlarm(
        id: UUID,
        time: Date,
        label: String,
        weekday: Int,
        sound: AlarmSound,
        repeatsWeekly: Bool
    ) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }

        notificationService.cancel(alarmID: id)

        alarms[index].time = time
        alarms[index].label = label.isEmpty ? "Alarm" : label
        alarms[index].weekday = weekday
        alarms[index].sound = sound
        alarms[index].repeatsWeekly = repeatsWeekly
        alarms[index].scheduledDate = repeatsWeekly ? nil : alarms[index].nextTriggerDate()

        let updatedAlarm = alarms[index]
        alarms.sort(by: sortAlarms)
        persist()
        editingAlarm = nil

        guard updatedAlarm.isEnabled else { return }

        Task {
            do {
                try await notificationService.schedule(alarm: updatedAlarm)
            } catch {
                handleSchedulingError(for: id, error: error)
            }
        }
    }

    func toggleAlarm(id: UUID, isEnabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }

        alarms[index].isEnabled = isEnabled

        if isEnabled && !alarms[index].repeatsWeekly {
            alarms[index].scheduledDate = alarms[index].nextTriggerDate()
        }

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

    private func reconcileOneTimeAlarms() {
        let now = Date()
        var didChange = false

        for index in alarms.indices {
            guard !alarms[index].repeatsWeekly else { continue }

            if alarms[index].isEnabled,
               let scheduledDate = alarms[index].scheduledDate,
               scheduledDate <= now {
                alarms[index].isEnabled = false
                notificationService.cancel(alarmID: alarms[index].id)
                didChange = true
            } else if alarms[index].isEnabled,
                      alarms[index].scheduledDate == nil {
                alarms[index].scheduledDate = alarms[index].nextTriggerDate(referenceDate: now)
                didChange = true
            }
        }

        if didChange {
            alarms.sort(by: sortAlarms)
            persist()
        }
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

}
