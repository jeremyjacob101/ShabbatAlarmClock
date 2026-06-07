package com.jeremyjacob.shabbatalarmclock.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.time.ZoneId

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val repository = AlarmRepository(context.applicationContext)
                val scheduler = AlarmScheduler(context.applicationContext)
                val alarmId = intent.getStringExtra(ExtraAlarmId)
                val displayedOccurrenceMillis = intent.getLongExtra(ExtraDisplayedOccurrenceMillis, 0L)
                val segmentDurationSeconds = intent.getIntExtra(ExtraSegmentDurationSeconds, Alarm.PreviewSoundDurationSeconds)
                val alarms = repository.alarms.first()
                val alarm = alarms.firstOrNull { it.id == alarmId }

                if (alarm != null) {
                    AlarmNotifier.showAlarm(
                        context,
                        alarm,
                        displayedOccurrenceMillis.takeIf { it > 0L } ?: System.currentTimeMillis(),
                        segmentDurationSeconds
                    )
                }

                val reconciled = reconcileOneTimeAlarms(alarms, context.getString(com.jeremyjacob.shabbatalarmclock.R.string.alarm_default_label))
                if (reconciled != alarms) {
                    repository.save(reconciled)
                }
                scheduler.replaceScheduledAlarms(reconciled)
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        private const val ExtraAlarmId = "alarm_id"
        private const val ExtraDisplayedOccurrenceMillis = "displayed_occurrence_millis"
        private const val ExtraSegmentDurationSeconds = "segment_duration_seconds"
        private const val ExtraRepeatsWeekly = "repeats_weekly"

        fun intent(context: Context, request: AlarmScheduleRequest): Intent =
            Intent(context, AlarmReceiver::class.java)
                .putExtra(ExtraAlarmId, request.alarmId)
                .putExtra(ExtraDisplayedOccurrenceMillis, request.displayedOccurrenceMillis)
                .putExtra(ExtraSegmentDurationSeconds, request.segmentDurationSeconds)
                .putExtra(ExtraRepeatsWeekly, request.repeatsWeekly)
    }
}

fun reconcileOneTimeAlarms(
    alarms: List<Alarm>,
    defaultLabel: String,
    nowMillis: Long = System.currentTimeMillis(),
    zoneId: ZoneId = ZoneId.systemDefault()
): List<Alarm> = alarms.map { alarm ->
    val normalized = alarm.normalized(defaultLabel)
    val expirationMillis = normalized.oneTimeExpirationMillis(nowMillis, zoneId)
    if (!normalized.repeatsWeekly && normalized.isEnabled && expirationMillis != null && nowMillis > expirationMillis) {
        normalized.copy(isEnabled = false)
    } else {
        normalized
    }
}
