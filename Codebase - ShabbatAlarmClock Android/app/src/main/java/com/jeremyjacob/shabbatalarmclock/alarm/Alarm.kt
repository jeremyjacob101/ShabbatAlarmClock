package com.jeremyjacob.shabbatalarmclock.alarm

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.util.UUID

@Serializable
data class Alarm(
    val id: String = UUID.randomUUID().toString(),
    val hour: Int = DefaultHour,
    val minute: Int = 0,
    val label: String = "",
    val isEnabled: Boolean = true,
    val weekday: Int = DefaultWeekday,
    val sound: AlarmSound = AlarmSound.Harp,
    val soundDurationSeconds: Int = DefaultSoundDurationSeconds,
    val soundNoiseLevel: AlarmNoiseLevel = AlarmNoiseLevel.Soft,
    val repeatsWeekly: Boolean = true,
    val autoSnoozeEnabled: Boolean = false,
    val scheduledEpochMillis: Long? = null
) {
    val normalizedWeekday: Int
        get() = normalizeWeekday(weekday)

    val clampedSoundDurationSeconds: Int
        get() = clampedSoundDuration(soundDurationSeconds)

    fun nextTriggerMillis(
        referenceMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault()
    ): Long {
        val reference = Instant.ofEpochMilli(referenceMillis).atZone(zoneId).toLocalDateTime()
        val targetDay = normalizedWeekday.toDayOfWeek()
        val targetTime = LocalTime.of(hour.coerceIn(0, 23), minute.coerceIn(0, 59))
        var candidateDate = reference.toLocalDate().nextOrSame(targetDay)
        var candidate = LocalDateTime.of(candidateDate, targetTime)

        if (!candidate.isAfter(reference)) {
            candidateDate = candidateDate.plusWeeks(1)
            candidate = LocalDateTime.of(candidateDate, targetTime)
        }

        return candidate.atZone(zoneId).toInstant().toEpochMilli()
    }

    fun primaryFireMillis(
        referenceMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault()
    ): Long = if (repeatsWeekly) {
        nextTriggerMillis(referenceMillis, zoneId)
    } else {
        scheduledEpochMillis ?: nextTriggerMillis(referenceMillis, zoneId)
    }

    fun notificationOccurrenceMillis(
        primaryFireMillis: Long,
        zoneId: ZoneId = ZoneId.systemDefault()
    ): List<Long> {
        val occurrences = mutableListOf(primaryFireMillis)
        if (autoSnoozeEnabled) {
            occurrences += Instant.ofEpochMilli(primaryFireMillis)
                .atZone(zoneId)
                .plusMinutes(AutoSnoozeMinutes.toLong())
                .toInstant()
                .toEpochMilli()
        }
        return occurrences
    }

    fun oneTimeExpirationMillis(
        referenceMillis: Long = System.currentTimeMillis(),
        zoneId: ZoneId = ZoneId.systemDefault()
    ): Long? {
        if (repeatsWeekly) return null
        val lastOccurrence = notificationOccurrenceMillis(primaryFireMillis(referenceMillis, zoneId), zoneId).lastOrNull()
            ?: return null
        val lastSegment = notificationSoundSegments(clampedSoundDurationSeconds).lastOrNull()
            ?: return lastOccurrence
        return Instant.ofEpochMilli(lastOccurrence)
            .plusSeconds(lastSegment.offsetSeconds.toLong())
            .toEpochMilli()
    }

    fun normalized(defaultLabel: String): Alarm = copy(
        label = normalizedLabel(label, defaultLabel),
        weekday = normalizedWeekday,
        hour = hour.coerceIn(0, 23),
        minute = minute.coerceIn(0, 59),
        soundDurationSeconds = clampedSoundDurationSeconds,
        scheduledEpochMillis = if (repeatsWeekly) null else scheduledEpochMillis
    )

    companion object {
        const val DefaultWeekday = 7
        const val DefaultHour = 8
        const val DefaultSoundDurationSeconds = 20
        const val PreviewSoundDurationSeconds = 10
        const val AutoSnoozeMinutes = 5

        val SupportedSoundDurations = listOf(10, 20, 30, 40, 50, 60)

        fun clampedSoundDuration(value: Int): Int {
            if (value in SupportedSoundDurations) return value
            if (value <= SupportedSoundDurations.first()) return SupportedSoundDurations.first()
            return SupportedSoundDurations.firstOrNull { value < it } ?: SupportedSoundDurations.last()
        }

        fun notificationSoundSegments(durationSeconds: Int): List<NotificationSoundSegment> =
            when (clampedSoundDuration(durationSeconds)) {
                10 -> listOf(NotificationSoundSegment(0, 10))
                20 -> listOf(NotificationSoundSegment(0, 20))
                30 -> listOf(NotificationSoundSegment(0, 30))
                40 -> listOf(NotificationSoundSegment(0, 30), NotificationSoundSegment(30, 10))
                50 -> listOf(NotificationSoundSegment(0, 30), NotificationSoundSegment(30, 20))
                60 -> listOf(NotificationSoundSegment(0, 30), NotificationSoundSegment(30, 30))
                else -> listOf(NotificationSoundSegment(0, 10))
            }

        fun normalizeWeekday(weekday: Int): Int = weekday.takeIf { it in 1..7 } ?: DefaultWeekday

        fun normalizedLabel(label: String, defaultLabel: String): String =
            label.trim().ifBlank { defaultLabel }
    }
}

data class NotificationSoundSegment(
    val offsetSeconds: Int,
    val durationSeconds: Int
)

@Serializable
enum class AlarmSound {
    @SerialName("chimes")
    Chimes,

    @SerialName("alarm")
    Alarm,

    @SerialName("harp")
    Harp
}

@Serializable
enum class AlarmNoiseLevel {
    @SerialName("soft")
    Soft,

    @SerialName("loud")
    Loud
}

fun Int.toDayOfWeek(): DayOfWeek = when (Alarm.normalizeWeekday(this)) {
    1 -> DayOfWeek.SUNDAY
    2 -> DayOfWeek.MONDAY
    3 -> DayOfWeek.TUESDAY
    4 -> DayOfWeek.WEDNESDAY
    5 -> DayOfWeek.THURSDAY
    6 -> DayOfWeek.FRIDAY
    else -> DayOfWeek.SATURDAY
}

fun DayOfWeek.toIosWeekday(): Int = when (this) {
    DayOfWeek.SUNDAY -> 1
    DayOfWeek.MONDAY -> 2
    DayOfWeek.TUESDAY -> 3
    DayOfWeek.WEDNESDAY -> 4
    DayOfWeek.THURSDAY -> 5
    DayOfWeek.FRIDAY -> 6
    DayOfWeek.SATURDAY -> 7
}

private fun LocalDate.nextOrSame(dayOfWeek: DayOfWeek): LocalDate {
    val daysUntil = (dayOfWeek.value - this.dayOfWeek.value + 7) % 7
    return plusDays(daysUntil.toLong())
}

fun alarmSortComparator(referenceMillis: Long = System.currentTimeMillis()): Comparator<Alarm> =
    compareBy<Alarm> { it.normalizedWeekday }
        .thenBy { it.hour }
        .thenBy { it.minute }
        .thenBy { it.primaryFireMillis(referenceMillis) }
        .thenBy { it.id }
