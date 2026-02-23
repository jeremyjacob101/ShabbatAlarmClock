import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date()
    @State private var label = "Alarm"
    @State private var sound: AlarmSound = .alarm

    let onSave: (Date, String, AlarmSound) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    DatePicker(
                        "Alarm Time",
                        selection: $time,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Section("Label") {
                    TextField("Alarm", text: $label)
                }

                Section("Sound") {
                    Picker("Sound", selection: $sound) {
                        ForEach(AlarmSound.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Text("This starter schedules a daily repeating local notification.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(time, label.trimmingCharacters(in: .whitespacesAndNewlines), sound)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    AddAlarmView { _, _, _ in }
}
