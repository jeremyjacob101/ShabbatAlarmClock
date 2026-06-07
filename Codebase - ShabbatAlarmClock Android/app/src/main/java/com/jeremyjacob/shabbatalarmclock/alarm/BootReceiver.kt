package com.jeremyjacob.shabbatalarmclock.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != android.app.AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
        ) {
            return
        }

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val appContext = context.applicationContext
                val repository = AlarmRepository(appContext)
                val scheduler = AlarmScheduler(appContext)
                val alarms = reconcileOneTimeAlarms(
                    repository.alarms.first(),
                    appContext.getString(com.jeremyjacob.shabbatalarmclock.R.string.alarm_default_label)
                )
                repository.save(alarms)
                scheduler.replaceScheduledAlarms(alarms)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
