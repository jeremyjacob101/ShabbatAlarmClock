package com.jeremyjacob.shabbatalarmclock.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

class AlarmTest {
    private val zone = ZoneId.of("Asia/Jerusalem")

    @Test
    fun clampedSoundDurationUsesNextSupportedStep() {
        assertEquals(10, Alarm.clampedSoundDuration(5))
        assertEquals(20, Alarm.clampedSoundDuration(11))
        assertEquals(40, Alarm.clampedSoundDuration(31))
        assertEquals(60, Alarm.clampedSoundDuration(100))
    }

    @Test
    fun soundSegmentsMatchIosMapping() {
        assertEquals(listOf(NotificationSoundSegment(0, 10)), Alarm.notificationSoundSegments(10))
        assertEquals(listOf(NotificationSoundSegment(0, 20)), Alarm.notificationSoundSegments(20))
        assertEquals(listOf(NotificationSoundSegment(0, 30)), Alarm.notificationSoundSegments(30))
        assertEquals(
            listOf(NotificationSoundSegment(0, 30), NotificationSoundSegment(30, 10)),
            Alarm.notificationSoundSegments(40)
        )
        assertEquals(
            listOf(NotificationSoundSegment(0, 30), NotificationSoundSegment(30, 20)),
            Alarm.notificationSoundSegments(50)
        )
        assertEquals(
            listOf(NotificationSoundSegment(0, 30), NotificationSoundSegment(30, 30)),
            Alarm.notificationSoundSegments(60)
        )
    }

    @Test
    fun nextTriggerRollsForwardWhenTimeAlreadyPassed() {
        val reference = LocalDateTime.of(2026, 6, 7, 9, 0).atZone(zone).toInstant().toEpochMilli()
        val alarm = Alarm(hour = 8, minute = 0, weekday = 1)

        val next = LocalDateTime.ofInstant(
            java.time.Instant.ofEpochMilli(alarm.nextTriggerMillis(reference, zone)),
            zone
        )

        assertEquals(2026, next.year)
        assertEquals(6, next.monthValue)
        assertEquals(14, next.dayOfMonth)
        assertEquals(8, next.hour)
    }

    @Test
    fun oneTimeAlarmUsesStoredPrimaryFireMillis() {
        val scheduled = LocalDateTime.of(2026, 6, 13, 8, 0).atZone(zone).toInstant().toEpochMilli()
        val alarm = Alarm(repeatsWeekly = false, scheduledEpochMillis = scheduled)

        assertEquals(scheduled, alarm.primaryFireMillis(zoneId = zone))
    }

    @Test
    fun oneTimeExpirationIncludesAutoSnoozeAndFinalSegmentOffset() {
        val scheduled = LocalDateTime.of(2026, 6, 13, 8, 0).atZone(zone).toInstant().toEpochMilli()
        val alarm = Alarm(
            repeatsWeekly = false,
            scheduledEpochMillis = scheduled,
            autoSnoozeEnabled = true,
            soundDurationSeconds = 60
        )

        val expiration = LocalDateTime.ofInstant(
            java.time.Instant.ofEpochMilli(alarm.oneTimeExpirationMillis(zoneId = zone)!!),
            zone
        )

        assertEquals(8, expiration.hour)
        assertEquals(5, expiration.minute)
        assertEquals(30, expiration.second)
    }

    @Test
    fun emptyLabelNormalizesToDefault() {
        assertEquals("Alarm", Alarm.normalizedLabel("   ", "Alarm"))
    }

    @Test
    fun duplicateWeeklySlotSuppressesOneTimeSlot() {
        val reference = LocalDateTime.of(2026, 6, 7, 9, 0).atZone(zone).toInstant().toEpochMilli()
        val weekly = Alarm(id = "weekly", hour = 8, minute = 0, weekday = 7, repeatsWeekly = true)
        val once = Alarm(
            id = "once",
            hour = 8,
            minute = 0,
            weekday = 7,
            repeatsWeekly = false,
            scheduledEpochMillis = weekly.nextTriggerMillis(reference, zone)
        )

        val requests = AlarmSchedulePlanner.requests(listOf(once, weekly), reference, zone)

        assertTrue(requests.any { it.alarmId == "weekly" })
        assertFalse(requests.any { it.alarmId == "once" })
    }
}
