package com.jeremyjacob.shabbatalarmclock.ui

import android.content.Context
import android.media.MediaPlayer
import com.jeremyjacob.shabbatalarmclock.alarm.Alarm
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmNoiseLevel
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmSound
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmSoundResolver

class SoundPreviewController(private val context: Context) {
    private var player: MediaPlayer? = null

    val isPlaying: Boolean
        get() = player?.isPlaying == true

    fun play(
        sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel,
        onComplete: () -> Unit
    ) {
        stop()
        val uri = AlarmSoundResolver.uri(
            context,
            sound,
            minOf(durationSeconds, Alarm.PreviewSoundDurationSeconds),
            noiseLevel
        ) ?: return

        player = MediaPlayer.create(context, uri)?.apply {
            setOnCompletionListener {
                this@SoundPreviewController.stop()
                onComplete()
            }
            start()
        }
    }

    fun stop() {
        player?.run {
            setOnCompletionListener(null)
            stopCatching()
            release()
        }
        player = null
    }

    private fun MediaPlayer.stopCatching() {
        runCatching { stop() }
    }
}
