import Foundation
import UserNotifications

enum NotificationServiceError: LocalizedError {
    case notAuthorized
    case invalidTriggerDate
    case soundUnavailable

    var errorDescription: String? {
        let strings = AppStrings.current

        switch self {
        case .notAuthorized:
            return strings.notificationNotAuthorizedError
        case .invalidTriggerDate:
            return strings.invalidTriggerDateError
        case .soundUnavailable:
            return strings.notificationSoundUnavailableError
        }
    }
}

final class NotificationService {
    private struct NotificationCandidate {
        let alarm: Alarm
        let fireDate: Date
        let displayedOccurrenceDate: Date
        let segmentDurationSeconds: Int
    }

    private struct WeekdayTimeSlot: Hashable {
        let weekday: Int
        let hour: Int
        let minute: Int
        let second: Int
    }

    private struct WeeklySlotKey: Hashable, Comparable {
        let time: WeekdayTimeSlot

        var identifier: String {
            "\(NotificationService.weeklyIdentifierPrefix)\(time.weekday)-\(time.hour)-\(time.minute)-\(time.second)"
        }

        static func < (lhs: WeeklySlotKey, rhs: WeeklySlotKey) -> Bool {
            if lhs.time.weekday != rhs.time.weekday {
                return lhs.time.weekday < rhs.time.weekday
            }

            if lhs.time.hour != rhs.time.hour {
                return lhs.time.hour < rhs.time.hour
            }

            if lhs.time.minute != rhs.time.minute {
                return lhs.time.minute < rhs.time.minute
            }

            return lhs.time.second < rhs.time.second
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
    private let notificationSoundStore: NotificationSoundFileStore
    private static let managedNotificationKey = "managedAlarmNotification"
    private static let weeklyIdentifierPrefix = "weekly-"
    private static let onceIdentifierPrefix = "once-"

    init(notificationSoundStore: NotificationSoundFileStore = .shared) {
        self.notificationSoundStore = notificationSoundStore
    }

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
        let enabledAlarms = alarms.filter(\.isEnabled)
        let managedIdentifiers = await managedNotificationIdentifiers(knownAlarmIDs: knownAlarmIDs)
        guard !enabledAlarms.isEmpty else {
            if !managedIdentifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers)
            }
            return
        }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            if !managedIdentifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers)
            }
            throw NotificationServiceError.notAuthorized
        }

        let requests = try notificationRequests(for: enabledAlarms)
        let requestIdentifiers = Set(requests.map(\.identifier))

        for request in requests {
            try Task.checkCancellation()
            try await add(request: request)
        }

        let staleIdentifiers = managedIdentifiers.filter { !requestIdentifiers.contains($0) }
        if !staleIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
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
                for occurrenceDate in try weeklyOccurrenceDates(for: alarm, calendar: calendar) {
                    try populateWeeklyRepresentatives(
                        for: alarm,
                        occurrenceDate: occurrenceDate,
                        calendar: calendar,
                        representatives: &weeklyRepresentatives
                    )
                }
                continue
            }

            guard let primaryFireDate = alarm.primaryFireDate(referenceDate: now, calendar: calendar) else {
                throw NotificationServiceError.invalidTriggerDate
            }

            for occurrenceDate in alarm.notificationOccurrenceDates(
                primaryFireDate: primaryFireDate,
                calendar: calendar
            ) {
                try populateOnceRepresentatives(
                    for: alarm,
                    occurrenceDate: occurrenceDate,
                    calendar: calendar,
                    now: now,
                    representatives: &onceRepresentatives
                )
            }
        }

        let weeklyTimes = Set(weeklyRepresentatives.keys.map(\.time))
        let strings = AppStrings.current
        var requests: [UNNotificationRequest] = []

        for key in weeklyRepresentatives.keys.sorted() {
            guard let candidate = weeklyRepresentatives[key] else { continue }
            requests.append(
                try weeklyRequest(
                    for: candidate.alarm,
                    key: key,
                    fireDate: candidate.fireDate,
                    displayedOccurrenceDate: candidate.displayedOccurrenceDate,
                    segmentDurationSeconds: candidate.segmentDurationSeconds,
                    strings: strings
                )
            )
        }

        for key in onceRepresentatives.keys.sorted() {
            guard !weeklyTimes.contains(key.weekdayTime) else { continue }
            guard let candidate = onceRepresentatives[key] else { continue }
            requests.append(
                try oneTimeRequest(
                    for: candidate.alarm,
                    fireDate: candidate.fireDate,
                    identifier: key.identifier,
                    displayedOccurrenceDate: candidate.displayedOccurrenceDate,
                    segmentDurationSeconds: candidate.segmentDurationSeconds,
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
        displayedOccurrenceDate: Date,
        segmentDurationSeconds: Int,
        strings: AppStrings
    ) throws -> UNNotificationRequest {
        var components = DateComponents()
        components.weekday = key.time.weekday
        components.hour = key.time.hour
        components.minute = key.time.minute
        components.second = key.time.second
        components.calendar = Calendar.current
        components.timeZone = Calendar.current.timeZone

        return UNNotificationRequest(
            identifier: key.identifier,
            content: try notificationContent(
                for: alarm,
                displayedOccurrenceDate: displayedOccurrenceDate,
                segmentDurationSeconds: segmentDurationSeconds,
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
        displayedOccurrenceDate: Date,
        segmentDurationSeconds: Int,
        strings: AppStrings
    ) throws -> UNNotificationRequest {
        let calendar = Calendar.current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        components.calendar = calendar
        components.timeZone = calendar.timeZone

        return UNNotificationRequest(
            identifier: identifier,
            content: try notificationContent(
                for: alarm,
                displayedOccurrenceDate: displayedOccurrenceDate,
                segmentDurationSeconds: segmentDurationSeconds,
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
        displayedOccurrenceDate: Date,
        segmentDurationSeconds: Int,
        strings: AppStrings
    ) throws -> UNMutableNotificationContent {
        let calendar = Calendar.current
        let content = UNMutableNotificationContent()
        content.title = strings.displayedAlarmLabel(alarm.label)
        content.body = strings.notificationBody(
            weekday: weekdayName(
                for: calendar.component(.weekday, from: displayedOccurrenceDate),
                strings: strings
            ),
            time: displayedOccurrenceDate
        )
        content.userInfo[Self.managedNotificationKey] = true

        let customSoundName = try notificationSoundName(
            for: alarm,
            segmentDurationSeconds: segmentDurationSeconds
        )
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(rawValue: customSoundName)
        )

        return content
    }

    private func notificationSoundName(
        for alarm: Alarm,
        segmentDurationSeconds: Int
    ) throws -> String {
        guard let sourceURL = alarm.sound.bundledFileURL(
            durationSeconds: segmentDurationSeconds,
            noiseLevel: alarm.soundNoiseLevel
        ), let fileName = alarm.sound.notificationSoundName(
            durationSeconds: segmentDurationSeconds,
            noiseLevel: alarm.soundNoiseLevel
        ) else {
            throw NotificationServiceError.soundUnavailable
        }

        // iOS notification sounds are resolved by filename from Library/Sounds.
        do {
            return try notificationSoundStore.prepareSoundFile(from: sourceURL, fileName: fileName)
        } catch {
            throw NotificationServiceError.soundUnavailable
        }
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

    private func weeklyOccurrenceDates(for alarm: Alarm, calendar: Calendar) throws -> [Date] {
        var components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        components.weekday = alarm.weekday
        components.second = 0

        guard let primaryFireDate = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            throw NotificationServiceError.invalidTriggerDate
        }

        return alarm.notificationOccurrenceDates(primaryFireDate: primaryFireDate, calendar: calendar)
    }

    private func weekdayTimeSlot(for fireDate: Date, calendar: Calendar) -> WeekdayTimeSlot {
        let components = calendar.dateComponents([.weekday, .hour, .minute, .second], from: fireDate)

        return WeekdayTimeSlot(
            weekday: components.weekday ?? 1,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0
        )
    }

    private func populateWeeklyRepresentatives(
        for alarm: Alarm,
        occurrenceDate: Date,
        calendar: Calendar,
        representatives: inout [WeeklySlotKey: NotificationCandidate]
    ) throws {
        for segment in Alarm.notificationSoundSegments(for: alarm.soundDurationSeconds) {
            guard let fireDate = calendar.date(
                byAdding: .second,
                value: segment.offsetSeconds,
                to: occurrenceDate
            ) else {
                throw NotificationServiceError.invalidTriggerDate
            }

            let key = WeeklySlotKey(
                time: weekdayTimeSlot(for: fireDate, calendar: calendar)
            )

            let candidate = NotificationCandidate(
                alarm: alarm,
                fireDate: fireDate,
                displayedOccurrenceDate: occurrenceDate,
                segmentDurationSeconds: segment.durationSeconds
            )

            if shouldUseCandidate(candidate, insteadOf: representatives[key]) {
                representatives[key] = candidate
            }
        }
    }

    private func populateOnceRepresentatives(
        for alarm: Alarm,
        occurrenceDate: Date,
        calendar: Calendar,
        now: Date,
        representatives: inout [OnceSlotKey: NotificationCandidate]
    ) throws {
        for segment in Alarm.notificationSoundSegments(for: alarm.soundDurationSeconds) {
            guard let fireDate = calendar.date(
                byAdding: .second,
                value: segment.offsetSeconds,
                to: occurrenceDate
            ) else {
                throw NotificationServiceError.invalidTriggerDate
            }

            guard fireDate > now else { continue }

            let timestamp = Int(fireDate.timeIntervalSince1970.rounded())
            let key = OnceSlotKey(
                fireDate: fireDate,
                timestamp: timestamp,
                weekdayTime: weekdayTimeSlot(for: fireDate, calendar: calendar)
            )

            let candidate = NotificationCandidate(
                alarm: alarm,
                fireDate: fireDate,
                displayedOccurrenceDate: occurrenceDate,
                segmentDurationSeconds: segment.durationSeconds
            )

            if shouldUseCandidate(candidate, insteadOf: representatives[key]) {
                representatives[key] = candidate
            }
        }
    }

    private func shouldUseCandidate(
        _ candidate: NotificationCandidate,
        insteadOf existingCandidate: NotificationCandidate?
    ) -> Bool {
        guard let existingCandidate else { return true }
        return candidate.segmentDurationSeconds > existingCandidate.segmentDurationSeconds
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
