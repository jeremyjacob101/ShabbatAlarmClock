import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    static let supportedSoundDurations = [5, 10, 15, 20]
    static let soundDurationRange = supportedSoundDurations.first!...supportedSoundDurations.last!
    static let defaultSoundDurationSeconds = supportedSoundDurations[supportedSoundDurations.count / 2]

    let id: UUID
    var time: Date
    var label: String
    var isEnabled: Bool
    var weekday: Int
    var sound: AlarmSound
    var soundDurationSeconds: Int
    var repeatsWeekly: Bool
    var scheduledDate: Date?

    init(
        id: UUID = UUID(),
        time: Date,
        label: String = "Alarm",
        isEnabled: Bool = true,
        weekday: Int = Calendar.current.component(.weekday, from: Date()),
        sound: AlarmSound = .defaultSound,
        soundDurationSeconds: Int = Alarm.defaultSoundDurationSeconds,
        repeatsWeekly: Bool = true,
        scheduledDate: Date? = nil
    ) {
        self.id = id
        self.time = time
        self.label = label.isEmpty ? "Alarm" : label
        self.isEnabled = isEnabled
        self.weekday = Alarm.normalizedWeekday(weekday, fallbackDate: time)
        self.sound = sound
        self.soundDurationSeconds = Alarm.clampedSoundDuration(soundDurationSeconds)
        self.repeatsWeekly = repeatsWeekly
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
        case repeatsWeekly
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
        let repeatsWeekly = try container.decodeIfPresent(Bool.self, forKey: .repeatsWeekly) ?? true
        let scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)

        self.init(
            id: id,
            time: time,
            label: label,
            isEnabled: isEnabled,
            weekday: decodedWeekday ?? Calendar.current.component(.weekday, from: time),
            sound: sound,
            soundDurationSeconds: soundDurationSeconds,
            repeatsWeekly: repeatsWeekly,
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

    private static func normalizedWeekday(_ weekday: Int, fallbackDate: Date) -> Int {
        let validRange = 1...7
        if validRange.contains(weekday) {
            return weekday
        }

        return Calendar.current.component(.weekday, from: fallbackDate)
    }

    static func clampedSoundDuration(_ value: Int) -> Int {
        supportedSoundDurations.min {
            let lhsDistance = (abs($0 - value), $0)
            let rhsDistance = (abs($1 - value), $1)
            return lhsDistance < rhsDistance
        } ?? defaultSoundDurationSeconds
    }
}
