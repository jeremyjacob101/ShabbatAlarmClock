package com.jeremyjacob.shabbatalarmclock.alarm

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.jeremyjacob.shabbatalarmclock.MainActivity
import com.jeremyjacob.shabbatalarmclock.R
import java.text.DateFormat
import java.time.Instant
import java.time.ZoneId
import java.util.Date
import java.util.Locale

object AlarmNotifier {
    private const val ChannelId = "alarms"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            ChannelId,
            context.getString(R.string.notification_channel_alarms),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.notification_channel_alarms_description)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            enableVibration(true)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun showAlarm(
        context: Context,
        alarm: Alarm,
        displayedOccurrenceMillis: Long,
        segmentDurationSeconds: Int
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val contentIntent = PendingIntent.getActivity(
            context,
            alarm.id.hashCode(),
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val soundResourceId = AlarmSoundResolver.rawResourceId(
            context,
            alarm.sound,
            segmentDurationSeconds,
            alarm.soundNoiseLevel
        )
        val soundUri = soundResourceId?.let { Uri.parse("android.resource://${context.packageName}/$it") }
        val channelId = ensureSoundChannel(context, soundResourceId, soundUri)
        val body = context.getString(
            R.string.notification_body,
            weekdayName(context, displayedOccurrenceMillis),
            DateFormat.getTimeInstance(DateFormat.SHORT, Locale.getDefault())
                .format(Date(displayedOccurrenceMillis))
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_alarm_notification)
            .setContentTitle(alarm.label.ifBlank { context.getString(R.string.alarm_default_label) })
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setSound(soundUri)
            .build()

        NotificationManagerCompat.from(context).notify(alarm.id.hashCode(), notification)
    }

    private fun weekdayName(context: Context, epochMillis: Long): String {
        val weekday = Instant.ofEpochMilli(epochMillis)
            .atZone(ZoneId.systemDefault())
            .dayOfWeek
            .toIosWeekday()
        return context.resources.getStringArray(R.array.weekday_names)[weekday - 1]
    }

    private fun ensureSoundChannel(context: Context, soundResourceId: Int?, soundUri: Uri?): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return ChannelId
        val channelId = soundResourceId?.let { "alarms_sound_$it" } ?: ChannelId
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(channelId) != null) return channelId

        val channel = NotificationChannel(
            channelId,
            context.getString(R.string.notification_channel_alarms),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = context.getString(R.string.notification_channel_alarms_description)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            enableVibration(true)
            if (soundUri != null) {
                setSound(
                    soundUri,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
        }
        manager.createNotificationChannel(channel)
        return channelId
    }
}
