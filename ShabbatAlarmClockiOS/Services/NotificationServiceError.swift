import Foundation
import UserNotifications

enum NotificationServiceError: LocalizedError {
    case notAuthorized
    case invalidTriggerDate

    var errorDescription: String? {
        let strings = AppStrings.current

        switch self {
        case .notAuthorized:
            return strings.notificationNotAuthorizedError
        case .invalidTriggerDate:
            return strings.invalidTriggerDateError
        }
    }
}

final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func schedule(alarm: Alarm) async throws {
        let strings = AppStrings.current
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            throw NotificationServiceError.notAuthorized
        }

        let weekdayName = weekdayName(for: alarm.weekday, strings: strings)
        let content = UNMutableNotificationContent()
        content.title = strings.displayedAlarmLabel(alarm.label)
        content.body = strings.notificationBody(weekday: weekdayName, time: alarm.time)
        if let customSoundName = alarm.sound.notificationSoundName(
            durationSeconds: alarm.soundDurationSeconds
        ) {
            content.sound = UNNotificationSound(
                named: UNNotificationSoundName(rawValue: customSoundName)
            )
        } else {
            content.sound = .default
        }

        let calendar = Calendar.current
        let trigger: UNCalendarNotificationTrigger

        if alarm.repeatsWeekly {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: alarm.time)
            var components = DateComponents()
            components.weekday = alarm.weekday
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            components.second = 0

            trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
        } else {
            guard let fireDate = alarm.scheduledDate ?? alarm.nextTriggerDate() else {
                throw NotificationServiceError.invalidTriggerDate
            }

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )

            trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
        }

        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func cancel(alarmID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [alarmID.uuidString])
    }

    func cancelAll(ids: [UUID]) {
        center.removePendingNotificationRequests(withIdentifiers: ids.map(\.uuidString))
    }

    private func weekdayName(for weekday: Int, strings: AppStrings) -> String {
        let symbols = strings.language.calendar.weekdaySymbols
        guard (1...symbols.count).contains(weekday) else {
            return strings.selectedDayFallback
        }

        return symbols[weekday - 1]
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}
