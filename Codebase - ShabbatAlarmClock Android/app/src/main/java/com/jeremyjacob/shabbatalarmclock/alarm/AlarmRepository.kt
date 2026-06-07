package com.jeremyjacob.shabbatalarmclock.alarm

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

private val Context.alarmDataStore by preferencesDataStore(name = "alarms")

class AlarmRepository(private val context: Context) {
    private val alarmsKey = stringPreferencesKey("alarms_json")
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    val alarms: Flow<List<Alarm>> = context.alarmDataStore.data
        .catch { emit(androidx.datastore.preferences.core.emptyPreferences()) }
        .map { preferences ->
            val encoded = preferences[alarmsKey] ?: return@map emptyList()
            runCatching {
                json.decodeFromString(ListSerializer(Alarm.serializer()), encoded)
            }.getOrElse { emptyList() }
        }

    suspend fun save(alarms: List<Alarm>) {
        context.alarmDataStore.edit { preferences ->
            preferences[alarmsKey] = json.encodeToString(ListSerializer(Alarm.serializer()), alarms)
        }
    }
}
