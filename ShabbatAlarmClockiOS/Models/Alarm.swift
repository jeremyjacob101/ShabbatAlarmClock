import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var time: Date
    var label: String
    var isEnabled: Bool
    var weekday: Int

    init(
        id: UUID = UUID(),
        time: Date,
        label: String = "Alarm",
        isEnabled: Bool = true,
        weekday: Int = Calendar.current.component(.weekday, from: Date())
    ) {
        self.id = id
        self.time = time
        self.label = label.isEmpty ? "Alarm" : label
        self.isEnabled = isEnabled
        self.weekday = Alarm.normalizedWeekday(weekday, fallbackDate: time)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case time
        case label
        case isEnabled
        case weekday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let time = try container.decode(Date.self, forKey: .time)
        let label = try container.decode(String.self, forKey: .label)
        let isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        let decodedWeekday = try container.decodeIfPresent(Int.self, forKey: .weekday)

        self.init(
            id: id,
            time: time,
            label: label,
            isEnabled: isEnabled,
            weekday: decodedWeekday ?? Calendar.current.component(.weekday, from: time)
        )
    }

    private static func normalizedWeekday(_ weekday: Int, fallbackDate: Date) -> Int {
        let validRange = 1...7
        if validRange.contains(weekday) {
            return weekday
        }

        return Calendar.current.component(.weekday, from: fallbackDate)
    }
}
