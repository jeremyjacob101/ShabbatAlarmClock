package com.jeremyjacob.shabbatalarmclock.alarm

import java.time.Instant
import java.time.ZoneId

data class AlarmScheduleRequest(
    val identifier: String,
    val alarmId: String,
    val triggerAtMillis: Long,
    val displayedOccurrenceMillis: Long,
    val segmentDurationSeconds: Int,
    val repeatsWeekly: Boolean
)

object AlarmSchedulePlanner {
    fun requests(
        alarms: List<Alarm>,
        referenceMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault()
    ): List<AlarmScheduleRequest> {
        val sortedAlarms = alarms
            .filter { it.isEnabled }
            .sortedWith(representativeComparator(referenceMillis))

        val weekly = linkedMapOf<WeekdayTimeSlot, AlarmScheduleRequest>()
        val once = linkedMapOf<String, AlarmScheduleRequest>()

        for (alarm in sortedAlarms) {
            val primaryFire = alarm.primaryFireMillis(referenceMillis, zoneId)
            val occurrenceTimes = alarm.notificationOccurrenceMillis(primaryFire, zoneId)
            for (occurrenceMillis in occurrenceTimes) {
                for (segment in Alarm.notificationSoundSegments(alarm.clampedSoundDurationSeconds)) {
                    val triggerAtMillis = Instant.ofEpochMilli(occurrenceMillis)
                        .plusSeconds(segment.offsetSeconds.toLong())
                        .toEpochMilli()
                    val slot = WeekdayTimeSlot.from(triggerAtMillis, zoneId)
                    if (alarm.repeatsWeekly) {
                        weekly.putIfAbsent(
                            slot,
                            AlarmScheduleRequest(
                                identifier = "weekly-${slot.weekday}-${slot.hour}-${slot.minute}-${slot.second}",
                                alarmId = alarm.id,
                                triggerAtMillis = triggerAtMillis,
                                displayedOccurrenceMillis = occurrenceMillis,
                                segmentDurationSeconds = segment.durationSeconds,
                                repeatsWeekly = true
                            )
                        )
                    } else if (triggerAtMillis > referenceMillis) {
                        once.putIfAbsent(
                            "once-$triggerAtMillis",
                            AlarmScheduleRequest(
                                identifier = "once-$triggerAtMillis",
                                alarmId = alarm.id,
                                triggerAtMillis = triggerAtMillis,
                                displayedOccurrenceMillis = occurrenceMillis,
                                segmentDurationSeconds = segment.durationSeconds,
                                repeatsWeekly = false
                            )
                        )
                    }
                }
            }
        }

        val weeklySlots = weekly.keys.toSet()
        return weekly.values.sortedBy { it.triggerAtMillis } +
            once.values.filter { request ->
                WeekdayTimeSlot.from(request.triggerAtMillis, zoneId) !in weeklySlots
            }.sortedBy { it.triggerAtMillis }
    }

    private fun representativeComparator(referenceMillis: Long): Comparator<Alarm> =
        compareByDescending<Alarm> { it.repeatsWeekly }
            .then(alarmSortComparator(referenceMillis))
}

data class WeekdayTimeSlot(
    val weekday: Int,
    val hour: Int,
    val minute: Int,
    val second: Int
) {
    companion object {
        fun from(epochMillis: Long, zoneId: ZoneId): WeekdayTimeSlot {
            val dateTime = Instant.ofEpochMilli(epochMillis).atZone(zoneId)
            return WeekdayTimeSlot(
                weekday = dateTime.dayOfWeek.toIosWeekday(),
                hour = dateTime.hour,
                minute = dateTime.minute,
                second = dateTime.second
            )
        }
    }
}
