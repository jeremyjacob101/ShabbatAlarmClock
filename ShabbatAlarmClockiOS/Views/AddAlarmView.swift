import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isLabelFieldFocused: Bool

    private static func defaultAlarmTime() -> Date {
        Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    @State private var time = Self.defaultAlarmTime()
    @State private var label = "Alarm"
    @State private var weekday = 7
    @State private var sound: AlarmSound = .defaultSound
    @State private var soundDurationSeconds = Alarm.defaultSoundDurationSeconds
    @State private var repeatsWeekly = false
    @State private var isTestingSound = false

    private let calendar = Calendar.current
    private let isEditing: Bool
    private let soundPreviewPlayer = AlarmSoundPreviewPlayer.shared

    let onSave: (Date, String, Int, AlarmSound, Int, Bool) -> Void

    init(alarm: Alarm? = nil, onSave: @escaping (Date, String, Int, AlarmSound, Int, Bool) -> Void) {
        let initialAlarm = alarm ?? Alarm(
            time: Self.defaultAlarmTime(),
            weekday: 7,
            sound: .defaultSound,
            repeatsWeekly: false
        )

        _time = State(initialValue: initialAlarm.time)
        _label = State(initialValue: initialAlarm.label)
        _weekday = State(initialValue: initialAlarm.weekday)
        _sound = State(initialValue: initialAlarm.sound)
        _soundDurationSeconds = State(initialValue: initialAlarm.soundDurationSeconds)
        _repeatsWeekly = State(initialValue: initialAlarm.repeatsWeekly)
        isEditing = alarm != nil
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    Picker("Day of Week", selection: $weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(calendar.weekdaySymbols[day - 1]).tag(day)
                        }
                    }

                    DatePicker(
                        "Alarm Time",
                        selection: $time,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Section("Repeat") {
                    Toggle("Repeat every week", isOn: $repeatsWeekly)
                }

                Section {
                    Picker("Alarm Sound", selection: $sound) {
                        ForEach(AlarmSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Alarm Sound Length")

                            Spacer()

                            Text("\(soundDurationSeconds)s")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        DiscreteStepSlider(
                            value: $soundDurationSeconds,
                            steps: Alarm.supportedSoundDurations,
                            accessibilityLabel: "Alarm sound length"
                        )
                    }
                } header: {
                    HStack {
                        Text("Sound")

                        Spacer()

                        Button {
                            toggleSoundPreview()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: isTestingSound ? "hat.widebrim.fill" : "play.fill")
                                Text(isTestingSound ? "Stop Sound" : "Test Sound")
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                    }
                    .textCase(nil)
                }

                Section("Label") {
                    TextField("Alarm", text: $label)
                        .focused($isLabelFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                        }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .background(
                KeyboardDismissTapInstaller {
                    dismissKeyboard()
                }
            )
            .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        stopSoundPreview()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        stopSoundPreview()
                        onSave(
                            time,
                            label.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func toggleSoundPreview() {
        if isTestingSound {
            stopSoundPreview()
        } else {
            isTestingSound = true
            soundPreviewPlayer.play(sound, durationSeconds: soundDurationSeconds) {
                isTestingSound = false
            }
        }
    }

    private func stopSoundPreview() {
        guard isTestingSound else { return }
        soundPreviewPlayer.stop()
        isTestingSound = false
    }

    private func dismissKeyboard() {
        isLabelFieldFocused = false
    }
}

#Preview {
    AddAlarmView { _, _, _, _, _, _ in }
}
