import Foundation

enum AlarmSound: String, CaseIterable, Codable, Identifiable {
    case chimes
    case alarm
    case harp

    static let defaultSound: AlarmSound = .harp
    private static let soundDirectory = "AlarmSounds"
    static let allCases: [AlarmSound] = [.chimes, .alarm, .harp]

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .chimes:
            return "sound.name.chimes"
        case .alarm:
            return "sound.name.alarm"
        case .harp:
            return "sound.name.harp"
        }
    }

    func displayName(in language: AppLanguage = AppLanguagePreferenceStore.currentLanguage()) -> String {
        AppStrings(language: language).soundDisplayName(self)
    }

    func bundledFileURL(durationSeconds: Int) -> URL? {
        return bundleURL(resource: louderVariantResourceName(durationSeconds: durationSeconds))
    }

    func notificationSoundName(durationSeconds: Int) -> String? {
        let fileName = louderVariantFileName(durationSeconds: durationSeconds)
        return notificationSoundName(
            resource: louderVariantResourceName(durationSeconds: durationSeconds),
            fileName: fileName
        )
    }

    private func louderVariantResourceName(durationSeconds: Int) -> String {
        "\(rawValue)_\(Alarm.clampedSoundDuration(durationSeconds))s_louder"
    }

    private func louderVariantFileName(durationSeconds: Int) -> String {
        "\(louderVariantResourceName(durationSeconds: durationSeconds)).wav"
    }

    private func bundleURL(resource: String) -> URL? {
        Bundle.main.url(
            forResource: resource,
            withExtension: "wav",
            subdirectory: Self.soundDirectory
        ) ?? Bundle.main.url(
            forResource: resource,
            withExtension: "wav"
        )
    }

    private func notificationSoundName(resource: String, fileName: String) -> String? {
        if Bundle.main.url(
            forResource: resource,
            withExtension: "wav",
            subdirectory: Self.soundDirectory
        ) != nil {
            return "\(Self.soundDirectory)/\(fileName)"
        }

        if Bundle.main.url(
            forResource: resource,
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
