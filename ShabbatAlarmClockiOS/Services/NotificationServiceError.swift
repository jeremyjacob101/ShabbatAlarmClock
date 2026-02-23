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
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            throw NotificationServiceError.notAuthorized
        }

        let weekdayName = weekdayName(for: alarm.weekday)
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "It’s \(weekdayName) at \(DateFormatter.alarmTime.string(from: alarm.time))"
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

        if inSubdirectory || inRoot {
            content.sound = UNNotificationSound(
                named: UNNotificationSoundName(rawValue: customSoundName)
            )
        } else {
            content.sound = .default
        }

        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        var components = DateComponents()
        components.weekday = alarm.weekday
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
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

    private func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard (1...symbols.count).contains(weekday) else {
            return "your selected day"
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
