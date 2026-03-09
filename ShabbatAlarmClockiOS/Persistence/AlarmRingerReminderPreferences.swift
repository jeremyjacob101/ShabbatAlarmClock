import Foundation

final class AlarmRingerReminderPreferences {
    private enum Keys {
        static let suppressSaveReminder = "alarmRingerReminder.suppressSaveReminder"
        static let lastSaveReminderShownAt = "alarmRingerReminder.lastSaveReminderShownAt"
        static let lastTestSoundReminderShownAt = "alarmRingerReminder.lastTestSoundReminderShownAt"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var shouldShowSaveReminder: Bool {
        defaults.object(forKey: Keys.suppressSaveReminder) as? Bool != true
            && shouldShowSaveReminderToday()
    }

    func suppressSaveReminder() {
        defaults.set(true, forKey: Keys.suppressSaveReminder)
    }

    func shouldShowSaveReminderToday(on date: Date = Date()) -> Bool {
        guard let lastShownAt = defaults.object(forKey: Keys.lastSaveReminderShownAt) as? Date else {
            return true
        }

        return !calendar.isDate(lastShownAt, inSameDayAs: date)
    }

    func markSaveReminderShown(on date: Date = Date()) {
        defaults.set(date, forKey: Keys.lastSaveReminderShownAt)
    }

    func shouldShowTestSoundReminder(on date: Date = Date()) -> Bool {
        guard let lastShownAt = defaults.object(forKey: Keys.lastTestSoundReminderShownAt) as? Date else {
            return true
        }

        return !calendar.isDate(lastShownAt, inSameDayAs: date)
    }

    func markTestSoundReminderShown(on date: Date = Date()) {
        defaults.set(date, forKey: Keys.lastTestSoundReminderShownAt)
    }
}
