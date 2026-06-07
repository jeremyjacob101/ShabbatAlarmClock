import Foundation

extension DateFormatter {
    static func alarmTime(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .none

        if Locale.autoupdatingCurrent.prefersTwelveHourClock {
            formatter.setLocalizedDateFormatFromTemplate("h:mm a")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        }

        return formatter
    }
}

extension Locale {
    var prefersTwelveHourClock: Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: self) ?? ""
        return format.contains("a")
    }
}
