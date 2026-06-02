import SwiftUI
import StoreKit
import UIKit
import WebKit

struct AlarmListView: View {
    @EnvironmentObject private var localization: AppLocalizationController
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTheme: AppTheme
    @StateObject private var viewModel = AlarmListViewModel()
    @State private var pendingDeletedAlarmID: UUID?
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    private var strings: AppStrings {
        localization.strings
    }

    private var systemAlert: Binding<AlarmListViewModel.AlertItem?> {
        Binding {
            guard viewModel.activeAlert?.isRingerReminder != true else {
                return nil
            }

            return viewModel.activeAlert
        } set: { newValue in
            guard viewModel.activeAlert?.isRingerReminder != true else { return }
            viewModel.activeAlert = newValue
        }
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
                                        theme.menuSwatch(
                                            isSelected: selectedTheme == theme,
                                            colorScheme: colorScheme
                                        )
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
                AddAlarmView {
                    time,
                    label,
                    weekday,
                    sound,
                    soundDurationSeconds,
                    soundNoiseLevel,
                    repeatsWeekly,
                    autoSnoozeEnabled in
                    viewModel.addAlarm(
                        time: time,
                        label: label,
                        weekday: weekday,
                        sound: sound,
                        soundDurationSeconds: soundDurationSeconds,
                        soundNoiseLevel: soundNoiseLevel,
                        repeatsWeekly: repeatsWeekly,
                        autoSnoozeEnabled: autoSnoozeEnabled
                    )
                }
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .environment(\.calendar, localization.calendar)
                .environment(\.layoutDirection, localization.layoutDirection)
                .id("add-alarm-sheet-\(localization.language.rawValue)")
            }
            .sheet(item: $viewModel.editingAlarm, onDismiss: handleEditAlarmDismiss) { alarm in
                AddAlarmView(
                    alarm: alarm,
                    onDelete: {
                        pendingDeletedAlarmID = alarm.id
                    }
                ) {
                    time,
                    label,
                    weekday,
                    sound,
                    soundDurationSeconds,
                    soundNoiseLevel,
                    repeatsWeekly,
                    autoSnoozeEnabled in
                    viewModel.updateAlarm(
                        id: alarm.id,
                        time: time,
                        label: label,
                        weekday: weekday,
                        sound: sound,
                        soundDurationSeconds: soundDurationSeconds,
                        soundNoiseLevel: soundNoiseLevel,
                        repeatsWeekly: repeatsWeekly,
                        autoSnoozeEnabled: autoSnoozeEnabled
                    )
                }
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .environment(\.calendar, localization.calendar)
                .environment(\.layoutDirection, localization.layoutDirection)
                .id("edit-alarm-sheet-\(localization.language.rawValue)-\(alarm.id.uuidString)")
            }
            .alert(item: systemAlert) { alert in
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
                    Alert(title: Text(AppAlertContent.ringerReminderTitle))
                }
            }
            .overlay {
                if viewModel.activeAlert?.isRingerReminder == true {
                    RingerReminderDialog(
                        title: strings.ringerReminderTitle,
                        message: strings.ringerReminderBody,
                        secondaryTitle: strings.ringerReminderDoNotDisturbTitle,
                        secondaryBody: strings.ringerReminderDoNotDisturbMessage,
                        dismissButtonTitle: strings.dontShowAgain,
                        confirmButtonTitle: strings.okay,
                        dismissAction: {
                            viewModel.suppressSaveReminder()
                        },
                        confirmAction: {
                            viewModel.dismissActiveAlert()
                        }
                    )
                    .environment(\.layoutDirection, localization.layoutDirection)
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

private struct RingerReminderDialog: View {
    let title: String
    let message: String
    let secondaryTitle: String
    let secondaryBody: String
    let dismissButtonTitle: String?
    let confirmButtonTitle: String
    let dismissAction: (() -> Void)?
    let confirmAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                reminderTitle(title)

                reminderBody(message)
                    .padding(.bottom, 18)

                reminderTitle(secondaryTitle)

                reminderBody(secondaryBody)
                    .padding(.bottom, 8)

                AnimatedGIFView(assetName: "DNDDemo")
                    .frame(width: 285, height: 315)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 14)

                if let dismissButtonTitle, let dismissAction {
                    dialogButton(dismissButtonTitle, role: .destructive, action: dismissAction)
                }

                dialogButton(confirmButtonTitle, action: confirmAction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: 350, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func reminderTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func reminderBody(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dialogButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(role == .destructive ? Color(.systemRed) : Color.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct AnimatedGIFView: UIViewRepresentable {
    let assetName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        loadGIF(in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.loadedAssetName != assetName {
            loadGIF(in: webView, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func loadGIF(in webView: WKWebView, coordinator: Coordinator? = nil) {
        guard let data = NSDataAsset(name: assetName)?.data else { return }

        let base64GIF = data.base64EncodedString()
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            html, body {
              margin: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: transparent;
            }
            img {
              width: 100%;
              height: 100%;
              object-fit: contain;
              display: block;
            }
          </style>
        </head>
        <body>
          <img src="data:image/gif;base64,\(base64GIF)" alt="">
        </body>
        </html>
        """

        coordinator?.loadedAssetName = assetName
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator {
        var loadedAssetName: String?
    }
}

#Preview {
    AlarmListView(selectedTheme: .constant(.blue))
        .environmentObject(AppLocalizationController())
}
