import SwiftUI

struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateFormatter.alarmTime.string(from: alarm.time))
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()

                Text(alarm.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
        alarm: Alarm(time: Date(), label: "Shabbat Alarm", isEnabled: true, repeatsDaily: true),
        onToggle: { _ in }
    )
    .padding()
}
