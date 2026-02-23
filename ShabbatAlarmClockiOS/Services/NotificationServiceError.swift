import Foundation
import UserNotifications

enum NotificationServiceError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notifications are not authorized. Please enable them in Settings."
        }
    }
}

final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let defaultSoundDirectory = "AlarmSounds"
    private let defaultSoundFileName = "chimes.wav"
    private let defaultSoundBaseName = "chimes"

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }

    func criticalAlertSetting() async -> UNNotificationSetting {
        let settings = await notificationSettings()
        return settings.criticalAlertSetting
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func schedule(alarm: Alarm) async throws {
        let settings = await notificationSettings()
        let status = settings.authorizationStatus
        guard status == .authorized || status == .provisional else {
            throw NotificationServiceError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "It’s \(DateFormatter.alarmTime.string(from: alarm.time))"
        let inSubdirectory = Bundle.main.url(
            forResource: defaultSoundBaseName,
            withExtension: "wav",
            subdirectory: defaultSoundDirectory
        ) != nil
        let inRoot = Bundle.main.url(
            forResource: defaultSoundBaseName,
            withExtension: "wav"
        ) != nil

        let customSoundName = inSubdirectory
            ? "\(defaultSoundDirectory)/\(defaultSoundFileName)"
            : defaultSoundFileName
        let canUseCritical = settings.criticalAlertSetting == .enabled

        if inSubdirectory || inRoot {
            if canUseCritical {
                content.interruptionLevel = .critical
                content.sound = UNNotificationSound.criticalSoundNamed(
                    UNNotificationSoundName(rawValue: customSoundName),
                    withAudioVolume: 1.0
                )
            } else {
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(rawValue: customSoundName)
                )
            }
        } else {
            content.sound = canUseCritical
                ? .defaultCriticalSound(withAudioVolume: 1.0)
                : .default
        }

        var components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)

        if !alarm.repeatsDaily {
            let nextDate = nextOccurrence(for: alarm.time)
            components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: alarm.repeatsDaily
        )

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

    private func nextOccurrence(for time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()

        let hm = calendar.dateComponents([.hour, .minute], from: time)
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = hm.hour
        todayComponents.minute = hm.minute
        todayComponents.second = 0

        let todayTarget = calendar.date(from: todayComponents) ?? now
        if todayTarget > now {
            return todayTarget
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayTarget) ?? todayTarget
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}
