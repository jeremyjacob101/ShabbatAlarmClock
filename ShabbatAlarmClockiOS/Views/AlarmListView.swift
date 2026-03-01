import SwiftUI
import StoreKit
import UIKit

struct AlarmListView: View {
    @Binding var selectedTheme: AppTheme
    @StateObject private var viewModel = AlarmListViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

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
                            openRingerSettings()
                        } label: {
                            Label("Ringer Settings", systemImage: "bell.badge")
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
                AddAlarmView { time, label, weekday, sound, repeatsWeekly in
                    viewModel.addAlarm(
                        time: time,
                        label: label,
                        weekday: weekday,
                        sound: sound,
                        repeatsWeekly: repeatsWeekly
                    )
                }
            }
            .sheet(item: $viewModel.editingAlarm) { alarm in
                AddAlarmView(alarm: alarm) { time, label, weekday, sound, repeatsWeekly in
                    viewModel.updateAlarm(
                        id: alarm.id,
                        time: time,
                        label: label,
                        weekday: weekday,
                        sound: sound,
                        repeatsWeekly: repeatsWeekly
                    )
                }
            }
            .alert("Notice", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }

    private func openRingerSettings() {
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
        if let emailURL = URL(string: "mailto:jeremyjacob101@gmail.com") {
            openURL(emailURL)
        }
    }
}

#Preview {
    AlarmListView(selectedTheme: .constant(.blue))
}
