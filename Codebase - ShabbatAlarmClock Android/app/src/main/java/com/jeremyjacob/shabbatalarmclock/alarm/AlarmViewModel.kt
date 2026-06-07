package com.jeremyjacob.shabbatalarmclock.alarm

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.jeremyjacob.shabbatalarmclock.R
import com.jeremyjacob.shabbatalarmclock.settings.AppLanguageSelection
import com.jeremyjacob.shabbatalarmclock.settings.AppSettings
import com.jeremyjacob.shabbatalarmclock.settings.AppTheme
import com.jeremyjacob.shabbatalarmclock.settings.SettingsStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.ZoneId

data class AlarmUiState(
    val alarms: List<Alarm> = emptyList(),
    val settings: AppSettings = AppSettings(),
    val editorAlarm: Alarm? = null,
    val isCreatingAlarm: Boolean = false,
    val alertMessage: String? = null
)

class AlarmViewModel(
    application: Application,
    private val repository: AlarmRepository = AlarmRepository(application.applicationContext),
    private val settingsStore: SettingsStore = SettingsStore(application.applicationContext),
    private val scheduler: AlarmScheduler = AlarmScheduler(application.applicationContext)
) : AndroidViewModel(application) {
    constructor(application: Application) : this(
        application = application,
        repository = AlarmRepository(application.applicationContext),
        settingsStore = SettingsStore(application.applicationContext),
        scheduler = AlarmScheduler(application.applicationContext)
    )

    private val appContext = application.applicationContext
    private val editorAlarm = MutableStateFlow<Alarm?>(null)
    private val isCreatingAlarm = MutableStateFlow(false)
    private val alertMessage = MutableStateFlow<String?>(null)

    val uiState: StateFlow<AlarmUiState> = combine(
        repository.alarms,
        settingsStore.settings,
        editorAlarm,
        isCreatingAlarm,
        alertMessage
    ) { alarms, settings, editing, creating, alert ->
        val normalized = reconcileOneTimeAlarms(
            alarms,
            appContext.getString(R.string.alarm_default_label)
        ).sortedWith(alarmSortComparator())
        AlarmUiState(
            alarms = normalized,
            settings = settings,
            editorAlarm = editing,
            isCreatingAlarm = creating,
            alertMessage = alert
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AlarmUiState())

    init {
        viewModelScope.launch {
            repository.alarms.collect { alarms ->
                val reconciled = reconcileOneTimeAlarms(
                    alarms,
                    appContext.getString(R.string.alarm_default_label)
                ).sortedWith(alarmSortComparator())
                if (reconciled != alarms) {
                    repository.save(reconciled)
                }
                scheduler.replaceScheduledAlarms(reconciled)
            }
        }
    }

    fun createAlarm() {
        isCreatingAlarm.value = true
        editorAlarm.value = null
    }

    fun editAlarm(alarm: Alarm) {
        editorAlarm.value = alarm
        isCreatingAlarm.value = false
    }

    fun closeEditor() {
        editorAlarm.value = null
        isCreatingAlarm.value = false
    }

    fun saveAlarm(
        existingId: String?,
        hour: Int,
        minute: Int,
        label: String,
        weekday: Int,
        sound: AlarmSound,
        durationSeconds: Int,
        noiseLevel: AlarmNoiseLevel,
        repeatsWeekly: Boolean,
        autoSnoozeEnabled: Boolean,
        notificationsAllowed: Boolean
    ) {
        viewModelScope.launch {
            val defaultLabel = appContext.getString(R.string.alarm_default_label)
            val current = uiState.value.alarms.toMutableList()
            val index = existingId?.let { id -> current.indexOfFirst { it.id == id } } ?: -1
            val base = if (index >= 0) current[index] else Alarm(repeatsWeekly = false)
            val scheduledEpochMillis = if (repeatsWeekly) {
                null
            } else {
                base.copy(hour = hour, minute = minute, weekday = weekday, repeatsWeekly = false)
                    .nextTriggerMillis(zoneId = ZoneId.systemDefault())
            }
            val alarm = base.copy(
                hour = hour,
                minute = minute,
                label = Alarm.normalizedLabel(label, defaultLabel),
                isEnabled = if (index >= 0) base.isEnabled && notificationsAllowed else notificationsAllowed,
                weekday = Alarm.normalizeWeekday(weekday),
                sound = sound,
                soundDurationSeconds = Alarm.clampedSoundDuration(durationSeconds),
                soundNoiseLevel = noiseLevel,
                repeatsWeekly = repeatsWeekly,
                autoSnoozeEnabled = autoSnoozeEnabled,
                scheduledEpochMillis = scheduledEpochMillis
            )

            if (index >= 0) {
                current[index] = alarm
            } else {
                current += alarm
            }
            saveAndSchedule(current)
            closeEditor()

            if (!notificationsAllowed) {
                alertMessage.value = appContext.getString(R.string.alerts_notifications_saved_but_disabled)
            }
        }
    }

    fun toggleAlarm(id: String, enabled: Boolean, notificationsAllowed: Boolean) {
        viewModelScope.launch {
            val current = uiState.value.alarms.toMutableList()
            val index = current.indexOfFirst { it.id == id }
            if (index < 0) return@launch

            if (enabled && !notificationsAllowed) {
                current[index] = current[index].copy(isEnabled = false)
                saveAndSchedule(current)
                alertMessage.value = appContext.getString(R.string.alerts_notifications_disabled_for_enable)
                return@launch
            }

            current[index] = current[index].copy(
                isEnabled = enabled,
                scheduledEpochMillis = if (enabled && !current[index].repeatsWeekly) {
                    current[index].nextTriggerMillis()
                } else {
                    current[index].scheduledEpochMillis
                }
            )
            saveAndSchedule(current)
        }
    }

    fun deleteAlarm(id: String) {
        viewModelScope.launch {
            saveAndSchedule(uiState.value.alarms.filterNot { it.id == id })
            if (editorAlarm.value?.id == id) closeEditor()
        }
    }

    fun setLanguage(selection: AppLanguageSelection) {
        viewModelScope.launch { settingsStore.setLanguage(selection) }
    }

    fun setTheme(theme: AppTheme) {
        viewModelScope.launch { settingsStore.setTheme(theme) }
    }

    fun dismissAlert() {
        alertMessage.value = null
    }

    private suspend fun saveAndSchedule(alarms: List<Alarm>) {
        val normalized = reconcileOneTimeAlarms(
            alarms,
            appContext.getString(R.string.alarm_default_label)
        ).sortedWith(alarmSortComparator())
        repository.save(normalized)
        if (scheduler.canScheduleExactAlarms()) {
            scheduler.replaceScheduledAlarms(normalized)
        } else {
            scheduler.clearScheduledAlarms()
            alertMessage.value = appContext.getString(R.string.alerts_notifications_schedule_failed)
        }
    }
}
