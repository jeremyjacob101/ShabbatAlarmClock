package com.jeremyjacob.shabbatalarmclock

import android.app.Application
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmNotifier

class ShabbatAlarmClockApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AlarmNotifier.createNotificationChannel(this)
    }
}
