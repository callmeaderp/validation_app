import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Persists and retrieves [UserSettings] via SharedPreferences
class SettingsRepository {
  static const _keyHeight = 'height';
  static const _keyAge = 'age';
  static const _keySex = 'sex';
  static const _keyActivityLevel = 'activityLevel';
  static const _keyGoalRate = 'goalRate';

  static const _keyWeightAlpha = 'weightAlpha';
  static const _keyWeightAlphaMin = 'weightAlphaMin';
  static const _keyWeightAlphaMax = 'weightAlphaMax';
  static const _keyCalorieAlpha = 'calorieAlpha';
  static const _keyCalorieAlphaMin = 'calorieAlphaMin';
  static const _keyCalorieAlphaMax = 'calorieAlphaMax';
  static const _keyTrendSmoothingDays = 'trendSmoothingDays';

  /// Loads settings, falling back to [UserSettings] defaults if not set.
  Future<UserSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final height = prefs.getDouble(_keyHeight) ?? UserSettings().height;
    final age = prefs.getInt(_keyAge) ?? UserSettings().age;
    final sexIndex = prefs.getInt(_keySex) ?? UserSettings().sex.index;
    final activityIndex =
        prefs.getInt(_keyActivityLevel) ?? UserSettings().activityLevel.index;
    final goalRate = prefs.getDouble(_keyGoalRate) ?? UserSettings().goalRate;

    // Load algorithm parameters if they exist
    final weightAlpha =
        prefs.getDouble(_keyWeightAlpha) ?? UserSettings().weightAlpha;
    final weightAlphaMin =
        prefs.getDouble(_keyWeightAlphaMin) ?? UserSettings().weightAlphaMin;
    final weightAlphaMax =
        prefs.getDouble(_keyWeightAlphaMax) ?? UserSettings().weightAlphaMax;
    final calorieAlpha =
        prefs.getDouble(_keyCalorieAlpha) ?? UserSettings().calorieAlpha;
    final calorieAlphaMin =
        prefs.getDouble(_keyCalorieAlphaMin) ?? UserSettings().calorieAlphaMin;
    final calorieAlphaMax =
        prefs.getDouble(_keyCalorieAlphaMax) ?? UserSettings().calorieAlphaMax;
    final trendSmoothingDays =
        prefs.getInt(_keyTrendSmoothingDays) ??
        UserSettings().trendSmoothingDays;

    return UserSettings(
      height: height,
      age: age,
      sex: BiologicalSex.values[sexIndex],
      activityLevel: ActivityLevel.values[activityIndex],
      goalRate: goalRate,
      weightAlpha: weightAlpha,
      weightAlphaMin: weightAlphaMin,
      weightAlphaMax: weightAlphaMax,
      calorieAlpha: calorieAlpha,
      calorieAlphaMin: calorieAlphaMin,
      calorieAlphaMax: calorieAlphaMax,
      trendSmoothingDays: trendSmoothingDays,
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

    // Save algorithm parameters
    await prefs.setDouble(_keyWeightAlpha, settings.weightAlpha);
    await prefs.setDouble(_keyWeightAlphaMin, settings.weightAlphaMin);
    await prefs.setDouble(_keyWeightAlphaMax, settings.weightAlphaMax);
    await prefs.setDouble(_keyCalorieAlpha, settings.calorieAlpha);
    await prefs.setDouble(_keyCalorieAlphaMin, settings.calorieAlphaMin);
    await prefs.setDouble(_keyCalorieAlphaMax, settings.calorieAlphaMax);
    await prefs.setInt(_keyTrendSmoothingDays, settings.trendSmoothingDays);
  }

  /// Resets algorithm parameters to defaults
  Future<void> resetAlgorithmParameters() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultSettings = UserSettings();

    // Keep user profile settings, reset only algorithm parameters
    await prefs.setDouble(_keyWeightAlpha, defaultSettings.weightAlpha);
    await prefs.setDouble(_keyWeightAlphaMin, defaultSettings.weightAlphaMin);
    await prefs.setDouble(_keyWeightAlphaMax, defaultSettings.weightAlphaMax);
    await prefs.setDouble(_keyCalorieAlpha, defaultSettings.calorieAlpha);
    await prefs.setDouble(_keyCalorieAlphaMin, defaultSettings.calorieAlphaMin);
    await prefs.setDouble(_keyCalorieAlphaMax, defaultSettings.calorieAlphaMax);
    await prefs.setInt(
      _keyTrendSmoothingDays,
      defaultSettings.trendSmoothingDays,
    );
  }

  /// Exports basic log data as CSV string
  Future<String> exportBasicCsv(List<LogEntry> entries) async {
    // Header row
    final csvBuffer = StringBuffer('Date,Weight,PreviousDayCalories\n');

    // Sort entries by date (oldest first) before exporting
    final sortedEntries = List<LogEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Add each entry as a row
    for (final entry in sortedEntries) {
      csvBuffer.write('${entry.date},');
      csvBuffer.write('${entry.rawWeight ?? ''},');
      csvBuffer.write('${entry.rawPreviousDayCalories ?? ''}\n');
    }

    return csvBuffer.toString();
  }

  /// Exports detailed log data as JSON string
  Future<String> exportDetailedJson(
    List<LogEntry> entries,
    UserSettings settings,
  ) async {
    final calculationEngine = CalculationEngine();
    final jsonList = [];

    // Process entries one by one to get historical calculations
    List<LogEntry> processedEntries = [];
    for (int i = 0; i < entries.length; i++) {
      processedEntries.add(entries[i]);

      final result = await calculationEngine.calculateStatus(
        processedEntries,
        settings,
      );

      // Create JSON object for this day
      final entryMap = {
        'Date': entries[i].date,
        'RawWeight': entries[i].rawWeight,
        'RawPreviousDayCalories': entries[i].rawPreviousDayCalories,
        'WeightEMA': result.trueWeight > 0 ? result.trueWeight : null,
        'CalorieEMA':
            result.averageCalories > 0 ? result.averageCalories : null,
        'SmoothedTrend_unit_per_week': result.weightTrend,
        'EstimatedTDEE_Algo':
            result.estimatedTdeeAlgo > 0 ? result.estimatedTdeeAlgo : null,
        'EstimatedTDEE_Standard':
            result.estimatedTdeeStandard > 0
                ? result.estimatedTdeeStandard
                : null,
        'TargetCalories_Algo':
            result.targetCaloriesAlgo > 0 ? result.targetCaloriesAlgo : null,
        'TargetCalories_Standard':
            result.targetCaloriesStandard > 0
                ? result.targetCaloriesStandard
                : null,
        'AlphaWeight_Used': result.currentAlphaWeight,
        'AlphaCalorie_Used': result.currentAlphaCalorie,
        'GoalRate_Set_for_Day': settings.goalRate,
        'TDEE_BlendFactor_Used': result.tdeeBlendFactorUsed,
      };

      jsonList.add(entryMap);
    }

    return jsonEncode(jsonList);
  }

  /// Saves export data to a file and returns the file path
  Future<String> saveExportToFile(
    String data,
    String prefix,
    String extension,
  ) async {
    try {
      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${prefix}_$timestamp.$extension';
      final filePath = '${directory.path}/$fileName';

      // Write data to file
      final file = File(filePath);
      await file.writeAsString(data);

      return filePath;
    } catch (e) {
      throw Exception('Error saving export file: $e');
    }
  }

  /// Imports data from a CSV string
  /// Returns the number of entries imported
  Future<int> importBasicCsv(String csvData) async {
    try {
      final lines = csvData.split('\n');
      if (lines.isEmpty) return 0;

      // Check for header row and skip if present
      int startIndex = 0;
      if (lines[0].toLowerCase().contains('date') &&
          lines[0].toLowerCase().contains('weight')) {
        startIndex = 1; // Skip header row
      }

      final importedEntries = <LogEntry>[];

      for (int i = startIndex; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final columns = line.split(',');
        if (columns.length < 2) continue; // Need at least date and weight

        // Parse date
        final date = columns[0].trim();
        if (!_isValidDateFormat(date)) continue; // Skip invalid dates

        // Parse weight (may be empty)
        double? weight;
        if (columns.length > 1 && columns[1].trim().isNotEmpty) {
          weight = double.tryParse(columns[1].trim());
        }

        // Parse calories (may be empty)
        int? calories;
        if (columns.length > 2 && columns[2].trim().isNotEmpty) {
          calories = int.tryParse(columns[2].trim());
        }

        // Create entry
        final entry = LogEntry(
          date: date,
          rawWeight: weight,
          rawPreviousDayCalories: calories,
        );

        importedEntries.add(entry);
      }

      // Return imported entries count
      return importedEntries.length;
    } catch (e) {
      throw Exception('Error importing CSV data: $e');
    }
  }

  bool _isValidDateFormat(String date) {
    // Expected format: YYYY-MM-DD
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return pattern.hasMatch(date);
  }
}
