package com.jeremyjacob.shabbatalarmclock.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.graphics.Color
import com.jeremyjacob.shabbatalarmclock.settings.AppTheme

@Composable
fun ShabbatAlarmClockTheme(
    theme: AppTheme,
    content: @Composable () -> Unit
) {
    val primary = theme.seed
    val light = lightColorScheme(
        primary = primary,
        secondary = Color(0xFF475569),
        tertiary = Color(0xFF0F766E),
        surface = Color(0xFFFFFBFE),
        background = Color(0xFFFFFBFE)
    )
    val dark = darkColorScheme(
        primary = primary,
        secondary = Color(0xFFCBD5E1),
        tertiary = Color(0xFF5EEAD4),
        surface = Color(0xFF111318),
        background = Color(0xFF111318)
    )
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) dark else light,
        content = content
    )
}
