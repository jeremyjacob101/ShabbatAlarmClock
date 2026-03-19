import SwiftUI
import UIKit
import UserNotifications

struct AddAlarmView: View {
    private enum AlertItem: String, Identifiable {
        case notificationPermissionIntro
        case notificationPermissionSettings
        case ringerReminder

        var id: String { rawValue }
    }

    @EnvironmentObject private var localization: AppLocalizationController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLabelFieldFocused = false

    private static func defaultAlarmTime() -> Date {
        Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    @State private var time = Self.defaultAlarmTime()
    @State private var label = AppStrings.current.defaultAlarmLabel
    @State private var weekday = 7
    @State private var sound: AlarmSound = .defaultSound
    @State private var soundDurationSeconds = Alarm.defaultSoundDurationSeconds
    @State private var repeatsWeekly = false
    @State private var isTestingSound = false
    @State private var activeAlert: AlertItem?

    private let isEditing: Bool
    private let notificationService = NotificationService()
    private let reminderPreferences = AlarmRingerReminderPreferences()
    private let soundPreviewPlayer = AlarmSoundPreviewPlayer.shared

    let onDelete: (() -> Void)?
    let onSave: (Date, String, Int, AlarmSound, Int, Bool) -> Void

    init(
        alarm: Alarm? = nil,
        onDelete: (() -> Void)? = nil,
        onSave: @escaping (Date, String, Int, AlarmSound, Int, Bool) -> Void
    ) {
        let strings = AppStrings.current
        let initialAlarm = alarm ?? Alarm(
            time: Self.defaultAlarmTime(),
            label: strings.defaultAlarmLabel,
            weekday: 7,
            sound: .defaultSound,
            repeatsWeekly: false
        )

        _time = State(initialValue: initialAlarm.time)
        _label = State(initialValue: strings.editableAlarmLabel(initialAlarm.label))
        _weekday = State(initialValue: initialAlarm.weekday)
        _sound = State(initialValue: initialAlarm.sound)
        _soundDurationSeconds = State(initialValue: initialAlarm.soundDurationSeconds)
        _repeatsWeekly = State(initialValue: initialAlarm.repeatsWeekly)
        isEditing = alarm != nil
        self.onDelete = onDelete
        self.onSave = onSave
    }

    private var strings: AppStrings {
        localization.strings
    }

    private var isRightToLeft: Bool {
        localization.layoutDirection == .rightToLeft
    }

    private var cancelPlacement: ToolbarItemPlacement {
        isRightToLeft ? .topBarTrailing : .topBarLeading
    }

    private var savePlacement: ToolbarItemPlacement {
        isRightToLeft ? .topBarLeading : .topBarTrailing
    }

    private var fixedScreenOrderLayoutDirection: LayoutDirection {
        .leftToRight
    }

    private var showsDeleteButton: Bool {
        isEditing && onDelete != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    directionalPickerRow(title: strings.dayOfWeek, selection: $weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(strings.weekdayName(for: day)).tag(day)
                        }
                    }

                    DatePicker(
                        strings.alarmTime,
                        selection: $time,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .environment(\.layoutDirection, .leftToRight)
                } header: {
                    sectionHeader(strings.scheduleSection)
                }

                Section {
                    directionalToggleRow(
                        title: strings.repeatEveryWeek,
                        isOn: $repeatsWeekly
                    )
                } header: {
                    sectionHeader(strings.repeatSection)
                }

                Section {
                    directionalPickerRow(title: strings.alarmSound, selection: $sound) {
                        ForEach(AlarmSound.allCases) { sound in
                            Text(sound.displayName(in: localization.language)).tag(sound)
                        }
                    }

                    VStack(alignment: isRightToLeft ? .trailing : .leading, spacing: 8) {
                        directionalValueRow(
                            title: strings.alarmSoundLength,
                            valueText: strings.shortDuration(soundDurationSeconds)
                        )

                        DiscreteStepSlider(
                            value: $soundDurationSeconds,
                            steps: Alarm.supportedSoundDurations,
                            accessibilityLabel: strings.alarmSoundLengthAccessibilityLabel
                        )
                    }
                } header: {
                    directionalHeaderWithAction(
                        title: strings.soundSection,
                        actionTitle: isTestingSound ? strings.stopSound : strings.testSound,
                        systemImage: isTestingSound ? "hat.widebrim.fill" : "play.fill",
                        action: handleTestSoundButtonTap
                    )
                    .textCase(nil)
                }

                Section {
                    labelTextField
                } header: {
                    sectionHeader(strings.labelSection)
                }

                if showsDeleteButton {
                    Section {
                        Button(action: handleDeleteButtonTap) {
                            Text(strings.deleteAlarm)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(DeleteAlarmButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .environment(\.layoutDirection, localization.layoutDirection)
            .id("add-alarm-form-\(localization.language.rawValue)")
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(
                KeyboardDismissTapInstaller {
                    dismissKeyboard()
                }
            )
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .notificationPermissionIntro:
                    Alert(
                        title: Text(AppAlertContent.notificationPermissionTitle),
                        message: Text(AppAlertContent.notificationPermissionMessage),
                        primaryButton: .default(Text(strings.allow)) {
                            requestNotificationPermissionForTestSound()
                        },
                        secondaryButton: .cancel(Text(strings.notNow))
                    )
                case .notificationPermissionSettings:
                    Alert(
                        title: Text(AppAlertContent.notificationPermissionTitle),
                        message: Text(AppAlertContent.notificationPermissionMessage),
                        primaryButton: .default(Text(strings.openSettings)) {
                            openNotificationSettings()
                        },
                        secondaryButton: .cancel(Text(strings.notNow))
                    )
                case .ringerReminder:
                    Alert(
                        title: Text(AppAlertContent.ringerReminderTitle),
                        message: Text(AppAlertContent.ringerReminderMessage),
                        dismissButton: .default(Text(strings.ok)) {
                            startSoundPreview()
                        }
                    )
                }
            }
            .navigationTitle(isEditing ? strings.editAlarmTitle : strings.newAlarmTitle)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, localization.layoutDirection)
            .id("add-alarm-stack-\(localization.language.rawValue)")
            .toolbar {
                ToolbarItem(placement: cancelPlacement) {
                    Button(strings.cancel) {
                        stopSoundPreview()
                        dismiss()
                    }
                }

                ToolbarItem(placement: savePlacement) {
                    Button(strings.save) {
                        stopSoundPreview()
                        onSave(
                            time,
                            strings.normalizedAlarmLabelInput(label),
                            weekday,
                            sound,
                            soundDurationSeconds,
                            repeatsWeekly
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: sound) { _, _ in
                dismissKeyboard()
                if isTestingSound {
                    stopSoundPreview()
                }
            }
            .onChange(of: soundDurationSeconds) { _, _ in
                dismissKeyboard()
                if isTestingSound {
                    stopSoundPreview()
                }
            }
            .onChange(of: repeatsWeekly) { _, _ in
                dismissKeyboard()
            }
            .onChange(of: weekday) { _, _ in
                dismissKeyboard()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    dismissKeyboard()
                    stopSoundPreview()
                }
            }
            .onDisappear {
                dismissKeyboard()
                stopSoundPreview()
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        fixedScreenOrderRow {
            if isRightToLeft {
                Spacer()
                Text(title)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        }
        .textCase(nil)
    }

    @ViewBuilder
    private func directionalHeaderWithAction(
        title: String,
        actionTitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        fixedScreenOrderRow {
            if isRightToLeft {
                actionButton(title: actionTitle, systemImage: systemImage, action: action)
                Spacer()
                Text(title)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
                actionButton(title: actionTitle, systemImage: systemImage, action: action)
            }
        }
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.footnote.weight(.semibold))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func directionalValueRow(title: String, valueText: String) -> some View {
        fixedScreenOrderRow {
            if isRightToLeft {
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(title)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func directionalToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        fixedScreenOrderRow {
            if isRightToLeft {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .accessibilityLabel(title)
                Spacer()
                Text(title)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .accessibilityLabel(title)
            }
        }
    }

    @ViewBuilder
    private func directionalPickerRow<SelectionValue: Hashable, Content: View>(
        title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        fixedScreenOrderRow {
            if isRightToLeft {
                Picker(title, selection: selection) {
                    content()
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .environment(\.layoutDirection, localization.layoutDirection)

                Spacer()

                Text(title)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
                Picker(title, selection: selection) {
                    content()
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .environment(\.layoutDirection, localization.layoutDirection)
            }
        }
    }

    @ViewBuilder
    private func fixedScreenOrderRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            content()
        }
        .frame(maxWidth: .infinity)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
        .environment(\.layoutDirection, fixedScreenOrderLayoutDirection)
    }

    private var labelTextField: some View {
        DirectionalTextField(
            text: $label,
            isFocused: $isLabelFieldFocused,
            placeholder: strings.defaultAlarmLabel,
            isRightToLeft: isRightToLeft,
            onSubmit: dismissKeyboard
        )
        .frame(maxWidth: .infinity, minHeight: 22, alignment: isRightToLeft ? .trailing : .leading)
    }

    private func handleDeleteButtonTap() {
        dismissKeyboard()
        stopSoundPreview()
        onDelete?()
        dismiss()
    }

    private func handleTestSoundButtonTap() {
        dismissKeyboard()

        if isTestingSound {
            stopSoundPreview()
            return
        }

        Task { @MainActor in
            let status = await notificationService.authorizationStatus()

            if isNotificationAuthorized(status) {
                presentRingerReminderIfNeeded()
                return
            }

            activeAlert = status == .notDetermined
                ? .notificationPermissionIntro
                : .notificationPermissionSettings
        }
    }

    private func requestNotificationPermissionForTestSound() {
        Task { @MainActor in
            do {
                let granted = try await notificationService.requestAuthorization()
                let status = await notificationService.authorizationStatus()

                guard granted, isNotificationAuthorized(status) else {
                    activeAlert = .notificationPermissionSettings
                    return
                }

                presentRingerReminderIfNeeded()
            } catch {
                activeAlert = .notificationPermissionSettings
            }
        }
    }

    private func presentRingerReminderIfNeeded() {
        if !reminderPreferences.shouldShowTestSoundReminder() {
            startSoundPreview()
            return
        }

        reminderPreferences.markTestSoundReminderShown()
        activeAlert = .ringerReminder
    }

    private func startSoundPreview() {
        isTestingSound = true
        soundPreviewPlayer.play(sound, durationSeconds: soundDurationSeconds) {
            isTestingSound = false
        }
    }

    private func stopSoundPreview() {
        guard isTestingSound else { return }
        soundPreviewPlayer.stop()
        isTestingSound = false
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

    private func isNotificationAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func dismissKeyboard() {
        isLabelFieldFocused = false
    }
}

private struct DeleteAlarmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color(uiColor: .systemRed))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        Color(
                            uiColor: configuration.isPressed
                                ? .secondarySystemFill
                                : .secondarySystemBackground
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(configuration.isPressed ? 0.10 : 0.04), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 1.015 : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct DirectionalTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let placeholder: String
    let isRightToLeft: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.returnKeyType = .done
        textField.clearButtonMode = .never
        textField.adjustsFontForContentSizeCategory = true
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        applyConfiguration(to: textField)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }

        applyConfiguration(to: uiView)

        if isFocused {
            if uiView.window != nil, !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    private func applyConfiguration(to textField: UITextField) {
        textField.placeholder = placeholder
        textField.textAlignment = isRightToLeft ? .right : .left
        textField.semanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DirectionalTextField

        init(parent: DirectionalTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            let updatedText = textField.text ?? ""
            guard parent.text != updatedText else { return }
            parent.text = updatedText
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            guard !parent.isFocused else { return }
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return false
        }
    }
}

#Preview {
    AddAlarmView { _, _, _, _, _, _ in }
        .environmentObject(AppLocalizationController())
}
