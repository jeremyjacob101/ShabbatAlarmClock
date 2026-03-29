import Combine
import Foundation
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case hebrew = "he"

    var id: String { rawValue }

    var locale: Locale {
        if let regionCode = Self.currentRegionCode {
            return Locale(identifier: "\(rawValue)-\(regionCode)")
        }

        return Locale(identifier: rawValue)
    }

    var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        return calendar
    }

    var layoutDirection: LayoutDirection {
        self == .hebrew ? .rightToLeft : .leftToRight
    }

    var semanticContentAttribute: UISemanticContentAttribute {
        self == .hebrew ? .forceRightToLeft : .forceLeftToRight
    }

    fileprivate var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }

    static func from(locale: Locale) -> AppLanguage {
        if isHebrewIdentifier(locale.identifier) {
            return .hebrew
        }

        return .english
    }

    static func systemPreferred(
        bundle: Bundle = .main,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        for identifier in bundle.preferredLocalizations + preferredLanguages {
            if isHebrewIdentifier(identifier) {
                return .hebrew
            }

            if isEnglishIdentifier(identifier) {
                return .english
            }
        }

        return .english
    }

    private static var currentRegionCode: String? {
        let identifier = Locale.autoupdatingCurrent.identifier
            .replacingOccurrences(of: "_", with: "-")
        let parts = identifier.split(separator: "-")

        return parts.reversed().first(where: { part in
            part.count == 2 || (part.count == 3 && part.allSatisfy(\.isNumber))
        }).map(String.init)
    }

    private static func baseLanguageCode(for identifier: String) -> String {
        identifier
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init) ?? ""
    }

    private static func isHebrewIdentifier(_ identifier: String) -> Bool {
        let languageCode = baseLanguageCode(for: identifier)
        return languageCode == "he" || languageCode == "iw"
    }

    private static func isEnglishIdentifier(_ identifier: String) -> Bool {
        baseLanguageCode(for: identifier) == "en"
    }
}

enum AppLanguageSelection: String, CaseIterable, Identifiable {
    case system
    case english
    case hebrew

    static let storageKey = "appLanguageSelection"

    var id: String { rawValue }

    var resolvedLanguage: AppLanguage {
        switch self {
        case .system:
            return .systemPreferred()
        case .english:
            return .english
        case .hebrew:
            return .hebrew
        }
    }

    static func resolve(storedValue: String?) -> AppLanguageSelection {
        AppLanguageSelection(rawValue: storedValue ?? "") ?? .system
    }
}

enum AppLanguagePreferenceStore {
    static func load(defaults: UserDefaults = .standard) -> AppLanguageSelection {
        AppLanguageSelection.resolve(
            storedValue: defaults.string(forKey: AppLanguageSelection.storageKey)
        )
    }

    static func save(_ selection: AppLanguageSelection, defaults: UserDefaults = .standard) {
        defaults.set(selection.rawValue, forKey: AppLanguageSelection.storageKey)
    }

    static func currentLanguage(defaults: UserDefaults = .standard) -> AppLanguage {
        load(defaults: defaults).resolvedLanguage
    }
}

@MainActor
final class AppLocalizationController: ObservableObject {
    @Published private(set) var selection: AppLanguageSelection
    @Published private(set) var language: AppLanguage

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let selection = AppLanguagePreferenceStore.load(defaults: defaults)
        self.selection = selection
        language = selection.resolvedLanguage
    }

    var locale: Locale { language.locale }
    var calendar: Calendar { language.calendar }
    var layoutDirection: LayoutDirection { language.layoutDirection }
    var strings: AppStrings { AppStrings(language: language) }

    func updateSelection(_ newSelection: AppLanguageSelection) {
        guard newSelection != selection || newSelection.resolvedLanguage != language else { return }

        AppLanguagePreferenceStore.save(newSelection, defaults: defaults)
        selection = newSelection
        language = newSelection.resolvedLanguage
    }

    func refreshSystemLanguageIfNeeded() {
        let refreshedLanguage = selection.resolvedLanguage
        guard refreshedLanguage != language else { return }
        language = refreshedLanguage
    }
}

struct AppStrings {
    let language: AppLanguage

    static var current: AppStrings {
        AppStrings(language: AppLanguagePreferenceStore.currentLanguage())
    }

    var defaultAlarmLabel: String { localized("alarm.default_label") }
    var alarmsTitle: String { localized("alarms.title") }
    var alarmsEmptyTitle: String { localized("alarms.empty.title") }
    var alarmsEmptyMessage: String { localized("alarms.empty.message") }
    var settingsTitle: String { localized("settings.title") }
    var enableNotifications: String { localized("settings.notifications.enable") }
    var notificationSettings: String { localized("settings.notifications.manage") }
    var appColor: String { localized("settings.app_color") }
    var languageMenuTitle: String { localized("settings.language") }
    var leaveRating: String { localized("settings.leave_rating") }
    var contact: String { localized("settings.contact") }
    var addAlarmAccessibilityLabel: String { localized("alarm.add") }
    var deleteAlarm: String { localized("alarm.delete") }
    var noticeTitle: String { localized("notice.title") }
    var openSettings: String { localized("button.open_settings") }
    var allow: String { localized("button.allow") }
    var notNow: String { localized("button.not_now") }
    var cancel: String { localized("button.cancel") }
    var save: String { localized("button.save") }
    var ok: String { localized("button.ok") }
    var okay: String { localized("button.okay") }
    var dontShowAgain: String { localized("button.dont_show_again") }
    var scheduleSection: String { localized("schedule.section") }
    var dayOfWeek: String { localized("schedule.day_of_week") }
    var alarmTime: String { localized("schedule.time") }
    var repeatSection: String { localized("repeat.section") }
    var repeatEveryWeek: String { localized("repeat.every_week") }
    var autoSnoozeForFiveMinutes: String { localized("repeat.auto_snooze_five_minutes") }
    var soundSection: String { localized("sound.section") }
    var alarmSound: String { localized("sound.alarm") }
    var alarmSoundLength: String { localized("sound.length") }
    var testSound: String { localized("sound.test") }
    var stopSound: String { localized("sound.stop") }
    var alarmSoundLengthAccessibilityLabel: String { localized("sound.accessibility.length") }
    var labelSection: String { localized("label.section") }
    var editAlarmTitle: String { localized("alarm.edit.title") }
    var newAlarmTitle: String { localized("alarm.new.title") }
    var weekdayUnknown: String { localized("weekday.unknown") }
    var selectedDayFallback: String { localized("weekday.selected_fallback") }
    var notificationPermissionTitle: String { localized("alerts.notifications.title") }
    var notificationPermissionMessage: String { localized("alerts.notifications.message") }
    var ringerReminderTitle: String { localized("alerts.ringer.title") }
    var ringerReminderMessage: String { localized("alerts.ringer.message") }
    var notificationPermissionRequestFailed: String {
        localized("alerts.notifications.request_failed")
    }
    var notificationsNotAllowed: String { localized("alerts.notifications.not_allowed") }
    var notificationsSavedButDisabled: String {
        localized("alerts.notifications.saved_but_disabled")
    }
    var notificationsSavedButRequestFailed: String {
        localized("alerts.notifications.saved_but_request_failed")
    }
    var notificationsDisabledForEnable: String {
        localized("alerts.notifications.disabled_for_enable")
    }
    var notificationsEnableFailed: String { localized("alerts.notifications.enable_failed") }
    var notificationSchedulingFailed: String {
        localized("alerts.notifications.schedule_failed")
    }
    var notificationNotAuthorizedError: String {
        localized("errors.notifications.not_authorized")
    }
    var invalidTriggerDateError: String { localized("errors.notifications.invalid_trigger_date") }
    var contactEmailSubject: String { localized("contact.email.subject") }

    func languageSelectionTitle(_ selection: AppLanguageSelection) -> String {
        switch selection {
        case .system:
            return localized("settings.language.option.system")
        case .english:
            return localized("settings.language.option.english")
        case .hebrew:
            return localized("settings.language.option.hebrew")
        }
    }

    func themeDisplayName(_ theme: AppTheme) -> String {
        localized(theme.localizationKey)
    }

    func soundDisplayName(_ sound: AlarmSound) -> String {
        localized(sound.localizationKey)
    }

    func weekdayName(for weekday: Int) -> String {
        let symbols = language.calendar.weekdaySymbols
        guard (1...symbols.count).contains(weekday) else {
            return weekdayUnknown
        }

        return symbols[weekday - 1]
    }

    func displayedAlarmLabel(_ storedLabel: String) -> String {
        AlarmLabelLocalization.displayLabel(storedLabel, language: language)
    }

    func editableAlarmLabel(_ storedLabel: String?) -> String {
        AlarmLabelLocalization.editableLabel(storedLabel, language: language)
    }

    func normalizedAlarmLabelInput(_ input: String) -> String {
        AlarmLabelLocalization.normalizedInputLabel(input, language: language)
    }

    func shortDuration(_ seconds: Int) -> String {
        formatted("duration.short", seconds)
    }

    func displayedAlarmTime(_ time: Date) -> String {
        DateFormatter.alarmTime(locale: language.locale).string(from: time)
    }

    func accessibilityDuration(_ seconds: Int) -> String {
        formatted("duration.accessibility", seconds)
    }

    func notificationBody(weekday: String, time: Date) -> String {
        formatted(
            "notification.body",
            weekday,
            DateFormatter.alarmTime(locale: language.locale).string(from: time)
        )
    }

    private func localized(_ key: String) -> String {
        language.bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    private func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: language.locale, arguments: arguments)
    }
}

enum AlarmLabelLocalization {
    static func isDefaultLabel(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        return AppLanguage.allCases.contains { language in
            AppStrings(language: language).defaultAlarmLabel == trimmed
        }
    }

    static func displayLabel(_ storedLabel: String, language: AppLanguage) -> String {
        let trimmed = storedLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isDefaultLabel(trimmed) else {
            return AppStrings(language: language).defaultAlarmLabel
        }

        return trimmed
    }

    static func editableLabel(_ storedLabel: String?, language: AppLanguage) -> String {
        let strings = AppStrings(language: language)
        guard let storedLabel else { return strings.defaultAlarmLabel }

        return displayLabel(storedLabel, language: language)
    }

    static func normalizedInputLabel(_ input: String, language: AppLanguage) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AppStrings(language: language).defaultAlarmLabel
        }

        return trimmed
    }
}
