import SwiftUI

@main
struct ShabbatAlarmClockiOSApp: App {
    @AppStorage(AppTheme.storageKey) private var storedTheme = AppTheme.defaultTheme.rawValue

    private var currentTheme: AppTheme {
        AppTheme.resolve(storedValue: storedTheme)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(currentTheme.color)
        }
    }
}
