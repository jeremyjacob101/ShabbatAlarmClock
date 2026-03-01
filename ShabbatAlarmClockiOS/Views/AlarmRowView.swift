import SwiftUI

struct AlarmRowView: View {
    let alarm: Alarm
    let themeColor: Color
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void

    private var weekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        guard (1...symbols.count).contains(alarm.weekday) else {
            return "Unknown Day"
        }
        return symbols[alarm.weekday - 1]
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateFormatter.alarmTime.string(from: alarm.time))
                            .font(.system(size: 34, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(themeColor)

                        Text(alarm.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            if alarm.repeatsWeekly {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                    .foregroundStyle(themeColor)
                            }

                            Text(weekdayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .opacity(alarm.isEnabled ? 1.0 : 0.5)
    }
}

#Preview {
    AlarmRowView(
        alarm: Alarm(time: Date(), label: "Shabbat Alarm", isEnabled: true, weekday: 6),
        themeColor: .blue,
        onEdit: { },
        onToggle: { _ in }
    )
    .padding()
}
