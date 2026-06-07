package com.jeremyjacob.shabbatalarmclock.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.jeremyjacob.shabbatalarmclock.MainActivity

class AlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)
    private val preferences = context.getSharedPreferences("scheduled_alarm_ids", Context.MODE_PRIVATE)

    fun canScheduleExactAlarms(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    fun replaceScheduledAlarms(alarms: List<Alarm>) {
        cancelScheduledIds()
        val requests = AlarmSchedulePlanner.requests(alarms)
        requests.forEach(::schedule)
        preferences.edit().putStringSet(ScheduledIdsKey, requests.map { it.identifier }.toSet()).apply()
    }

    fun clearScheduledAlarms() {
        cancelScheduledIds()
        preferences.edit().remove(ScheduledIdsKey).apply()
    }

    private fun schedule(request: AlarmScheduleRequest) {
        val operation = PendingIntent.getBroadcast(
            context,
            request.identifier.hashCode(),
            AlarmReceiver.intent(context, request),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val showIntent = PendingIntent.getActivity(
            context,
            request.identifier.hashCode(),
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmInfo = AlarmManager.AlarmClockInfo(request.triggerAtMillis, showIntent)
        alarmManager.setAlarmClock(alarmInfo, operation)
    }

    private fun cancelScheduledIds() {
        preferences.getStringSet(ScheduledIdsKey, emptySet()).orEmpty().forEach { identifier ->
            val operation = PendingIntent.getBroadcast(
                context,
                identifier.hashCode(),
                Intent(context, AlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (operation != null) {
                alarmManager.cancel(operation)
                operation.cancel()
            }
        }
    }

    private companion object {
        const val ScheduledIdsKey = "scheduled_ids"
    }
}
