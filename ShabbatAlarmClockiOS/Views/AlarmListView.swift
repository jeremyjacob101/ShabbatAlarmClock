import SwiftUI
import StoreKit
import UIKit

struct AlarmListView: View {
    @Binding var selectedTheme: AppTheme
    @StateObject private var viewModel = AlarmListViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alarms.isEmpty {
                    ContentUnavailableView(
                        "No Alarms Yet",
                        systemImage: "alarm",
                        description: Text("Tap + to create your first alarm.")
                    )
                } else {
                    List {
                        ForEach(viewModel.alarms) { alarm in
                            AlarmRowView(
                                alarm: alarm,
                                themeColor: selectedTheme.color,
                                onEdit: {
                                    viewModel.editAlarm(alarm)
                                },
                                onToggle: { isOn in
                                    viewModel.toggleAlarm(id: alarm.id, isEnabled: isOn)
                                }
                            )
                        }
                        .onDelete(perform: viewModel.deleteAlarms)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            handleNotificationAction()
                        } label: {
                            Label(notificationActionTitle, systemImage: "bell.badge")
                        }

                        Menu {
                            ForEach(AppTheme.allCases) { theme in
                                Button {
                                    selectedTheme = theme
                                } label: {
                                    Label {
                                        Text(theme.displayName)
                                    } icon: {
                                        theme.menuSwatch(isSelected: selectedTheme == theme)
                                    }
                                }
                            }
                        } label: {
                            Label("App Color", systemImage: "paintpalette")
                        }

                        Divider()

                        Button {
                            leaveRating()
                        } label: {
                            Label("Leave a Rating", systemImage: "star")
                        }

                        Button {
                            contact()
                        } label: {
                            Label("Contact", systemImage: "envelope")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(isPresented: $viewModel.showAddAlarm) {
                AddAlarmView { time, label, weekday, sound, soundDurationSeconds, repeatsWeekly in
                    viewModel.addAlarm(
                        time: time,
                        label: label,
                        weekday: weekday,
                        sound: sound,
                        soundDurationSeconds: soundDurationSeconds,
                        repeatsWeekly: repeatsWeekly
                    )
                }
            }
            .sheet(item: $viewModel.editingAlarm) { alarm in
                AddAlarmView(alarm: alarm) { time, label, weekday, sound, soundDurationSeconds, repeatsWeekly in
                    viewModel.updateAlarm(
                        id: alarm.id,
                        time: time,
                        label: label,
                        weekday: weekday,
                        sound: sound,
                        soundDurationSeconds: soundDurationSeconds,
                        repeatsWeekly: repeatsWeekly
                    )
                }
            }
            .alert(item: $viewModel.activeAlert) { alert in
                switch alert.kind {
                case .notice(let message):
                    Alert(
                        title: Text("Notice"),
                        message: Text(message),
                        dismissButton: .default(Text("OK")) {
                            viewModel.dismissActiveAlert()
                        }
                    )
                case .notificationPermissionSettings:
                    Alert(
                        title: Text(AppAlertContent.notificationPermissionTitle),
                        message: Text(AppAlertContent.notificationPermissionMessage),
                        primaryButton: .default(Text("Open Settings")) {
                            viewModel.dismissActiveAlert()
                            openNotificationSettings()
                        },
                        secondaryButton: .cancel(Text("Not Now")) {
                            viewModel.dismissActiveAlert()
                        }
                    )
                case .ringerReminder:
                    Alert(
                        title: Text(AppAlertContent.ringerReminderTitle),
                        message: Text(AppAlertContent.ringerReminderMessage),
                        primaryButton: .default(Text("Don't Show Again")) {
                            viewModel.suppressSaveReminder()
                        },
                        secondaryButton: .default(Text("Okay")) {
                            viewModel.dismissActiveAlert()
                        }
                    )
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.onSceneBecameActive()
                }
            }
        }
    }

    private var notificationActionTitle: String {
        switch viewModel.notificationStatus {
        case .notDetermined:
            return "Enable Notifications"
        default:
            return "Notification Settings"
        }
    }

    private func handleNotificationAction() {
        if viewModel.notificationStatus == .notDetermined {
            viewModel.requestNotificationPermissionIfNeeded()
            return
        }

        openNotificationSettings()
    }

    private func openNotificationSettings() {
        if let notificationSettingsURL = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(notificationSettingsURL)
            return
        }

        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
            openURL(appSettingsURL)
        }
    }

    private func leaveRating() {
        if let reviewURL = AppStoreConfiguration.writeReviewURL {
            openURL(reviewURL)
        } else {
            requestReview()
        }
    }

    private func contact() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "jeremyjacob101@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[CONTACT] Shabbat Alarm Clock")
        ]

        if let emailURL = components.url {
            openURL(emailURL)
        }
    }
}

#Preview {
    AlarmListView(selectedTheme: .constant(.blue))
}
