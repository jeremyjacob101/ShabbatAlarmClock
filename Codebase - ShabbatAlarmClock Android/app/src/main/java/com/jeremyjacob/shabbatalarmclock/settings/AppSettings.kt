package com.jeremyjacob.shabbatalarmclock.settings

import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.ui.graphics.Color
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.jeremyjacob.shabbatalarmclock.R
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "settings")

data class AppSettings(
    val languageSelection: AppLanguageSelection = AppLanguageSelection.System,
    val theme: AppTheme = AppTheme.Blue,
    val ringerReminderDismissed: Boolean = false
)

enum class AppLanguageSelection(@StringRes val titleRes: Int) {
    System(R.string.settings_language_option_system),
    English(R.string.settings_language_option_english),
    Hebrew(R.string.settings_language_option_hebrew)
}

enum class AppTheme(@StringRes val titleRes: Int, val seed: Color) {
    Standard(R.string.theme_standard, Color(0xFF202124)),
    Blue(R.string.theme_blue, Color(0xFF2563EB)),
    Teal(R.string.theme_teal, Color(0xFF0F766E)),
    Green(R.string.theme_green, Color(0xFF16A34A)),
    Mint(R.string.theme_mint, Color(0xFF36C99A)),
    Orange(R.string.theme_orange, Color(0xFFF97316)),
    Rose(R.string.theme_rose, Color(0xFFF43F7A)),
    Red(R.string.theme_red, Color(0xFFDC2626)),
    Lavender(R.string.theme_lavender, Color(0xFF8B7CF6))
}

class SettingsStore(private val context: Context) {
    private val languageKey = stringPreferencesKey("app_language_selection")
    private val themeKey = stringPreferencesKey("app_theme")
    private val ringerDismissedKey = booleanPreferencesKey("ringer_reminder_dismissed")

    val settings: Flow<AppSettings> = context.settingsDataStore.data
        .catch { emit(androidx.datastore.preferences.core.emptyPreferences()) }
        .map { preferences ->
            AppSettings(
                languageSelection = preferences[languageKey]?.let {
                    runCatching { AppLanguageSelection.valueOf(it) }.getOrNull()
                } ?: AppLanguageSelection.System,
                theme = preferences[themeKey]?.let {
                    runCatching { AppTheme.valueOf(it) }.getOrNull()
                } ?: AppTheme.Blue,
                ringerReminderDismissed = preferences[ringerDismissedKey] ?: false
            )
        }

    suspend fun setLanguage(selection: AppLanguageSelection) {
        context.settingsDataStore.edit { it[languageKey] = selection.name }
    }

    suspend fun setTheme(theme: AppTheme) {
        context.settingsDataStore.edit { it[themeKey] = theme.name }
    }

    suspend fun setRingerReminderDismissed(dismissed: Boolean) {
        context.settingsDataStore.edit { it[ringerDismissedKey] = dismissed }
    }
}
