// lib/data/repository/preferences_repository.dart

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesRepository {
  final SharedPreferences _prefs;

  PreferencesRepository(this._prefs);

  static const _keyHourlyRate = 'hourly_rate';
  static const _keyCurrency = 'currency';
  static const _keyHolidayMultiplier = 'holiday_multiplier';
  static const _keyRestDays = 'rest_days'; // Guardado como lista de int (1=Seg, 7=Dom)
  static const _keyAppTheme = 'app_theme'; // 0=Auto, 1=Claro, 2=Escuro
  static const _keyNotificationTime = 'notification_time'; // Guardado como "HH:mm"

  // --- Getters ---
  
  double getHourlyRate() => _prefs.getDouble(_keyHourlyRate) ?? 0.0;
  
  String getCurrency() => _prefs.getString(_keyCurrency) ?? '€';
  
  double getHolidayMultiplier() => _prefs.getDouble(_keyHolidayMultiplier) ?? 1.0;
  
  List<int> getRestDays() {
    final list = _prefs.getStringList(_keyRestDays);
    if (list == null) return [6, 7]; // Default: Sábado e Domingo
    return list.map((e) => int.parse(e)).toList();
  }

  int getAppTheme() => _prefs.getInt(_keyAppTheme) ?? 0;

  String? getNotificationTime() => _prefs.getString(_keyNotificationTime);

  // --- Setters ---

  Future<void> setHourlyRate(double value) => _prefs.setDouble(_keyHourlyRate, value);

  Future<void> setCurrency(String value) => _prefs.setString(_keyCurrency, value);

  Future<void> setHolidayMultiplier(double value) => _prefs.setDouble(_keyHolidayMultiplier, value);

  Future<void> setRestDays(List<int> days) {
    return _prefs.setStringList(_keyRestDays, days.map((e) => e.toString()).toList());
  }

  Future<void> setAppTheme(int value) => _prefs.setInt(_keyAppTheme, value);

  Future<void> setNotificationTime(String? time) async {
    if (time == null) {
      await _prefs.remove(_keyNotificationTime);
    } else {
      await _prefs.setString(_keyNotificationTime, time);
    }
  }
}