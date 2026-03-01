import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var repeatsWeekly = false
    @State private var isTestingSound = false

    private let calendar = Calendar.current
    private let isEditing: Bool
    private let soundPreviewPlayer = AlarmSoundPreviewPlayer.shared

    let onSave: (Date, String, Int, AlarmSound, Bool) -> Void

    init(alarm: Alarm? = nil, onSave: @escaping (Date, String, Int, AlarmSound, Bool) -> Void) {
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
                } header: {
                    HStack {
                        Text("Sound")

                        Spacer()

                        Button {
                            toggleSoundPreview()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: isTestingSound ? "stop.fill" : "play.fill")
                                Text("Test Sound")
                            }
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                    }
                    .textCase(nil)
                }

                Section("Label") {
                    TextField("Alarm", text: $label)
                }
            }
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
                            repeatsWeekly
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: sound) { _, _ in
                if isTestingSound {
                    stopSoundPreview()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    stopSoundPreview()
                }
            }
            .onDisappear {
                stopSoundPreview()
            }
        }
    }

    private func toggleSoundPreview() {
        if isTestingSound {
            stopSoundPreview()
        } else {
            isTestingSound = true
            soundPreviewPlayer.play(sound) {
                isTestingSound = false
            }
        }
    }

    private func stopSoundPreview() {
        guard isTestingSound else { return }
        soundPreviewPlayer.stop()
        isTestingSound = false
    }
}

#Preview {
    AddAlarmView { _, _, _, _, _ in }
}
