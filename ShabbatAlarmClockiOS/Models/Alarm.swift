import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var time: Date
    var label: String
    var isEnabled: Bool
    var repeatsDaily: Bool

    init(
        id: UUID = UUID(),
        time: Date,
        label: String = "Alarm",
        isEnabled: Bool = true,
        repeatsDaily: Bool = true
    ) {
        self.id = id
        self.time = time
        self.label = label.isEmpty ? "Alarm" : label
        self.isEnabled = isEnabled
        self.repeatsDaily = repeatsDaily
    }
}
