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

                    FixedOrderTimePicker(
                        selection: $time,
                        locale: localization.locale,
                        calendar: localization.calendar,
                        accessibilityLabel: strings.alarmTime
                    )
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
            .background(
                SheetSemanticContentAttributeInstaller(
                    semanticContentAttribute: localization.language.semanticContentAttribute
                )
            )
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

private struct FixedOrderTimePicker: UIViewRepresentable {
    @Binding var selection: Date

    let locale: Locale
    let calendar: Calendar
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> FixedOrderTimePickerView {
        let view = FixedOrderTimePickerView()
        view.picker.dataSource = context.coordinator
        view.picker.delegate = context.coordinator
        context.coordinator.configure(view, animated: false)
        return view
    }

    func updateUIView(_ uiView: FixedOrderTimePickerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configure(uiView, animated: false)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: FixedOrderTimePickerView,
        context: Context
    ) -> CGSize? {
        let intrinsicSize = uiView.intrinsicContentSize
        return CGSize(
            width: proposal.width ?? intrinsicSize.width,
            height: intrinsicSize.height
        )
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        private enum Component {
            case hour
            case minute
            case meridiem
        }

        private struct Configuration: Equatable {
            let localeIdentifier: String
            let usesTwelveHourClock: Bool
            let amSymbol: String
            let pmSymbol: String
        }

        var parent: FixedOrderTimePicker
        private var isUpdatingSelection = false
        private var configuration: Configuration?

        init(parent: FixedOrderTimePicker) {
            self.parent = parent
        }

        func configure(_ view: FixedOrderTimePickerView, animated: Bool) {
            view.picker.accessibilityLabel = parent.accessibilityLabel
            view.semanticContentAttribute = .forceLeftToRight
            view.picker.semanticContentAttribute = .forceLeftToRight

            let newConfiguration = makeConfiguration()
            if newConfiguration != configuration {
                configuration = newConfiguration
                view.picker.reloadAllComponents()
            }

            updateSelectionIfNeeded(in: view.picker, animated: animated)
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            componentOrder.count
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch componentType(for: component) {
            case .hour:
                return hourValues.count * repetitionCount
            case .minute:
                return minuteValues.count * repetitionCount
            case .meridiem:
                return meridiemValues.count
            }
        }

        func pickerView(
            _ pickerView: UIPickerView,
            widthForComponent component: Int
        ) -> CGFloat {
            switch componentType(for: component) {
            case .hour:
                return hourComponentWidth
            case .minute:
                return digitComponentWidth
            case .meridiem:
                return meridiemComponentWidth
            }
        }

        func pickerView(
            _ pickerView: UIPickerView,
            rowHeightForComponent component: Int
        ) -> CGFloat {
            40
        }

        func pickerView(
            _ pickerView: UIPickerView,
            viewForRow row: Int,
            forComponent component: Int,
            reusing view: UIView?
        ) -> UIView {
            let label = (view as? PickerRowLabel) ?? PickerRowLabel()
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .label
            label.backgroundColor = .clear
            label.semanticContentAttribute = .forceLeftToRight
            label.font = componentType(for: component) == .meridiem
                ? .systemFont(ofSize: 24, weight: .regular)
                : .monospacedDigitSystemFont(ofSize: 24, weight: .regular)
            label.textAlignment = textAlignment(for: component)
            label.textInsets = textInsets(for: component)
            label.text = title(for: row, component: component)
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard !isUpdatingSelection else { return }

            recenterIfNeeded(component: component, in: pickerView)
            let hour = selectedHourValue(in: pickerView)
            let minute = selectedMinuteValue(in: pickerView)
            let convertedHour = usesTwelveHourClock
                ? convertedTwentyFourHour(hour: hour, meridiemIndex: selectedMeridiemIndex(in: pickerView))
                : hour

            var updatedCalendar = parent.calendar
            updatedCalendar.locale = parent.locale

            let currentComponents = updatedCalendar.dateComponents(
                [.year, .month, .day, .second, .nanosecond],
                from: parent.selection
            )

            var components = DateComponents()
            components.year = currentComponents.year
            components.month = currentComponents.month
            components.day = currentComponents.day
            components.hour = convertedHour
            components.minute = minute
            components.second = currentComponents.second ?? 0
            components.nanosecond = currentComponents.nanosecond ?? 0
            components.calendar = updatedCalendar
            components.timeZone = updatedCalendar.timeZone

            if let updatedDate = updatedCalendar.date(from: components) {
                isUpdatingSelection = true
                parent.selection = updatedDate
                isUpdatingSelection = false
            }
        }

        private var usesTwelveHourClock: Bool {
            configuration?.usesTwelveHourClock ?? false
        }

        private var hourValues: [Int] {
            usesTwelveHourClock ? Array(1...12) : Array(0...23)
        }

        private var minuteValues: [Int] {
            Array(0...59)
        }

        private var meridiemValues: [String] {
            [configuration?.amSymbol ?? "AM", configuration?.pmSymbol ?? "PM"]
        }

        private var componentOrder: [Component] {
            if usesTwelveHourClock {
                return usesLeadingMeridiem
                    ? [.meridiem, .hour, .minute]
                    : [.hour, .minute, .meridiem]
            }

            return [.hour, .minute]
        }

        private var usesLeadingMeridiem: Bool {
            AppLanguage.from(locale: parent.locale) == .hebrew
        }

        private var digitComponentWidth: CGFloat {
            72
        }

        private var hourComponentWidth: CGFloat {
            usesLeadingMeridiem ? 64 : digitComponentWidth
        }

        private var meridiemComponentWidth: CGFloat {
            76
        }

        private var repetitionCount: Int {
            400
        }

        private func makeConfiguration() -> Configuration {
            let formatter = DateFormatter()
            formatter.locale = parent.locale
            let usesTwelveHourClock = Locale.autoupdatingCurrent.prefersTwelveHourClock

            return Configuration(
                localeIdentifier: parent.locale.identifier,
                usesTwelveHourClock: usesTwelveHourClock,
                amSymbol: formatter.amSymbol,
                pmSymbol: formatter.pmSymbol
            )
        }

        private func componentType(for component: Int) -> Component {
            guard componentOrder.indices.contains(component) else { return .minute }
            return componentOrder[component]
        }

        private func componentIndex(for component: Component) -> Int? {
            componentOrder.firstIndex(of: component)
        }

        private func title(for row: Int, component: Int) -> String {
            switch componentType(for: component) {
            case .hour:
                return parent.locale.hourFormatter.string(from: NSNumber(value: hourValues[wrappedIndex(row, count: hourValues.count)])) ?? ""
            case .minute:
                return parent.locale.minuteFormatter.string(from: NSNumber(value: minuteValues[wrappedIndex(row, count: minuteValues.count)])) ?? ""
            case .meridiem:
                return meridiemValues[wrappedIndex(row, count: meridiemValues.count)]
            }
        }

        private func textAlignment(for component: Int) -> NSTextAlignment {
            switch componentType(for: component) {
            case .meridiem where usesLeadingMeridiem:
                return .right
            case .hour:
                return .right
            case .minute, .meridiem:
                return .left
            }
        }

        private func textInsets(for component: Int) -> UIEdgeInsets {
            switch componentType(for: component) {
            case .hour:
                return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
            case .minute:
                return UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
            case .meridiem:
                return usesLeadingMeridiem
                    ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 2)
                    : UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            }
        }

        private func updateSelectionIfNeeded(in pickerView: UIPickerView, animated: Bool) {
            let components = parent.calendar.dateComponents([.hour, .minute], from: parent.selection)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let meridiemIndex = hour >= 12 ? 1 : 0
            let twelveHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

            let hourValue = usesTwelveHourClock ? twelveHour : hour
            let targetHourRow = centeredRow(for: hourValue, values: hourValues)
            let targetMinuteRow = centeredRow(for: minute, values: minuteValues)

            isUpdatingSelection = true

            if let hourComponent = componentIndex(for: .hour),
               pickerView.selectedRow(inComponent: hourComponent) != targetHourRow {
                pickerView.selectRow(targetHourRow, inComponent: hourComponent, animated: animated)
            }

            if let minuteComponent = componentIndex(for: .minute),
               pickerView.selectedRow(inComponent: minuteComponent) != targetMinuteRow {
                pickerView.selectRow(targetMinuteRow, inComponent: minuteComponent, animated: animated)
            }

            if usesTwelveHourClock,
               let meridiemComponent = componentIndex(for: .meridiem) {
                let targetMeridiemRow = meridiemIndex
                if pickerView.selectedRow(inComponent: meridiemComponent) != targetMeridiemRow {
                    pickerView.selectRow(
                        targetMeridiemRow,
                        inComponent: meridiemComponent,
                        animated: animated
                    )
                }
            }

            isUpdatingSelection = false
        }

        private func recenterIfNeeded(component: Int, in pickerView: UIPickerView) {
            let componentType = componentType(for: component)
            let valuesCount: Int

            switch componentType {
            case .hour:
                valuesCount = hourValues.count
            case .minute:
                valuesCount = minuteValues.count
            case .meridiem:
                return
            }

            let selectedRow = pickerView.selectedRow(inComponent: component)
            let centered = centeredRow(
                forWrappedIndex: wrappedIndex(selectedRow, count: valuesCount),
                valuesCount: valuesCount
            )

            if abs(selectedRow - centered) > valuesCount {
                isUpdatingSelection = true
                pickerView.selectRow(centered, inComponent: component, animated: false)
                isUpdatingSelection = false
            }
        }

        private func centeredRow(for value: Int, values: [Int]) -> Int {
            let index = values.firstIndex(of: value) ?? 0
            return centeredRow(forWrappedIndex: index, valuesCount: values.count)
        }

        private func centeredRow(forWrappedIndex index: Int, valuesCount: Int) -> Int {
            let midpoint = repetitionCount / 2
            return midpoint * valuesCount + index
        }

        private func wrappedIndex(_ row: Int, count: Int) -> Int {
            guard count > 0 else { return 0 }
            let remainder = row % count
            return remainder >= 0 ? remainder : remainder + count
        }

        private func selectedHourValue(in pickerView: UIPickerView) -> Int {
            guard let component = componentIndex(for: .hour) else {
                return hourValues.first ?? 0
            }
            let row = pickerView.selectedRow(inComponent: component)
            return hourValues[wrappedIndex(row, count: hourValues.count)]
        }

        private func selectedMinuteValue(in pickerView: UIPickerView) -> Int {
            guard let component = componentIndex(for: .minute) else {
                return minuteValues.first ?? 0
            }
            let row = pickerView.selectedRow(inComponent: component)
            return minuteValues[wrappedIndex(row, count: minuteValues.count)]
        }

        private func selectedMeridiemIndex(in pickerView: UIPickerView) -> Int {
            guard usesTwelveHourClock else { return 0 }
            guard let component = componentIndex(for: .meridiem) else { return 0 }
            let row = pickerView.selectedRow(inComponent: component)
            return min(max(row, 0), max(meridiemValues.count - 1, 0))
        }

        private func convertedTwentyFourHour(hour: Int, meridiemIndex: Int) -> Int {
            switch (hour, meridiemIndex) {
            case (12, 0):
                return 0
            case (12, 1):
                return 12
            case (_, 1):
                return hour + 12
            default:
                return hour
            }
        }
    }
}

private final class FixedOrderTimePickerView: UIView {
    let picker = UIPickerView(frame: .zero)

    override var intrinsicContentSize: CGSize {
        let pickerSize = picker.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: pickerSize.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        semanticContentAttribute = .forceLeftToRight
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.backgroundColor = .clear
        picker.semanticContentAttribute = .forceLeftToRight
        picker.setContentHuggingPriority(.required, for: .vertical)
        picker.setContentCompressionResistancePriority(.required, for: .vertical)

        addSubview(picker)

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: trailingAnchor),
            picker.topAnchor.constraint(equalTo: topAnchor),
            picker.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private final class PickerRowLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
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

private struct SheetSemanticContentAttributeInstaller: UIViewControllerRepresentable {
    let semanticContentAttribute: UISemanticContentAttribute

    func makeUIViewController(context: Context) -> InstallerViewController {
        let viewController = InstallerViewController()
        viewController.view.isHidden = true
        viewController.view.isUserInteractionEnabled = false
        return viewController
    }

    func updateUIViewController(_ uiViewController: InstallerViewController, context: Context) {
        uiViewController.semanticContentAttributeOverride = semanticContentAttribute
        uiViewController.applySemanticContentAttributeIfNeeded()
    }

    final class InstallerViewController: UIViewController {
        var semanticContentAttributeOverride: UISemanticContentAttribute = .unspecified

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applySemanticContentAttributeIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applySemanticContentAttributeIfNeeded()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applySemanticContentAttributeIfNeeded()
        }

        func applySemanticContentAttributeIfNeeded() {
            for controller in hostingControllerChain() {
                controller.view.semanticContentAttribute = semanticContentAttributeOverride
            }
        }

        private func hostingControllerChain() -> [UIViewController] {
            var controllers: [UIViewController] = []
            var seen = Set<ObjectIdentifier>()
            var current: UIViewController? = self

            while let controller = current {
                let identifier = ObjectIdentifier(controller)
                if seen.insert(identifier).inserted {
                    controllers.append(controller)
                }

                if let navigationController = controller.navigationController {
                    let navigationIdentifier = ObjectIdentifier(navigationController)
                    if seen.insert(navigationIdentifier).inserted {
                        controllers.append(navigationController)
                    }
                }

                if controller.presentingViewController != nil || controller.parent == nil {
                    break
                }

                current = controller.parent
            }

            return controllers
        }
    }
}

private extension Locale {
    var hourFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = self
        formatter.numberStyle = .none
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var minuteFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = self
        formatter.numberStyle = .none
        formatter.minimumIntegerDigits = 2
        formatter.maximumFractionDigits = 0
        return formatter
    }
}

#Preview {
    AddAlarmView { _, _, _, _, _, _ in }
        .environmentObject(AppLocalizationController())
}
