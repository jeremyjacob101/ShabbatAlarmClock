import Foundation
import UserNotifications
import Combine

@MainActor
final class AlarmListViewModel: ObservableObject {
    struct AlertItem: Identifiable {
        enum Kind {
            case notice(message: String)
            case ringerReminder
            case notificationPermissionSettings
        }

        let id = UUID()
        let kind: Kind

        var isRingerReminder: Bool {
            if case .ringerReminder = kind {
                return true
            }

            return false
        }
    }

    @Published private(set) var alarms: [Alarm] = []
    @Published var showAddAlarm = false
    @Published var editingAlarm: Alarm?
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var activeAlert: AlertItem?

    private let repository: AlarmRepository
    private let notificationService: NotificationService
    private let reminderPreferences: AlarmRingerReminderPreferences
    private var oneTimeAlarmExpirationTask: Task<Void, Never>?
    private var pendingAlerts: [AlertItem] = []
    private var hasEvaluatedLaunchNotificationPrompt = false

    // Main initializer (no default dependency expressions = avoids Swift concurrency warnings)
    init(
        repository: AlarmRepository,
        notificationService: NotificationService,
        reminderPreferences: AlarmRingerReminderPreferences
    ) {
        self.repository = repository
        self.notificationService = notificationService
        self.reminderPreferences = reminderPreferences
    }

    // Convenience initializer for normal app usage
    convenience init() {
        self.init(
            repository: AlarmRepository(),
            notificationService: NotificationService(),
            reminderPreferences: AlarmRingerReminderPreferences()
        )
    }

    func onAppear() {
        alarms = repository.load().sorted(by: sortAlarms)
        reconcileOneTimeAlarms()
        scheduleNextOneTimeAlarmExpiration()

        Task { @MainActor in
            let status = await refreshNotificationStatus()
            presentLaunchNotificationPromptIfNeeded(status: status)
        }
    }

    func onSceneBecameActive() {
        reconcileOneTimeAlarms()
        scheduleNextOneTimeAlarmExpiration()

        Task { @MainActor in
            await refreshNotificationStatus()
        }
    }

    @discardableResult
    func refreshNotificationStatus() async -> UNAuthorizationStatus {
        let status = await notificationService.authorizationStatus()
        notificationStatus = status
        return status
    }

    func requestNotificationPermissionIfNeeded() {
        Task {
            let status = await refreshNotificationStatus()
            guard status == .notDetermined else { return }

            do {
                let granted = try await notificationService.requestAuthorization()
                let updatedStatus = await refreshNotificationStatus()

                if !granted || !isNotificationAuthorized(updatedStatus) {
                    presentAlert("Notifications were not allowed. You can still save alarms, but they won’t ring until notifications are enabled.")
                }
            } catch {
                await refreshNotificationStatus()
                presentAlert("Failed to request notification permission: \(error.localizedDescription)")
            }
        }
    }

    func addAlarm(
        time: Date,
        label: String,
        weekday: Int,
        sound: AlarmSound,
        soundDurationSeconds: Int,
        repeatsWeekly: Bool
    ) {
        Task {
            let notificationStatusResult = await notificationStatusForScheduling()
            let notificationsEnabled: Bool

            switch notificationStatusResult {
            case .success(let status):
                notificationsEnabled = isNotificationAuthorized(status)
                if !notificationsEnabled {
                    presentAlert("Alarm saved, but notifications are not enabled. Turn them on in Settings to activate alarms.")
                }
            case .failure(let error):
                notificationsEnabled = false
                presentAlert("Alarm saved, but notification permission couldn’t be requested: \(error.localizedDescription)")
            }

            var newAlarm = Alarm(
                time: time,
                label: label,
                isEnabled: notificationsEnabled,
                weekday: weekday,
                sound: sound,
                soundDurationSeconds: soundDurationSeconds,
                repeatsWeekly: repeatsWeekly
            )

            if !repeatsWeekly {
                newAlarm.scheduledDate = newAlarm.nextTriggerDate()
            }

            alarms.append(newAlarm)
            alarms.sort(by: sortAlarms)
            persist()
            presentRingerReminderIfNeeded()

            guard newAlarm.isEnabled else { return }

            do {
                try await notificationService.schedule(alarm: newAlarm)
            } catch {
                handleSchedulingError(for: newAlarm.id, error: error)
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
        soundDurationSeconds: Int,
        repeatsWeekly: Bool
    ) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }

        notificationService.cancel(alarmID: id)

        alarms[index].time = time
        alarms[index].label = label.isEmpty ? "Alarm" : label
        alarms[index].weekday = weekday
        alarms[index].sound = sound
        alarms[index].soundDurationSeconds = Alarm.clampedSoundDuration(soundDurationSeconds)
        alarms[index].repeatsWeekly = repeatsWeekly
        alarms[index].scheduledDate = repeatsWeekly ? nil : alarms[index].nextTriggerDate()

        let updatedAlarm = alarms[index]
        alarms.sort(by: sortAlarms)
        persist()
        editingAlarm = nil
        presentRingerReminderIfNeeded()

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

        if isEnabled {
            Task {
                let notificationStatusResult = await notificationStatusForScheduling()
                guard let refreshedIndex = alarms.firstIndex(where: { $0.id == id }) else { return }

                switch notificationStatusResult {
                case .success(let status):
                    guard isNotificationAuthorized(status) else {
                        alarms[refreshedIndex].isEnabled = false
                        persist()
                        presentAlert("Notifications are not enabled. Turn them on in Settings to activate alarms.")
                        return
                    }

                    alarms[refreshedIndex].isEnabled = true

                    if !alarms[refreshedIndex].repeatsWeekly {
                        alarms[refreshedIndex].scheduledDate = alarms[refreshedIndex].nextTriggerDate()
                    }

                    let alarm = alarms[refreshedIndex]
                    persist()

                    do {
                        try await notificationService.schedule(alarm: alarm)
                    } catch {
                        handleSchedulingError(for: id, error: error)
                    }
                case .failure(let error):
                    alarms[refreshedIndex].isEnabled = false
                    persist()
                    presentAlert("Couldn’t enable alarm because notification permission couldn’t be requested: \(error.localizedDescription)")
                }
            }
        } else {
            alarms[index].isEnabled = false
            notificationService.cancel(alarmID: id)
            persist()
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

    func dismissActiveAlert() {
        activeAlert = nil
        presentNextAlertIfNeeded()
    }

    func suppressSaveReminder() {
        reminderPreferences.suppressSaveReminder()

        if activeAlert?.isRingerReminder == true {
            activeAlert = nil
        }

        pendingAlerts.removeAll { $0.isRingerReminder }
        presentNextAlertIfNeeded()
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
        scheduleNextOneTimeAlarmExpiration()
    }

    private func presentAlert(_ message: String) {
        enqueueAlert(AlertItem(kind: .notice(message: message)))
    }

    private func presentLaunchNotificationPromptIfNeeded(status: UNAuthorizationStatus) {
        guard !hasEvaluatedLaunchNotificationPrompt else { return }
        hasEvaluatedLaunchNotificationPrompt = true

        guard !isNotificationAuthorized(status) else { return }

        if status == .notDetermined {
            requestNotificationPermissionIfNeeded()
            return
        }

        enqueueAlert(AlertItem(kind: .notificationPermissionSettings))
    }

    private func presentRingerReminderIfNeeded() {
        guard reminderPreferences.shouldShowSaveReminder else { return }

        reminderPreferences.markSaveReminderShown()
        enqueueAlert(AlertItem(kind: .ringerReminder))
    }

    private func enqueueAlert(_ alert: AlertItem) {
        if activeAlert == nil {
            activeAlert = alert
            return
        }

        pendingAlerts.append(alert)
    }

    private func presentNextAlertIfNeeded() {
        guard activeAlert == nil, !pendingAlerts.isEmpty else { return }

        let nextAlert = pendingAlerts.removeFirst()
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard self.activeAlert == nil else {
                self.pendingAlerts.insert(nextAlert, at: 0)
                return
            }

            self.activeAlert = nextAlert
        }
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
                alarms[index].scheduledDate = nil
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
        } else {
            scheduleNextOneTimeAlarmExpiration()
        }
    }

    private func scheduleNextOneTimeAlarmExpiration() {
        oneTimeAlarmExpirationTask?.cancel()
        oneTimeAlarmExpirationTask = nil

        guard let nextFireDate = alarms
            .filter({ $0.isEnabled && !$0.repeatsWeekly })
            .compactMap(\.scheduledDate)
            .min()
        else {
            return
        }

        let delay = max(nextFireDate.timeIntervalSinceNow, 0)
        let delayNanoseconds = UInt64(delay * 1_000_000_000)

        oneTimeAlarmExpirationTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handleOneTimeAlarmExpiration()
            }
        }
    }

    private func handleOneTimeAlarmExpiration() {
        reconcileOneTimeAlarms()
    }

    private func isNotificationAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func notificationStatusForScheduling() async -> Result<UNAuthorizationStatus, Error> {
        let status = await refreshNotificationStatus()
        guard status == .notDetermined else {
            return .success(status)
        }

        do {
            _ = try await notificationService.requestAuthorization()
            return .success(await refreshNotificationStatus())
        } catch {
            await refreshNotificationStatus()
            return .failure(error)
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
