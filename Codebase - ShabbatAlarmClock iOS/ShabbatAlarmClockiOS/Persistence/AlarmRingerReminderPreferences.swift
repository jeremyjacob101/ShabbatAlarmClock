import Foundation

final class AlarmRingerReminderPreferences {
    private enum Keys {
        static let suppressSaveReminder = "alarmRingerReminder.suppressSaveReminder.v5"
        static let suppressTestSoundReminder = "alarmRingerReminder.suppressTestSoundReminder.v5"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldShowSaveReminder: Bool {
        defaults.object(forKey: Keys.suppressSaveReminder) as? Bool != true
    }

    func suppressSaveReminder() {
        defaults.set(true, forKey: Keys.suppressSaveReminder)
    }

    var shouldShowTestSoundReminder: Bool {
        defaults.object(forKey: Keys.suppressTestSoundReminder) as? Bool != true
    }

    func suppressTestSoundReminder() {
        defaults.set(true, forKey: Keys.suppressTestSoundReminder)
    }
}
