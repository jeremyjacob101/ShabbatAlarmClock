import Foundation

final class AlarmRepository {
    private let defaults: UserDefaults
    private let storageKey = "saved_alarms_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [Alarm] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }

        do {
            return try JSONDecoder().decode([Alarm].self, from: data)
        } catch {
            print("Failed to decode alarms: \(error)")
            return []
        }
    }

    func save(_ alarms: [Alarm]) {
        do {
            let data = try JSONEncoder().encode(alarms)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode alarms: \(error)")
        }
    }
}
