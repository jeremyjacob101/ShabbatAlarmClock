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
    private struct NotificationCandidate {
        let alarm: Alarm
        let fireDate: Date
    }

    private struct WeekdayTimeSlot: Hashable {
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    private struct WeeklySlotKey: Hashable, Comparable {
        let time: WeekdayTimeSlot

        var identifier: String {
            "\(NotificationService.weeklyIdentifierPrefix)\(time.weekday)-\(time.hour)-\(time.minute)"
        }

        static func < (lhs: WeeklySlotKey, rhs: WeeklySlotKey) -> Bool {
            if lhs.time.weekday != rhs.time.weekday {
                return lhs.time.weekday < rhs.time.weekday
            }

            if lhs.time.hour != rhs.time.hour {
                return lhs.time.hour < rhs.time.hour
            }

            return lhs.time.minute < rhs.time.minute
        }
    }

    private struct OnceSlotKey: Hashable, Comparable {
        let fireDate: Date
        let timestamp: Int
        let weekdayTime: WeekdayTimeSlot

        var identifier: String {
            "\(NotificationService.onceIdentifierPrefix)\(timestamp)"
        }

        static func < (lhs: OnceSlotKey, rhs: OnceSlotKey) -> Bool {
            lhs.fireDate < rhs.fireDate
        }
    }

    private let center = UNUserNotificationCenter.current()
    private static let managedNotificationKey = "managedAlarmNotification"
    private static let weeklyIdentifierPrefix = "weekly-"
    private static let onceIdentifierPrefix = "once-"

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

        let requests = try notificationRequests(for: [alarm])

        for request in requests {
            try await add(request: request)
        }
    }

    func replaceScheduledNotifications(for alarms: [Alarm], knownAlarmIDs: [UUID]) async throws {
        let identifiersToRemove = await managedNotificationIdentifiers(knownAlarmIDs: knownAlarmIDs)
        if !identifiersToRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }

        let enabledAlarms = alarms.filter(\.isEnabled)
        guard !enabledAlarms.isEmpty else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            throw NotificationServiceError.notAuthorized
        }

        let requests = try notificationRequests(for: enabledAlarms)

        for request in requests {
            try Task.checkCancellation()
            try await add(request: request)
        }
    }

    func clearManagedNotifications(knownAlarmIDs: [UUID]) async {
        let identifiersToRemove = await managedNotificationIdentifiers(knownAlarmIDs: knownAlarmIDs)
        guard !identifiersToRemove.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
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

    private func notificationRequests(for alarms: [Alarm]) throws -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let now = Date()
        let sortedAlarms = alarms.sorted(by: notificationRepresentativeOrdering)
        var weeklyRepresentatives: [WeeklySlotKey: NotificationCandidate] = [:]
        var onceRepresentatives: [OnceSlotKey: NotificationCandidate] = [:]

        for alarm in sortedAlarms {
            if alarm.repeatsWeekly {
                for fireDate in try weeklyFireDates(for: alarm, calendar: calendar) {
                    let key = WeeklySlotKey(
                        time: weekdayTimeSlot(for: fireDate, calendar: calendar)
                    )

                    if weeklyRepresentatives[key] == nil {
                        weeklyRepresentatives[key] = NotificationCandidate(
                            alarm: alarm,
                            fireDate: fireDate
                        )
                    }
                }
                continue
            }

            guard let primaryFireDate = alarm.primaryFireDate(referenceDate: now, calendar: calendar) else {
                throw NotificationServiceError.invalidTriggerDate
            }

            for fireDate in alarm.notificationFireDates(
                primaryFireDate: primaryFireDate,
                calendar: calendar
            ) where fireDate > now {
                let timestamp = Int(fireDate.timeIntervalSince1970.rounded())
                let key = OnceSlotKey(
                    fireDate: fireDate,
                    timestamp: timestamp,
                    weekdayTime: weekdayTimeSlot(for: fireDate, calendar: calendar)
                )

                if onceRepresentatives[key] == nil {
                    onceRepresentatives[key] = NotificationCandidate(
                        alarm: alarm,
                        fireDate: fireDate
                    )
                }
            }
        }

        let weeklyTimes = Set(weeklyRepresentatives.keys.map(\.time))
        let strings = AppStrings.current
        var requests: [UNNotificationRequest] = []

        for key in weeklyRepresentatives.keys.sorted() {
            guard let candidate = weeklyRepresentatives[key] else { continue }
            requests.append(
                weeklyRequest(
                    for: candidate.alarm,
                    key: key,
                    fireDate: candidate.fireDate,
                    strings: strings
                )
            )
        }

        for key in onceRepresentatives.keys.sorted() {
            guard !weeklyTimes.contains(key.weekdayTime) else { continue }
            guard let candidate = onceRepresentatives[key] else { continue }
            requests.append(
                oneTimeRequest(
                    for: candidate.alarm,
                    fireDate: candidate.fireDate,
                    identifier: key.identifier,
                    strings: strings
                )
            )
        }

        return requests
    }

    private func weeklyRequest(
        for alarm: Alarm,
        key: WeeklySlotKey,
        fireDate: Date,
        strings: AppStrings
    ) -> UNNotificationRequest {
        var components = DateComponents()
        components.weekday = key.time.weekday
        components.hour = key.time.hour
        components.minute = key.time.minute
        components.second = 0

        return UNNotificationRequest(
            identifier: key.identifier,
            content: notificationContent(
                for: alarm,
                weekday: key.time.weekday,
                time: fireDate,
                strings: strings
            ),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
        )
    }

    private func oneTimeRequest(
        for alarm: Alarm,
        fireDate: Date,
        identifier: String,
        strings: AppStrings
    ) -> UNNotificationRequest {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )

        return UNNotificationRequest(
            identifier: identifier,
            content: notificationContent(
                for: alarm,
                weekday: calendar.component(.weekday, from: fireDate),
                time: fireDate,
                strings: strings
            ),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
        )
    }

    private func notificationContent(
        for alarm: Alarm,
        weekday: Int,
        time: Date,
        strings: AppStrings
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = strings.displayedAlarmLabel(alarm.label)
        content.body = strings.notificationBody(
            weekday: weekdayName(for: weekday, strings: strings),
            time: time
        )
        content.userInfo[Self.managedNotificationKey] = true

        if let customSoundName = alarm.sound.notificationSoundName(
            durationSeconds: alarm.soundDurationSeconds
        ) {
            content.sound = UNNotificationSound(
                named: UNNotificationSoundName(rawValue: customSoundName)
            )
        } else {
            content.sound = .default
        }

        return content
    }

    private func notificationRepresentativeOrdering(_ lhs: Alarm, _ rhs: Alarm) -> Bool {
        if lhs.repeatsWeekly != rhs.repeatsWeekly {
            return lhs.repeatsWeekly && !rhs.repeatsWeekly
        }

        if lhs.weekday != rhs.weekday {
            return lhs.weekday < rhs.weekday
        }

        let calendar = Calendar.current
        let leftTime = calendar.dateComponents([.hour, .minute], from: lhs.time)
        let rightTime = calendar.dateComponents([.hour, .minute], from: rhs.time)
        let leftMinutes = (leftTime.hour ?? 0) * 60 + (leftTime.minute ?? 0)
        let rightMinutes = (rightTime.hour ?? 0) * 60 + (rightTime.minute ?? 0)

        if leftMinutes != rightMinutes {
            return leftMinutes < rightMinutes
        }

        let leftFireDate = lhs.scheduledDate ?? lhs.nextTriggerDate() ?? lhs.time
        let rightFireDate = rhs.scheduledDate ?? rhs.nextTriggerDate() ?? rhs.time
        if leftFireDate != rightFireDate {
            return leftFireDate < rightFireDate
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func weeklyFireDates(for alarm: Alarm, calendar: Calendar) throws -> [Date] {
        var components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        components.weekday = alarm.weekday
        components.second = 0

        guard let primaryFireDate = calendar.nextDate(
            after: Date(timeIntervalSince1970: 0),
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            throw NotificationServiceError.invalidTriggerDate
        }

        return alarm.notificationFireDates(primaryFireDate: primaryFireDate, calendar: calendar)
    }

    private func weekdayTimeSlot(for fireDate: Date, calendar: Calendar) -> WeekdayTimeSlot {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: fireDate)

        return WeekdayTimeSlot(
            weekday: components.weekday ?? 1,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }

    private func managedNotificationIdentifiers(knownAlarmIDs: [UUID]) async -> [String] {
        let legacyAlarmIDs = Set(knownAlarmIDs.map(\.uuidString))
        let pendingRequests = await pendingNotificationRequests()
        var identifiers = legacyAlarmIDs

        for request in pendingRequests where isManagedRequest(request, legacyAlarmIDs: legacyAlarmIDs) {
            identifiers.insert(request.identifier)
        }

        return Array(identifiers)
    }

    private func isManagedRequest(
        _ request: UNNotificationRequest,
        legacyAlarmIDs: Set<String>
    ) -> Bool {
        if legacyAlarmIDs.contains(request.identifier) {
            return true
        }

        if request.identifier.hasPrefix(Self.weeklyIdentifierPrefix)
            || request.identifier.hasPrefix(Self.onceIdentifierPrefix) {
            return true
        }

        return request.content.userInfo[Self.managedNotificationKey] as? Bool == true
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func add(request: UNNotificationRequest) async throws {
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
}
