import SwiftUI

struct AlarmRowView: View {
    @EnvironmentObject private var localization: AppLocalizationController

    let alarm: Alarm
    let themeColor: Color
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void

    private var isRightToLeft: Bool {
        localization.layoutDirection == .rightToLeft
    }

    private var fixedScreenOrderLayoutDirection: LayoutDirection {
        .leftToRight
    }

    private var weekdayName: String {
        localization.strings.weekdayName(for: alarm.weekday)
    }

    var body: some View {
        HStack(spacing: 12) {
            if isRightToLeft {
                alarmToggle
                alarmDetailsButton
            } else {
                alarmDetailsButton
                alarmToggle
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
        .opacity(alarm.isEnabled ? 1.0 : 0.5)
        .environment(\.layoutDirection, fixedScreenOrderLayoutDirection)
        .id("\(alarm.id.uuidString)-\(localization.language.rawValue)")
    }

    private var alarmDetailsButton: some View {
        Button(action: onEdit) {
            VStack(alignment: isRightToLeft ? .trailing : .leading, spacing: 6) {
                Text(alarm.time, format: .dateTime.hour().minute())
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeColor)
                    .frame(maxWidth: .infinity, alignment: isRightToLeft ? .trailing : .leading)

                HStack(spacing: 6) {
                    if alarm.repeatsWeekly {
                        Image(systemName: "repeat")
                            .font(.footnote)
                            .foregroundStyle(themeColor)
                    }

                    Text(weekdayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: isRightToLeft ? .trailing : .leading)

                Text(localization.strings.displayedAlarmLabel(alarm.label))
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: isRightToLeft ? .trailing : .leading)
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: isRightToLeft ? .trailing : .leading)
        }
        .buttonStyle(.plain)
    }

    private var alarmToggle: some View {
        Toggle("", isOn: Binding(
            get: { alarm.isEnabled },
            set: { onToggle($0) }
        ))
        .labelsHidden()
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
    .environmentObject(AppLocalizationController())
}
