import Foundation

enum AlarmSound: String, CaseIterable, Codable, Identifiable {
    case alarm
    case chimes
    case soft
    case beacon
    case bell

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alarm:
            return "Alarm"
        case .chimes:
            return "Chimes"
        case .soft:
            return "Soft"
        case .beacon:
            return "Beacon"
        case .bell:
            return "Bell"
        }
    }

    var resourceFileName: String {
        "\(rawValue).wav"
    }
}
