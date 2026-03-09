import SwiftUI

struct ContentView: View {
    @AppStorage(AppTheme.storageKey) private var storedTheme = AppTheme.defaultTheme.rawValue

    private var selectedTheme: Binding<AppTheme> {
        Binding(
            get: { AppTheme.resolve(storedValue: storedTheme) },
            set: { storedTheme = $0.rawValue }
        )
    }

    var body: some View {
        AlarmListView(selectedTheme: selectedTheme)
    }
}

#Preview {
    ContentView()
}
