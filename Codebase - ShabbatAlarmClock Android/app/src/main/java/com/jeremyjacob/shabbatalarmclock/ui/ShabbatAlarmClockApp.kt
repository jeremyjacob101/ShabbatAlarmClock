package com.jeremyjacob.shabbatalarmclock.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jeremyjacob.shabbatalarmclock.R
import com.jeremyjacob.shabbatalarmclock.alarm.Alarm
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmNoiseLevel
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmSound
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmSoundResolver
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmUiState
import com.jeremyjacob.shabbatalarmclock.alarm.AlarmViewModel
import com.jeremyjacob.shabbatalarmclock.settings.AppLanguageSelection
import com.jeremyjacob.shabbatalarmclock.settings.AppTheme
import java.text.DateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@Composable
fun ShabbatAlarmClockApp(
    state: AlarmUiState,
    viewModel: AlarmViewModel,
    notificationsAllowed: () -> Boolean,
    requestNotifications: () -> Unit,
    openNotificationSettings: () -> Unit
) {
    val editorAlarm = state.editorAlarm
    if (state.isCreatingAlarm || editorAlarm != null) {
        EditAlarmScreen(
            alarm = editorAlarm,
            notificationsAllowed = notificationsAllowed,
            onSave = viewModel::saveAlarm,
            onDelete = { id -> viewModel.deleteAlarm(id) },
            onClose = viewModel::closeEditor
        )
    } else {
        AlarmListScreen(
            state = state,
            viewModel = viewModel,
            notificationsAllowed = notificationsAllowed,
            requestNotifications = requestNotifications,
            openNotificationSettings = openNotificationSettings
        )
    }

    state.alertMessage?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::dismissAlert,
            title = { Text(stringResource(R.string.notice_title)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = viewModel::dismissAlert) {
                    Text(stringResource(R.string.button_ok))
                }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlarmListScreen(
    state: AlarmUiState,
    viewModel: AlarmViewModel,
    notificationsAllowed: () -> Boolean,
    requestNotifications: () -> Unit,
    openNotificationSettings: () -> Unit
) {
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.alarms_title)) },
                navigationIcon = {
                    SettingsMenu(
                        state = state,
                        viewModel = viewModel,
                        requestNotifications = requestNotifications,
                        openNotificationSettings = openNotificationSettings
                    )
                },
                actions = {
                    IconButton(onClick = viewModel::createAlarm) {
                        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.alarm_add))
                    }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = viewModel::createAlarm,
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text(stringResource(R.string.alarm_add)) }
            )
        }
    ) { padding ->
        if (state.alarms.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.Alarm,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(Modifier.height(16.dp))
                    Text(
                        stringResource(R.string.alarms_empty_title),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        stringResource(R.string.alarms_empty_message),
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = TextAlign.Center
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(state.alarms, key = { it.id }) { alarm ->
                    AlarmRow(
                        alarm = alarm,
                        onEdit = { viewModel.editAlarm(alarm) },
                        onToggle = { checked ->
                            viewModel.toggleAlarm(alarm.id, checked, notificationsAllowed())
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun AlarmRow(
    alarm: Alarm,
    onEdit: () -> Unit,
    onToggle: (Boolean) -> Unit
) {
    val weekdays = stringArrayResource(R.array.weekday_names)
    val time = remember(alarm.hour, alarm.minute) {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
        }
        DateFormat.getTimeInstance(DateFormat.SHORT, Locale.getDefault()).format(calendar.time)
    }
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onEdit)
    ) {
        ListItem(
            headlineContent = {
                Text(time, style = MaterialTheme.typography.headlineMedium)
            },
            supportingContent = {
                Text(
                    listOf(
                        alarm.label.ifBlank { stringResource(R.string.alarm_default_label) },
                        weekdays[alarm.normalizedWeekday - 1],
                        if (alarm.repeatsWeekly) stringResource(R.string.repeat_every_week) else stringResource(R.string.repeat_once),
                        stringResource(AlarmSoundResolver.displayNameRes(alarm.sound)),
                        stringResource(R.string.duration_short, alarm.clampedSoundDurationSeconds)
                    ).joinToString(" • ")
                )
            },
            trailingContent = {
                Switch(checked = alarm.isEnabled, onCheckedChange = onToggle)
            }
        )
    }
}

@Composable
private fun SettingsMenu(
    state: AlarmUiState,
    viewModel: AlarmViewModel,
    requestNotifications: () -> Unit,
    openNotificationSettings: () -> Unit
) {
    val context = LocalContext.current
    var open by remember { mutableStateOf(false) }
    var languageOpen by remember { mutableStateOf(false) }
    var themeOpen by remember { mutableStateOf(false) }

    IconButton(onClick = { open = true }) {
        Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.settings_title))
    }

    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings_notifications_manage)) },
            leadingIcon = { Icon(Icons.Default.Notifications, contentDescription = null) },
            onClick = {
                open = false
                requestNotifications()
                openNotificationSettings()
            }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings_language)) },
            leadingIcon = { Icon(Icons.Default.Language, contentDescription = null) },
            onClick = { languageOpen = true }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings_app_color)) },
            leadingIcon = { Icon(Icons.Default.Palette, contentDescription = null) },
            onClick = { themeOpen = true }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings_leave_rating)) },
            leadingIcon = { Icon(Icons.Default.Star, contentDescription = null) },
            onClick = { open = false }
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings_contact)) },
            leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
            onClick = {
                open = false
                val intent = Intent(Intent.ACTION_SENDTO)
                    .setData(Uri.parse("mailto:"))
                    .putExtra(Intent.EXTRA_SUBJECT, context.getString(R.string.contact_email_subject))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(Intent.createChooser(intent, context.getString(R.string.settings_contact)))
            }
        )
    }

    DropdownMenu(expanded = languageOpen, onDismissRequest = { languageOpen = false }) {
        AppLanguageSelection.entries.forEach { selection ->
            DropdownMenuItem(
                text = { Text(stringResource(selection.titleRes)) },
                trailingIcon = {
                    if (state.settings.languageSelection == selection) Icon(Icons.Default.Check, contentDescription = null)
                },
                onClick = {
                    languageOpen = false
                    open = false
                    viewModel.setLanguage(selection)
                }
            )
        }
    }

    DropdownMenu(expanded = themeOpen, onDismissRequest = { themeOpen = false }) {
        AppTheme.entries.forEach { theme ->
            DropdownMenuItem(
                text = { Text(stringResource(theme.titleRes)) },
                trailingIcon = {
                    if (state.settings.theme == theme) Icon(Icons.Default.Check, contentDescription = null)
                },
                onClick = {
                    themeOpen = false
                    open = false
                    viewModel.setTheme(theme)
                }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditAlarmScreen(
    alarm: Alarm?,
    notificationsAllowed: () -> Boolean,
    onSave: (
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
    ) -> Unit,
    onDelete: (String) -> Unit,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val previewController = remember { SoundPreviewController(context.applicationContext) }
    DisposableEffect(Unit) {
        onDispose { previewController.stop() }
    }

    var hour by remember(alarm?.id) { mutableStateOf(alarm?.hour ?: Alarm.DefaultHour) }
    var minute by remember(alarm?.id) { mutableStateOf(alarm?.minute ?: 0) }
    var label by remember(alarm?.id) { mutableStateOf(alarm?.label ?: context.getString(R.string.alarm_default_label)) }
    var weekday by remember(alarm?.id) { mutableStateOf(alarm?.normalizedWeekday ?: Alarm.DefaultWeekday) }
    var sound by remember(alarm?.id) { mutableStateOf(alarm?.sound ?: AlarmSound.Harp) }
    var duration by remember(alarm?.id) { mutableStateOf(alarm?.clampedSoundDurationSeconds ?: Alarm.DefaultSoundDurationSeconds) }
    var noiseLevel by remember(alarm?.id) { mutableStateOf(alarm?.soundNoiseLevel ?: AlarmNoiseLevel.Soft) }
    var repeatsWeekly by remember(alarm?.id) { mutableStateOf(alarm?.repeatsWeekly ?: false) }
    var autoSnooze by remember(alarm?.id) { mutableStateOf(alarm?.autoSnoozeEnabled ?: false) }
    var isTesting by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(if (alarm == null) stringResource(R.string.alarm_new_title) else stringResource(R.string.alarm_edit_title))
                },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.button_cancel))
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            previewController.stop()
                            onSave(
                                alarm?.id,
                                hour,
                                minute,
                                label.trim().ifBlank { context.getString(R.string.alarm_default_label) },
                                weekday,
                                sound,
                                duration,
                                noiseLevel,
                                repeatsWeekly,
                                autoSnooze,
                                notificationsAllowed()
                            )
                        }
                    ) {
                        Text(stringResource(R.string.button_save))
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                SectionCard(title = stringResource(R.string.schedule_section)) {
                    OptionMenuRow(
                        label = stringResource(R.string.schedule_day_of_week),
                        value = stringArrayResource(R.array.weekday_names)[weekday - 1],
                        options = (1..7).map { it to stringArrayResource(R.array.weekday_names)[it - 1] },
                        onSelected = { weekday = it }
                    )
                    NumberMenuRow(stringResource(R.string.schedule_hour), hour, 0..23) { hour = it }
                    NumberMenuRow(stringResource(R.string.schedule_minute), minute, 0..59) { minute = it }
                }
            }
            item {
                SectionCard(title = stringResource(R.string.repeat_section)) {
                    SwitchRow(stringResource(R.string.repeat_every_week), repeatsWeekly) { repeatsWeekly = it }
                    SwitchRow(stringResource(R.string.repeat_auto_snooze_five_minutes), autoSnooze) { autoSnooze = it }
                }
            }
            item {
                SectionCard(title = stringResource(R.string.sound_section)) {
                    OptionMenuRow(
                        label = stringResource(R.string.sound_alarm),
                        value = stringResource(AlarmSoundResolver.displayNameRes(sound)),
                        options = AlarmSound.entries.map { it to context.getString(AlarmSoundResolver.displayNameRes(it)) },
                        onSelected = { sound = it }
                    )
                    OptionMenuRow(
                        label = stringResource(R.string.sound_length),
                        value = stringResource(R.string.duration_short, duration),
                        options = Alarm.SupportedSoundDurations.map { it to context.getString(R.string.duration_short, it) },
                        onSelected = { duration = it }
                    )
                    OptionMenuRow(
                        label = stringResource(R.string.sound_noise_level),
                        value = stringResource(AlarmSoundResolver.displayNameRes(noiseLevel)),
                        options = AlarmNoiseLevel.entries.map { it to context.getString(AlarmSoundResolver.displayNameRes(it)) },
                        onSelected = { noiseLevel = it }
                    )
                    Button(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            if (isTesting) {
                                previewController.stop()
                                isTesting = false
                            } else {
                                isTesting = true
                                previewController.play(sound, duration, noiseLevel) { isTesting = false }
                            }
                        }
                    ) {
                        Text(if (isTesting) stringResource(R.string.sound_stop) else stringResource(R.string.sound_test))
                    }
                }
            }
            item {
                SectionCard(title = stringResource(R.string.label_section)) {
                    androidx.compose.material3.OutlinedTextField(
                        modifier = Modifier.fillMaxWidth(),
                        value = label,
                        onValueChange = { label = it },
                        singleLine = true,
                        label = { Text(stringResource(R.string.label_section)) }
                    )
                }
            }
            if (alarm != null) {
                item {
                    Button(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = { onDelete(alarm.id) }
                    ) {
                        Icon(Icons.Default.Delete, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text(stringResource(R.string.alarm_delete))
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun NumberMenuRow(label: String, value: Int, range: IntRange, onSelected: (Int) -> Unit) {
    OptionMenuRow(
        label = label,
        value = "%02d".format(value),
        options = range.map { it to "%02d".format(it) },
        onSelected = onSelected
    )
}

@Composable
private fun <T> OptionMenuRow(
    label: String,
    value: String,
    options: List<Pair<T, String>>,
    onSelected: (T) -> Unit
) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { open = true }
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, modifier = Modifier.weight(1f))
            Text(value, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Medium)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { (item, title) ->
                DropdownMenuItem(
                    text = { Text(title) },
                    onClick = {
                        open = false
                        onSelected(item)
                    }
                )
            }
        }
    }
}
