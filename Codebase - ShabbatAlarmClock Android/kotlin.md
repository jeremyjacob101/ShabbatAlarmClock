# Shabbat Alarm Clock Android Kotlin Build Guide

This folder is intentionally not an Android project yet. It is a handoff document for a future Codex thread to build a native Android/Kotlin version that follows the existing iOS app closely while still feeling like a proper Android app.

The iOS reference implementation now lives in:

```text
Codebase - ShabbatAlarmClock iOS/
├── ShabbatAlarmClockiOS/
└── ShabbatAlarmClockiOS.xcodeproj/
```

Use the Swift app as the behavioral source of truth. Do not copy Swift code mechanically. Rebuild the app using native Android architecture, Kotlin, Jetpack Compose, Android notification/alarm APIs, and Android resource/localization conventions.

## Product Goal

Build a local-first Shabbat-oriented alarm app for Android.

The Android app should let a user:

1. View all saved alarms.
2. Add a new alarm for a selected weekday and time.
3. Edit an existing alarm.
4. Delete alarms.
5. Enable or disable each alarm.
6. Choose whether an alarm repeats weekly or fires once.
7. Choose a bundled sound.
8. Choose a sound duration.
9. Choose a noise level.
10. Enable optional 5-minute auto-snooze.
11. Preview the selected sound in the app.
12. Use the app in English or Hebrew.
13. See correct right-to-left layout in Hebrew.
14. Choose an app accent/theme color.
15. Receive local alarm notifications without accounts, cloud sync, or a backend.

The Android implementation should be native Kotlin, not a web view and not a cross-platform port.

## Reference iOS Behavior

Before coding, inspect these iOS files:

```text
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/Models/Alarm.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/Models/AlarmSound.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/Models/AlarmNoiseLevel.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/ViewModels/AlarmListViewModel.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/Services/NotificationServiceError.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/Views/AlarmListView.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/Views/AddAlarmView.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/AppLocalization.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/AppTheme.swift
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/en.lproj/Localizable.strings
Codebase - ShabbatAlarmClock iOS/ShabbatAlarmClockiOS/he.lproj/Localizable.strings
```

Key behavior to preserve:

1. Alarms are local-only.
2. Alarms are sorted by weekday/time in a predictable order.
3. Empty labels fall back to a localized default label.
4. A one-time alarm stores its next scheduled date and disables itself after the final expected occurrence has passed.
5. A repeating alarm schedules weekly.
6. Auto-snooze schedules a second occurrence 5 minutes after the primary alarm.
7. Supported sound durations are 10, 20, 30, 40, 50, and 60 seconds.
8. Durations above 30 seconds are represented by multiple notification/sound segments because platforms may limit custom notification sound length.
9. Sounds are `chimes`, `alarm`, and `harp`.
10. Noise levels are `soft` and `loud`.
11. Default sound is `harp`.
12. Default noise level is `soft`.
13. Default sound duration is 20 seconds.
14. Default new alarm time is 8:00 AM.
15. Default new alarm weekday is Saturday in the iOS app's current model.
16. Default new alarms are one-time, not weekly.
17. Notification permission state affects whether an alarm can be enabled.
18. Duplicate overlapping alarm slots should not create competing alerts for the same exact occurrence.
19. English and Hebrew are first-class app languages.
20. Hebrew must force right-to-left layout.

## Recommended Android Stack

Use:

1. Kotlin.
2. Jetpack Compose with Material 3.
3. A single-activity architecture.
4. AndroidX Navigation Compose if separate screens are useful.
5. ViewModel plus Kotlin coroutines and StateFlow.
6. DataStore or Room for persistence.
7. kotlinx.serialization for structured alarm persistence if using DataStore.
8. AlarmManager for exact local alarm triggers.
9. BroadcastReceiver for alarm firing.
10. NotificationManager for alarm notifications.
11. MediaPlayer, ExoPlayer, or SoundPool for in-app preview.
12. Android string resources for localization.

Prefer DataStore for the first version unless there is a strong reason to use Room. The alarm model is small and local.

## Project Setup Steps

1. Create a new Android Studio project inside this folder.
2. Use package name `com.jeremyjacob.shabbatalarmclock` unless the user asks for a different application id.
3. Use minSdk 26 or higher. Prefer minSdk 31+ only if exact alarm behavior and device support have been considered.
4. Enable Jetpack Compose.
5. Use Kotlin DSL Gradle files.
6. Add dependencies for:
   - Compose Material 3
   - lifecycle-viewmodel-compose
   - kotlinx-coroutines-android
   - kotlinx-serialization-json
   - datastore-preferences or datastore-core
   - navigation-compose if needed
7. Create a simple app icon from the existing shared logo or Android adaptive-icon assets later. Do not block core behavior on final icon polish.

## Suggested Android File Structure

Use a simple feature-oriented structure:

```text
app/src/main/java/com/jeremyjacob/shabbatalarmclock/
├── MainActivity.kt
├── ShabbatAlarmClockApp.kt
├── alarm/
│   ├── Alarm.kt
│   ├── AlarmNoiseLevel.kt
│   ├── AlarmRepository.kt
│   ├── AlarmScheduler.kt
│   ├── AlarmSound.kt
│   ├── AlarmReceiver.kt
│   └── AlarmViewModel.kt
├── localization/
│   ├── AppLanguage.kt
│   └── AppLocaleController.kt
├── settings/
│   ├── AppTheme.kt
│   └── SettingsStore.kt
└── ui/
    ├── AlarmListScreen.kt
    ├── EditAlarmScreen.kt
    ├── AlarmRow.kt
    ├── SoundPreviewController.kt
    └── components/
```

Resources:

```text
app/src/main/res/
├── raw/
│   ├── chimes_10s_louder.wav
│   ├── chimes_10s_super_loud.wav
│   ├── ...
│   └── harp_30s_super_loud.wav
├── values/strings.xml
├── values-he/strings.xml
├── values/colors.xml
└── mipmap-anydpi-v26/
```

Copy or regenerate the alarm sound files from the iOS reference only after confirming licensing and desired Android packaging. The Android app should use `res/raw` names with lowercase letters, digits, and underscores.

## Alarm Data Model

Create a Kotlin model equivalent to the iOS `Alarm`.

Fields:

```kotlin
@Serializable
data class Alarm(
    val id: String = UUID.randomUUID().toString(),
    val hour: Int,
    val minute: Int,
    val label: String,
    val isEnabled: Boolean = true,
    val weekday: Int,
    val sound: AlarmSound = AlarmSound.Harp,
    val soundDurationSeconds: Int = 20,
    val soundNoiseLevel: AlarmNoiseLevel = AlarmNoiseLevel.Soft,
    val repeatsWeekly: Boolean = true,
    val autoSnoozeEnabled: Boolean = false,
    val scheduledEpochMillis: Long? = null
)
```

Use Android/Java time APIs for scheduling calculations:

1. Store `hour` and `minute` directly instead of storing a full date object for repeating alarms.
2. Store `weekday` using a consistent app convention.
3. Recommended convention: `1 = Sunday`, `2 = Monday`, ..., `7 = Saturday`, matching the iOS model and Foundation calendar behavior.
4. Store one-time `scheduledEpochMillis` as the exact next primary fire date.

Constants:

```kotlin
val supportedSoundDurations = listOf(10, 20, 30, 40, 50, 60)
const val defaultSoundDurationSeconds = 20
const val previewSoundDurationSeconds = 10
const val autoSnoozeMinutes = 5
```

Implement:

1. `clampedSoundDuration(value: Int): Int`
2. `nextTriggerMillis(referenceMillis: Long, zoneId: ZoneId): Long`
3. `primaryFireMillis(referenceMillis: Long, zoneId: ZoneId): Long?`
4. `notificationOccurrenceMillis(...)`
5. `oneTimeExpirationMillis(...)`

Match the iOS segmentation:

```text
10 -> [(0, 10)]
20 -> [(0, 20)]
30 -> [(0, 30)]
40 -> [(0, 30), (30, 10)]
50 -> [(0, 30), (30, 20)]
60 -> [(0, 30), (30, 30)]
```

Each pair is `(offsetSeconds, durationSeconds)`.

## Sound Model

Create:

```kotlin
enum class AlarmSound {
    Chimes,
    Alarm,
    Harp
}

enum class AlarmNoiseLevel {
    Soft,
    Loud
}
```

Map display names through string resources, not hard-coded Kotlin strings.

Resource naming pattern:

```text
{sound}_{duration}s_{suffix}
```

Examples:

```text
harp_20s_louder
harp_20s_super_loud
alarm_30s_louder
chimes_10s_super_loud
```

Noise level suffix behavior:

1. `Soft` should prefer `louder`.
2. `Loud` should prefer `super_loud`, then fall back to `louder` if needed.

## Persistence

Use DataStore with a JSON payload or Proto DataStore.

For a first implementation:

1. Store alarms as a JSON array string in DataStore.
2. Store selected language.
3. Store selected theme.
4. Store whether the ringer reminder has been dismissed.

Suggested keys:

```text
alarms_json
app_language_selection
app_theme
ringer_reminder_dismissed
```

When loading:

1. Decode alarms.
2. Clamp invalid sound durations.
3. Normalize invalid weekdays.
4. Map old or unknown sound values to defaults if needed.
5. Sort alarms.
6. Reconcile expired one-time alarms.

## Scheduling Strategy

Android alarm delivery is different from iOS notification scheduling. Build the scheduler around Android realities instead of imitating iOS APIs.

Use `AlarmManager`:

1. For each enabled alarm occurrence, schedule an exact alarm if allowed.
2. Use `setExactAndAllowWhileIdle` when exact alarm permission and device policy allow it.
3. Use `setAlarmClock` if the product should behave like a user-visible alarm clock and appear in system surfaces.
4. Use a fallback path for devices where exact alarms are restricted.

Permissions to consider:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Important: Android exact alarm policy changes by API level and app category. The future implementation thread must verify the current Google Play policy and Android SDK behavior before choosing final manifest permissions. Alarm-clock apps are often treated differently from generic reminder apps.

Scheduler responsibilities:

1. Cancel all pending alarms managed by this app before replacing the schedule.
2. Schedule enabled alarms only.
3. Schedule primary and auto-snooze occurrences.
4. Split longer sound durations into multiple scheduled occurrences if the notification sound duration limit requires it.
5. Avoid duplicate occurrences for the same weekday/time/second.
6. Give repeating weekly alarms priority over one-time alarms in the same slot, matching the iOS dedupe intent.
7. Reschedule repeating alarms after each receiver fires.
8. Reconcile one-time alarms after app launch and after alarm delivery.
9. Re-register alarms after device reboot.

Add a `BOOT_COMPLETED` receiver:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

The boot receiver should reload stored alarms and reschedule enabled alarms.

## Notification Behavior

Create a notification channel for alarms:

```text
id: alarms
importance: IMPORTANCE_HIGH
category: NotificationCompat.CATEGORY_ALARM
priority: PRIORITY_HIGH
visibility: VISIBILITY_PUBLIC
```

The alarm receiver should:

1. Resolve the alarm by id.
2. Show a high-priority notification.
3. Use the selected sound resource if the platform supports it cleanly.
4. Include localized title/body text.
5. Launch the app when tapped.
6. Update or reschedule state after firing.

Consider whether the Android version needs a full-screen alarm UI. The iOS version uses notifications and bundled sounds, not a custom ringing screen. For parity, begin with notifications and sound. Add full-screen intent only if the user explicitly wants it or Android delivery proves insufficient.

## Permission UX

Android requires careful permission prompts.

Implement flows for:

1. `POST_NOTIFICATIONS` on Android 13+.
2. Exact alarm capability on Android 12+ where relevant.
3. Opening app notification settings when permission is denied.
4. Warning that alarms are saved but disabled if notification/alarm permissions are unavailable.

Match the iOS spirit:

1. Users can create alarms even if permission is unavailable.
2. Alarms should remain disabled until permissions are granted.
3. Enabling an alarm should verify permission first.
4. Use clear, localized alerts.

## One-Time Alarm Reconciliation

On app start, app foreground, and after alarm delivery:

1. Find one-time alarms.
2. Compute each alarm's expiration time.
3. If now is after expiration, set `isEnabled = false`.
4. Persist the updated alarms.
5. Refresh the schedule.

Expiration should include:

1. The primary occurrence.
2. The 5-minute auto-snooze occurrence if enabled.
3. The final sound segment offset.

Example: one-time alarm at 8:00, auto-snooze enabled, 60-second sound.

```text
primary occurrence: 8:00
snooze occurrence: 8:05
last segment starts: 8:05:30
expiration: after 8:05:30
```

The iOS implementation uses the start of the final segment as the expiration reference, not necessarily the end of the sound. Preserve that behavior unless deliberately improving it and documenting the difference.

## Duplicate Slot Handling

The iOS notification service deduplicates scheduled alerts by slot.

Implement comparable Android logic:

1. Build candidate occurrences for every enabled alarm.
2. For weekly alarms, key by weekday/hour/minute/second.
3. For one-time alarms, key by exact timestamp plus weekday/time.
4. If multiple alarms collide, choose a representative by stable sorting.
5. Do not schedule a one-time occurrence if a weekly occurrence already owns the same weekday/time slot.

Document the chosen tie-breaker. A reasonable tie-breaker is:

1. Earlier next fire date first.
2. Existing stored order or creation id for stability.
3. Repeating weekly before one-time for exact slot conflicts.

## UI Requirements

Use Jetpack Compose Material 3.

Main screen:

1. Top app bar titled with localized "Alarms".
2. Settings menu button.
3. Add button.
4. Empty state when there are no alarms.
5. Alarm list when alarms exist.
6. Each row shows time, weekday, label, repeat/one-time status, sound summary, and enabled switch.
7. Tapping a row opens edit.
8. Swipe-to-delete is optional but useful.

Add/edit screen:

1. Day-of-week picker.
2. Time picker.
3. Repeat weekly switch.
4. Auto-snooze switch.
5. Sound picker.
6. Sound duration control with fixed steps: 10, 20, 30, 40, 50, 60.
7. Noise level segmented choice or radio buttons.
8. Test/stop sound action.
9. Label text field.
10. Save and cancel actions.
11. Delete button in edit mode.

Settings menu:

1. Notification action: enable/manage notifications depending on permission state.
2. Language menu: system, English, Hebrew.
3. App color menu.
4. Leave rating action if an Android app listing exists later.
5. Contact action.

Theme colors:

1. Standard
2. Blue
3. Teal
4. Green
5. Mint
6. Orange
7. Rose
8. Red
9. Lavender

The UI should be familiar Android Material, not a SwiftUI clone. Preserve product behavior, labels, and rhythm while using Android-native controls.

## Localization and RTL

Create:

```text
app/src/main/res/values/strings.xml
app/src/main/res/values-he/strings.xml
```

Translate every visible string. Use the iOS `Localizable.strings` files as the starting source.

Language modes:

1. System
2. English
3. Hebrew

For app-level language switching:

1. On Android 13+, prefer per-app language APIs where appropriate.
2. For in-app override, persist the choice and apply locale through AppCompat or a Compose-compatible locale controller.
3. Ensure Hebrew uses RTL layout.
4. Check number/time formatting under both languages.

Test:

1. English, light mode.
2. English, dark mode.
3. Hebrew, light mode.
4. Hebrew, dark mode.
5. Long translated strings on small screens.

## Sound Preview

Implement a `SoundPreviewController`:

1. Stops any current preview before starting a new one.
2. Resolves the selected sound/noise/duration resource.
3. Uses the 10-second preview duration where possible.
4. Updates UI state while playing.
5. Stops playback on screen dismissal.
6. Handles missing resource files gracefully.

If using MediaPlayer:

1. Keep lifecycle ownership clear.
2. Release the player after playback.
3. Avoid leaking an Activity context.

## Suggested Implementation Order

1. Create the Android project and confirm it builds.
2. Add core model enums and the `Alarm` data class.
3. Add date/time calculation utilities and unit tests.
4. Add DataStore persistence.
5. Build the ViewModel with in-memory CRUD first.
6. Wire persistence into the ViewModel.
7. Build the main alarm list UI.
8. Build add/edit UI.
9. Add localization resources for English and Hebrew.
10. Add theme selection.
11. Add sound resources and preview playback.
12. Add notification permission flow.
13. Add AlarmManager scheduling.
14. Add BroadcastReceiver delivery.
15. Add boot rescheduling.
16. Add one-time alarm reconciliation.
17. Add duplicate slot handling.
18. Test on emulator and at least one physical device if available.
19. Compare behavior against the iOS app.
20. Polish copy, spacing, empty states, and error alerts.

## Tests To Write

Unit tests:

1. `clampedSoundDuration`.
2. Next trigger date for each weekday.
3. Next trigger rolls to next week when the selected time already passed.
4. One-time scheduled date is preserved.
5. One-time expiration with and without auto-snooze.
6. Sound segment mapping for 10 through 60 seconds.
7. Invalid weekday normalization.
8. Empty label normalization.
9. Duplicate slot representative selection.
10. Alarm sorting.

Instrumented/manual tests:

1. Create an alarm and confirm it persists after app restart.
2. Toggle an alarm off and confirm the pending Android alarm is canceled.
3. Toggle an alarm on and confirm permissions are checked.
4. Fire a one-time alarm and confirm it disables after expiration.
5. Fire a weekly alarm and confirm it reschedules.
6. Enable auto-snooze and confirm the second occurrence.
7. Preview every sound/noise combination.
8. Switch to Hebrew and verify RTL layout.
9. Reboot device/emulator and confirm enabled alarms reschedule.
10. Deny notifications and confirm the app explains the disabled state.

## Parity Checklist

Before calling the Android version complete, verify:

1. App launches to the alarm list.
2. Empty state appears with no alarms.
3. Add flow creates an alarm.
4. Edit flow updates an alarm.
5. Delete flow removes an alarm.
6. Toggle flow enables/disables scheduling.
7. Weekly alarms repeat.
8. One-time alarms disable after firing.
9. Auto-snooze works.
10. Sounds match the selected sound and noise level.
11. Durations map to the same segment behavior as iOS.
12. English UI is complete.
13. Hebrew UI is complete and RTL.
14. Theme color persists.
15. Permission denial is handled.
16. Device reboot rescheduling works.
17. No backend, login, or sync has been introduced.

## Important Android Differences To Respect

Android is more restrictive and more variable than iOS for alarms.

A future implementation thread must actively verify:

1. Exact alarm permission requirements for the target SDK.
2. Google Play policy for exact alarm permissions.
3. Notification runtime permission behavior on Android 13+.
4. OEM battery optimization behavior.
5. Whether a foreground service or full-screen intent is justified.
6. Whether bundled custom notification sounds play for the desired duration on target devices.

If exact alarms are unavailable, the app should explain the limitation rather than silently pretending alarms are dependable.

## Definition Of Done

The Android app is done when:

1. It is a buildable native Kotlin Android app in this folder.
2. It has no dependency on the iOS project at runtime.
3. It preserves the existing product behavior closely.
4. It uses Android-native UI and system APIs.
5. It has English and Hebrew resources.
6. It handles notification and exact alarm permissions honestly.
7. It persists all user settings locally.
8. It includes focused unit tests for scheduling behavior.
9. Its README/build notes explain how to run it from Android Studio and the command line.

