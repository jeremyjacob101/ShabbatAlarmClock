import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var time: Date
    var label: String
    var sound: AlarmSound
    var isEnabled: Bool
    var repeatsDaily: Bool

    init(
        id: UUID = UUID(),
        time: Date,
        label: String = "Alarm",
        sound: AlarmSound = .alarm,
        isEnabled: Bool = true,
        repeatsDaily: Bool = true
    ) {
        self.id = id
        self.time = time
        self.label = label.isEmpty ? "Alarm" : label
        self.sound = sound
        self.isEnabled = isEnabled
        self.repeatsDaily = repeatsDaily
    }

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case label
        case sound
        case isEnabled
        case repeatsDaily
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        time = try container.decode(Date.self, forKey: .time)
        label = try container.decode(String.self, forKey: .label)
        sound = try container.decodeIfPresent(AlarmSound.self, forKey: .sound) ?? .alarm
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        repeatsDaily = try container.decode(Bool.self, forKey: .repeatsDaily)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(time, forKey: .time)
        try container.encode(label, forKey: .label)
        try container.encode(sound, forKey: .sound)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(repeatsDaily, forKey: .repeatsDaily)
    }
}
