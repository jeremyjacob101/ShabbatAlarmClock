package com.jeremyjacob.shabbatalarmclock.alarm

import android.content.Context
import android.net.Uri

object AlarmSoundResolver {
    fun displayNameRes(sound: AlarmSound): Int = when (sound) {
        AlarmSound.Chimes -> com.jeremyjacob.shabbatalarmclock.R.string.sound_name_chimes
        AlarmSound.Alarm -> com.jeremyjacob.shabbatalarmclock.R.string.sound_name_alarm
        AlarmSound.Harp -> com.jeremyjacob.shabbatalarmclock.R.string.sound_name_harp
    }

    fun displayNameRes(noiseLevel: AlarmNoiseLevel): Int = when (noiseLevel) {
        AlarmNoiseLevel.Soft -> com.jeremyjacob.shabbatalarmclock.R.string.sound_noise_level_soft
        AlarmNoiseLevel.Loud -> com.jeremyjacob.shabbatalarmclock.R.string.sound_noise_level_loud
    }

    fun rawResourceName(
        sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel
    ): String {
        val suffix = suffixCandidates(noiseLevel).first()
        return "${sound.rawName()}_${Alarm.clampedSoundDuration(durationSeconds)}s_$suffix"
    }

    fun rawResourceId(
        context: Context,
        sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel
    ): Int? {
        val clampedDuration = Alarm.clampedSoundDuration(durationSeconds)
        val durations = buildList {
            add(clampedDuration)
            add(Alarm.PreviewSoundDurationSeconds)
            add(30)
            add(20)
            add(10)
        }.distinct().filter { it <= 30 }

        for (duration in durations) {
            for (suffix in suffixCandidates(noiseLevel)) {
                val name = "${sound.rawName()}_${duration}s_$suffix"
                val id = context.resources.getIdentifier(name, "raw", context.packageName)
                if (id != 0) return id
            }
        }
        return null
    }

    fun uri(
        context: Context,
        sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel
    ): Uri? {
        val resourceId = rawResourceId(context, sound, durationSeconds, noiseLevel) ?: return null
        return Uri.parse("android.resource://${context.packageName}/$resourceId")
    }

    private fun AlarmSound.rawName(): String = when (this) {
        AlarmSound.Chimes -> "chimes"
        AlarmSound.Alarm -> "alarm"
        AlarmSound.Harp -> "harp"
    }

    private fun suffixCandidates(noiseLevel: AlarmNoiseLevel): List<String> = when (noiseLevel) {
        AlarmNoiseLevel.Soft -> listOf("louder")
        AlarmNoiseLevel.Loud -> listOf("super_loud", "louder")
    }
}
