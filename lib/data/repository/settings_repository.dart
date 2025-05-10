import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/models/user_settings.dart';

/// Persists and retrieves [UserSettings] via SharedPreferences
class SettingsRepository {
  static const _keyHeight = 'height';
  static const _keyAge = 'age';
  static const _keySex = 'sex';
  static const _keyActivityLevel = 'activityLevel';
  static const _keyGoalRate = 'goalRate';

  /// Loads settings, falling back to [UserSettings] defaults if not set.
  Future<UserSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final height = prefs.getDouble(_keyHeight) ?? UserSettings().height;
    final age = prefs.getInt(_keyAge) ?? UserSettings().age;
    final sexIndex = prefs.getInt(_keySex) ?? UserSettings().sex.index;
    final activityIndex =
        prefs.getInt(_keyActivityLevel) ?? UserSettings().activityLevel.index;
    final goalRate = prefs.getDouble(_keyGoalRate) ?? UserSettings().goalRate;

    return UserSettings(
      height: height,
      age: age,
      sex: BiologicalSex.values[sexIndex],
      activityLevel: ActivityLevel.values[activityIndex],
      goalRate: goalRate,
    );
  }

  /// Saves all settings to SharedPreferences
  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyHeight, settings.height);
    await prefs.setInt(_keyAge, settings.age);
    await prefs.setInt(_keySex, settings.sex.index);
    await prefs.setInt(_keyActivityLevel, settings.activityLevel.index);
    await prefs.setDouble(_keyGoalRate, settings.goalRate);
  }
}
