package com.jeremyjacob.shabbatalarmclock

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmViewModel
import com.jeremyjacob.shabbatalarmclock.settings.AppLanguageSelection
import com.jeremyjacob.shabbatalarmclock.ui.ShabbatAlarmClockApp
import com.jeremyjacob.shabbatalarmclock.ui.ShabbatAlarmClockTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            val viewModel: AlarmViewModel = viewModel()
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            val language = resolvedLanguage(state.settings.languageSelection)
            val localizedContext = LocalContext.current.localized(language)
            val layoutDirection = if (language == "he") LayoutDirection.Rtl else LayoutDirection.Ltr
            val notificationPermissionLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.RequestPermission()
            ) { }

            CompositionLocalProvider(
                LocalContext provides localizedContext,
                LocalLayoutDirection provides layoutDirection
            ) {
                ShabbatAlarmClockTheme(theme = state.settings.theme) {
                    ShabbatAlarmClockApp(
                        state = state,
                        viewModel = viewModel,
                        notificationsAllowed = { notificationsAllowed() },
                        requestNotifications = {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            }
                        },
                        openNotificationSettings = { openNotificationSettings() }
                    )
                }
            }
        }
    }

    private fun notificationsAllowed(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:$packageName"))
        startActivity(intent)
    }

    private fun resolvedLanguage(selection: AppLanguageSelection): String = when (selection) {
        AppLanguageSelection.English -> "en"
        AppLanguageSelection.Hebrew -> "he"
        AppLanguageSelection.System -> if (java.util.Locale.getDefault().language == "he" || java.util.Locale.getDefault().language == "iw") {
            "he"
        } else {
            "en"
        }
    }
}

private fun Context.localized(language: String): Context {
    val configuration = Configuration(resources.configuration)
    configuration.setLocale(java.util.Locale(language))
    configuration.setLayoutDirection(java.util.Locale(language))
    return createConfigurationContext(configuration)
}
