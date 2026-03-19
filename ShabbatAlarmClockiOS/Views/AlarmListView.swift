import SwiftUI
import StoreKit
import UIKit

struct AlarmListView: View {
    @EnvironmentObject private var localization: AppLocalizationController
    @Binding var selectedTheme: AppTheme
    @StateObject private var viewModel = AlarmListViewModel()
    @State private var pendingDeletedAlarmID: UUID?
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    private var strings: AppStrings {
        localization.strings
    }

    private var settingsPlacement: ToolbarItemPlacement {
        localization.layoutDirection == .rightToLeft ? .topBarTrailing : .topBarLeading
    }

    private var addPlacement: ToolbarItemPlacement {
        localization.layoutDirection == .rightToLeft ? .topBarLeading : .topBarTrailing
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alarms.isEmpty {
                    ContentUnavailableView(
                        strings.alarmsEmptyTitle,
                        systemImage: "alarm",
                        description: Text(strings.alarmsEmptyMessage)
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
                    .environment(\.layoutDirection, localization.layoutDirection)
                    .id("alarm-list-\(localization.language.rawValue)")
                }
            }
            .navigationTitle(strings.alarmsTitle)
            .toolbar {
                ToolbarItem(placement: settingsPlacement) {
                    Menu {
                        Button {
                            handleNotificationAction()
                        } label: {
                            Label(notificationActionTitle, systemImage: "bell.badge")
                        }

                        Divider()

                        Menu {
                            ForEach(AppLanguageSelection.allCases) { selection in
                                Button {
                                    localization.updateSelection(selection)
                                } label: {
                                    HStack {
                                        Text(strings.languageSelectionTitle(selection))
                                        Spacer()
                                        if localization.selection == selection {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label(strings.languageMenuTitle, systemImage: "globe")
                        }

                        Menu {
                            ForEach(AppTheme.allCases) { theme in
                                Button {
                                    selectedTheme = theme
                                } label: {
                                    Label {
                                        Text(theme.displayName(in: localization.language))
                                    } icon: {
                                        theme.menuSwatch(isSelected: selectedTheme == theme)
                                    }
                                }
                            }
                        } label: {
                            Label(strings.appColor, systemImage: "paintpalette")
                        }

                        Divider()

                        Button {
                            leaveRating()
                        } label: {
                            Label(strings.leaveRating, systemImage: "star")
                        }

                        Button {
                            contact()
                        } label: {
                            Label(strings.contact, systemImage: "envelope")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(strings.settingsTitle)
                }

                ToolbarItem(placement: addPlacement) {
                    Button {
                        viewModel.showAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(strings.addAlarmAccessibilityLabel)
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
            .sheet(item: $viewModel.editingAlarm, onDismiss: handleEditAlarmDismiss) { alarm in
                AddAlarmView(
                    alarm: alarm,
                    onDelete: {
                        pendingDeletedAlarmID = alarm.id
                    }
                ) { time, label, weekday, sound, soundDurationSeconds, repeatsWeekly in
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
                        title: Text(strings.noticeTitle),
                        message: Text(message),
                        dismissButton: .default(Text(strings.ok)) {
                            viewModel.dismissActiveAlert()
                        }
                    )
                case .notificationPermissionSettings:
                    Alert(
                        title: Text(AppAlertContent.notificationPermissionTitle),
                        message: Text(AppAlertContent.notificationPermissionMessage),
                        primaryButton: .default(Text(strings.openSettings)) {
                            viewModel.dismissActiveAlert()
                            openNotificationSettings()
                        },
                        secondaryButton: .cancel(Text(strings.notNow)) {
                            viewModel.dismissActiveAlert()
                        }
                    )
                case .ringerReminder:
                    Alert(
                        title: Text(AppAlertContent.ringerReminderTitle),
                        message: Text(AppAlertContent.ringerReminderMessage),
                        primaryButton: .default(Text(strings.dontShowAgain)) {
                            viewModel.suppressSaveReminder()
                        },
                        secondaryButton: .default(Text(strings.okay)) {
                            viewModel.dismissActiveAlert()
                        }
                    )
                }
            }
            .onAppear {
                localization.refreshSystemLanguageIfNeeded()
                viewModel.onAppear()
            }
            .onChange(of: localization.language) { _, _ in
                viewModel.handleAppLanguageChange()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    localization.refreshSystemLanguageIfNeeded()
                    viewModel.onSceneBecameActive()
                }
            }
        }
    }

    private var notificationActionTitle: String {
        switch viewModel.notificationStatus {
        case .notDetermined:
            return strings.enableNotifications
        default:
            return strings.notificationSettings
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
            URLQueryItem(name: "subject", value: strings.contactEmailSubject)
        ]

        if let emailURL = components.url {
            openURL(emailURL)
        }
    }

    private func handleEditAlarmDismiss() {
        guard let pendingDeletedAlarmID else { return }
        self.pendingDeletedAlarmID = nil
        viewModel.deleteAlarm(id: pendingDeletedAlarmID)
    }
}

#Preview {
    AlarmListView(selectedTheme: .constant(.blue))
        .environmentObject(AppLocalizationController())
}
