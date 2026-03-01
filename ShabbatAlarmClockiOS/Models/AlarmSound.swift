import Foundation

enum AlarmSound: String, CaseIterable, Codable, Identifiable {
    case chimes
    case alarm
    case harp

    static let defaultSound: AlarmSound = .chimes
    private static let soundDirectory = "AlarmSounds"
    static let allCases: [AlarmSound] = [.chimes, .alarm, .harp]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chimes:
            return "Chimes"
        case .alarm:
            return "Alarm"
        case .harp:
            return "Harp"
        }
    }

    var fileName: String {
        "\(rawValue).wav"
    }

    func bundledFileURL() -> URL? {
        Bundle.main.url(
            forResource: rawValue,
            withExtension: "wav",
            subdirectory: Self.soundDirectory
        ) ?? Bundle.main.url(
            forResource: rawValue,
            withExtension: "wav"
        )
    }

    func notificationSoundName() -> String? {
        if Bundle.main.url(
            forResource: rawValue,
            withExtension: "wav",
            subdirectory: Self.soundDirectory
        ) != nil {
            return "\(Self.soundDirectory)/\(fileName)"
        }

        if Bundle.main.url(
            forResource: rawValue,
            withExtension: "wav"
        ) != nil {
            return fileName
        }

        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case AlarmSound.chimes.rawValue:
            self = .chimes
        case "bells", "woods", AlarmSound.alarm.rawValue:
            self = .alarm
        case AlarmSound.harp.rawValue:
            self = .harp
        default:
            self = .defaultSound
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
