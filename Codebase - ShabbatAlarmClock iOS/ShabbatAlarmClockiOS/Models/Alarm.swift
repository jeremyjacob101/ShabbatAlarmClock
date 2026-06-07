import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    struct NotificationSoundSegment: Equatable {
        let offsetSeconds: Int
        let durationSeconds: Int
    }

    static let supportedSoundDurations = [10, 20, 30, 40, 50, 60]
    static let soundDurationRange = supportedSoundDurations.first!...supportedSoundDurations.last!
    static let defaultSoundDurationSeconds = 20
    static let previewSoundDurationSeconds = 10
    static let autoSnoozeMinutes = 5

    let id: UUID
    var time: Date
    var label: String
    var isEnabled: Bool
    var weekday: Int
    var sound: AlarmSound
    var soundDurationSeconds: Int
    var soundNoiseLevel: AlarmNoiseLevel
    var repeatsWeekly: Bool
    var autoSnoozeEnabled: Bool
    var scheduledDate: Date?

    init(
        id: UUID = UUID(),
        time: Date,
        label: String = AppStrings.current.defaultAlarmLabel,
        isEnabled: Bool = true,
        weekday: Int = Calendar.current.component(.weekday, from: Date()),
        sound: AlarmSound = .defaultSound,
        soundDurationSeconds: Int = Alarm.defaultSoundDurationSeconds,
        soundNoiseLevel: AlarmNoiseLevel = .defaultLevel,
        repeatsWeekly: Bool = true,
        autoSnoozeEnabled: Bool = false,
        scheduledDate: Date? = nil
    ) {
        self.id = id
        self.time = time
        self.label = AppStrings.current.normalizedAlarmLabelInput(label)
        self.isEnabled = isEnabled
        self.weekday = Alarm.normalizedWeekday(weekday, fallbackDate: time)
        self.sound = sound
        self.soundDurationSeconds = Alarm.clampedSoundDuration(soundDurationSeconds)
        self.soundNoiseLevel = soundNoiseLevel
        self.repeatsWeekly = repeatsWeekly
        self.autoSnoozeEnabled = autoSnoozeEnabled
        self.scheduledDate = repeatsWeekly ? nil : scheduledDate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case time
        case label
        case isEnabled
        case weekday
        case sound
        case soundDurationSeconds
        case soundNoiseLevel
        case repeatsWeekly
        case autoSnoozeEnabled
        case scheduledDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let time = try container.decode(Date.self, forKey: .time)
        let label = try container.decode(String.self, forKey: .label)
        let isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        let decodedWeekday = try container.decodeIfPresent(Int.self, forKey: .weekday)
        let sound = try container.decodeIfPresent(AlarmSound.self, forKey: .sound) ?? .defaultSound
        let soundDurationSeconds = try container.decodeIfPresent(
            Int.self,
            forKey: .soundDurationSeconds
        ) ?? Self.defaultSoundDurationSeconds
        let soundNoiseLevel = try container.decodeIfPresent(
            AlarmNoiseLevel.self,
            forKey: .soundNoiseLevel
        ) ?? .defaultLevel
        let repeatsWeekly = try container.decodeIfPresent(Bool.self, forKey: .repeatsWeekly) ?? true
        let autoSnoozeEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .autoSnoozeEnabled
        ) ?? false
        let scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)

        self.init(
            id: id,
            time: time,
            label: label,
            isEnabled: isEnabled,
            weekday: decodedWeekday ?? Calendar.current.component(.weekday, from: time),
            sound: sound,
            soundDurationSeconds: soundDurationSeconds,
            soundNoiseLevel: soundNoiseLevel,
            repeatsWeekly: repeatsWeekly,
            autoSnoozeEnabled: autoSnoozeEnabled,
            scheduledDate: scheduledDate
        )
    }

    func nextTriggerDate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.hour, .minute], from: time)
        components.weekday = weekday
        components.second = 0

        return calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    func primaryFireDate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        if repeatsWeekly {
            return nextTriggerDate(referenceDate: referenceDate, calendar: calendar)
        }

        return scheduledDate ?? nextTriggerDate(referenceDate: referenceDate, calendar: calendar)
    }

    func notificationOccurrenceDates(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        guard let primaryFireDate = primaryFireDate(
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return []
        }

        return notificationOccurrenceDates(primaryFireDate: primaryFireDate, calendar: calendar)
    }

    func notificationOccurrenceDates(
        primaryFireDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        var fireDates = [primaryFireDate]

        if autoSnoozeEnabled,
           let snoozeDate = calendar.date(
                byAdding: .minute,
                value: Self.autoSnoozeMinutes,
                to: primaryFireDate
           ) {
            fireDates.append(snoozeDate)
        }

        return fireDates
    }

    func oneTimeExpirationDate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard !repeatsWeekly else { return nil }

        guard let lastOccurrenceDate = notificationOccurrenceDates(
            referenceDate: referenceDate,
            calendar: calendar
        ).last else {
            return nil
        }

        guard let lastSegment = Self.notificationSoundSegments(
            for: soundDurationSeconds
        ).last else {
            return lastOccurrenceDate
        }

        return calendar.date(
            byAdding: .second,
            value: lastSegment.offsetSeconds,
            to: lastOccurrenceDate
        ) ?? lastOccurrenceDate
    }

    private static func normalizedWeekday(_ weekday: Int, fallbackDate: Date) -> Int {
        let validRange = 1...7
        if validRange.contains(weekday) {
            return weekday
        }

        return Calendar.current.component(.weekday, from: fallbackDate)
    }

    static func clampedSoundDuration(_ value: Int) -> Int {
        guard let first = supportedSoundDurations.first,
              let last = supportedSoundDurations.last else {
            return defaultSoundDurationSeconds
        }

        if supportedSoundDurations.contains(value) {
            return value
        }

        if value <= first {
            return first
        }

        return supportedSoundDurations.first(where: { value < $0 }) ?? last
    }

    static func notificationSoundSegments(for durationSeconds: Int) -> [NotificationSoundSegment] {
        switch clampedSoundDuration(durationSeconds) {
        case 10:
            return [NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 10)]
        case 20:
            return [NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 20)]
        case 30:
            return [NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 30)]
        case 40:
            return [
                NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 30),
                NotificationSoundSegment(offsetSeconds: 30, durationSeconds: 10)
            ]
        case 50:
            return [
                NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 30),
                NotificationSoundSegment(offsetSeconds: 30, durationSeconds: 20)
            ]
        case 60:
            return [
                NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 30),
                NotificationSoundSegment(offsetSeconds: 30, durationSeconds: 30)
            ]
        default:
            return [NotificationSoundSegment(offsetSeconds: 0, durationSeconds: 10)]
        }
    }
}
