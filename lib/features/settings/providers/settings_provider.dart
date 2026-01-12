// lib/features/settings/providers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:work_hours_tracker/core/services/backup_service.dart';
import 'package:work_hours_tracker/core/services/notification_service.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';
import 'package:work_hours_tracker/data/repository/preferences_repository.dart';

// 1. Provider para instância assíncrona do SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// 2. Provider do Repositório (depende do SharedPreferences)
final preferencesRepositoryProvider = Provider<PreferencesRepository?>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return prefsAsync.when(
    data: (prefs) => PreferencesRepository(prefs),
    loading: () => null,
    error: (_, __) => null,
  );
});

// 3. Estado das Definições
class SettingsState {
  final double hourlyRate;
  final String currency;
  final double holidayMultiplier;
  final List<int> restDays;
  final int appTheme; // 0=Auto, 1=Light, 2=Dark
  final TimeOfDay? notificationTime;
  final bool isLoading;

  SettingsState({
    this.hourlyRate = 0.0,
    this.currency = '€',
    this.holidayMultiplier = 1.0,
    this.restDays = const [6, 7],
    this.appTheme = 0,
    this.notificationTime,
    this.isLoading = true,
  });

  SettingsState copyWith({
    double? hourlyRate,
    String? currency,
    double? holidayMultiplier,
    List<int>? restDays,
    int? appTheme,
    TimeOfDay? notificationTime,
    bool forceNotificationTimeNull = false,
    bool? isLoading,
  }) {
    return SettingsState(
      hourlyRate: hourlyRate ?? this.hourlyRate,
      currency: currency ?? this.currency,
      holidayMultiplier: holidayMultiplier ?? this.holidayMultiplier,
      restDays: restDays ?? this.restDays,
      appTheme: appTheme ?? this.appTheme,
      notificationTime: forceNotificationTimeNull ? null : (notificationTime ?? this.notificationTime),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 4. ViewModel
class SettingsViewModel extends StateNotifier<SettingsState> {
  final PreferencesRepository? _repo;
  final AppDatabase _db; // Necessário para Backup/Restore

  SettingsViewModel(this._repo, this._db) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    if (_repo == null) {
      state = SettingsState(isLoading: true);
      return;
    }

    TimeOfDay? time;
    final timeStr = _repo.getNotificationTime();
    if (timeStr != null) {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    
    state = SettingsState(
      hourlyRate: _repo.getHourlyRate(),
      currency: _repo.getCurrency(),
      holidayMultiplier: _repo.getHolidayMultiplier(),
      restDays: _repo.getRestDays(),
      appTheme: _repo.getAppTheme(),
      notificationTime: time,
      isLoading: false,
    );
  }

  Future<void> updateHourlyRate(double value) async {
    await _repo?.setHourlyRate(value);
    state = state.copyWith(hourlyRate: value);
  }

  Future<void> updateCurrency(String value) async {
    await _repo?.setCurrency(value);
    state = state.copyWith(currency: value);
  }

  Future<void> updateHolidayMultiplier(double value) async {
    await _repo?.setHolidayMultiplier(value);
    state = state.copyWith(holidayMultiplier: value);
  }

  Future<void> toggleRestDay(int dayValue) async {
    final currentDays = List<int>.from(state.restDays);
    if (currentDays.contains(dayValue)) {
      currentDays.remove(dayValue);
    } else {
      currentDays.add(dayValue);
    }
    await _repo?.setRestDays(currentDays);
    state = state.copyWith(restDays: currentDays);
  }

  Future<void> updateAppTheme(int value) async {
    await _repo?.setAppTheme(value);
    state = state.copyWith(appTheme: value);
  }

  Future<void> updateNotificationTime(TimeOfDay? time) async {
    if (time == null) {
      await _repo?.setNotificationTime(null);
      await NotificationService().cancelNotification(0);
      state = state.copyWith(forceNotificationTimeNull: true);
    } else {
      final timeStr = '${time.hour}:${time.minute}';
      await _repo?.setNotificationTime(timeStr);
      
      await NotificationService().requestPermissions();
      await NotificationService().scheduleDailyNotification(
        id: 0,
        title: 'Registar Horas',
        body: 'Não te esqueças de registar o teu dia!',
        time: time,
      );
      
      state = state.copyWith(notificationTime: time);
    }
  }

  // --- MÉTODOS DE BACKUP ---

  Future<void> createBackup() async {
    try {
      state = state.copyWith(isLoading: true);
      final entries = await _db.getAllEntries();
      await BackupService().exportData(entries);
    } catch (e) {
      debugPrint("Erro no backup: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<int> restoreBackup() async {
    try {
      state = state.copyWith(isLoading: true);
      final entries = await BackupService().pickAndParseBackup();
      
      if (entries.isNotEmpty) {
        await _db.insertBatchWorkEntries(entries);
        return entries.length;
      }
      return 0;
    } catch (e) {
      debugPrint("Erro no restore: $e");
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

// 5. O Provider principal
final settingsViewModelProvider = StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
  final repo = ref.watch(preferencesRepositoryProvider);
  final db = ref.watch(databaseProvider); // Injeção da DB
  return SettingsViewModel(repo, db);
});