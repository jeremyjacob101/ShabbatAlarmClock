import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date()
    @State private var label = "Alarm"
    @State private var weekday = Calendar.current.component(.weekday, from: Date())

    private let calendar = Calendar.current

    let onSave: (Date, String, Int) -> Void

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

                Section("Label") {
                    TextField("Alarm", text: $label)
                }

                Section {
                    Text("This alarm repeats every week on the selected day and time.")
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
                        onSave(
                            time,
                            label.trimmingCharacters(in: .whitespacesAndNewlines),
                            weekday
                        )
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
