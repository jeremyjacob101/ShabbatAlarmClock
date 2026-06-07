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

    func bundledFileURL(
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel = .defaultLevel
    ) -> URL? {
        guard let resource = resolvedResourceName(
            durationSeconds: durationSeconds,
            noiseLevel: noiseLevel
        ) else {
            return nil
        }

        return bundleURL(resource: resource)
    }

    func notificationSoundName(
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel = .defaultLevel
    ) -> String? {
        guard let resource = resolvedResourceName(
            durationSeconds: durationSeconds,
            noiseLevel: noiseLevel
        ) else {
            return nil
        }

        let fileName = "\(resource).wav"
        return notificationSoundName(
            resource: resource,
            fileName: fileName
        )
    }

    private func resolvedResourceName(
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel
    ) -> String? {
        resourceNameCandidates(durationSeconds: durationSeconds, noiseLevel: noiseLevel)
            .first(where: { bundleURL(resource: $0) != nil })
    }

    private func resourceNameCandidates(
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel
    ) -> [String] {
        let clampedDurationSeconds = Alarm.clampedSoundDuration(durationSeconds)
        return noiseLevel.fileSuffixCandidates.map { suffix in
            "\(rawValue)_\(clampedDurationSeconds)s_\(suffix)"
        }
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
