import SwiftUI

@main
struct ShabbatAlarmClockiOSApp: App {
    @AppStorage(AppTheme.storageKey) private var storedTheme = AppTheme.defaultTheme.rawValue
    @StateObject private var localization = AppLocalizationController()

    private var currentTheme: AppTheme {
        AppTheme.resolve(storedValue: storedTheme)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(currentTheme.color)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .environment(\.calendar, localization.calendar)
                .environment(\.layoutDirection, localization.layoutDirection)
        }
    }
}
