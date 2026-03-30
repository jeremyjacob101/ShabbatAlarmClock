import Foundation

enum AlarmNoiseLevel: String, CaseIterable, Codable, Identifiable {
    case soft
    case loud

    nonisolated static let defaultLevel: AlarmNoiseLevel = .soft

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .soft:
            return "sound.noise_level.soft"
        case .loud:
            return "sound.noise_level.loud"
        }
    }

    var fileSuffixCandidates: [String] {
        switch self {
        case .soft:
            return ["louder"]
        case .loud:
            return ["super_loud", "super_load", "louder"]
        }
    }

    func displayName(in language: AppLanguage = AppLanguagePreferenceStore.currentLanguage()) -> String {
        AppStrings(language: language).noiseLevelDisplayName(self)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case AlarmNoiseLevel.soft.rawValue:
            self = .soft
        case AlarmNoiseLevel.loud.rawValue, "super_loud", "super_load":
            self = .loud
        default:
            self = .defaultLevel
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
