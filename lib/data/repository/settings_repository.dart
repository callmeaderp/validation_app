// lib/data/repository/settings_repository.dart
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
  static const _keyWeightUnit = 'weightUnit';
  static const _keyHeightUnit = 'heightUnit';
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

    // Load user profile data, or use defaults if not set
    final height = prefs.getDouble(_keyHeight) ?? UserSettings().height;
    final age = prefs.getInt(_keyAge) ?? UserSettings().age;
    final sexIndex = prefs.getInt(_keySex) ?? UserSettings().sex.index;
    final activityIndex =
        prefs.getInt(_keyActivityLevel) ?? UserSettings().activityLevel.index;
    final goalRate = prefs.getDouble(_keyGoalRate) ?? UserSettings().goalRate;

    // Load unit preferences, or use defaults if not set
    final weightUnitIndex =
        prefs.getInt(_keyWeightUnit) ?? UserSettings().weightUnit.index;
    final heightUnitIndex =
        prefs.getInt(_keyHeightUnit) ?? UserSettings().heightUnit.index;

    // Load algorithm parameters, or use defaults if not set
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

    // Ensure values are within valid ranges
    final validWeightUnitIndex = _ensureValidEnumIndex(
      weightUnitIndex,
      WeightUnitSystem.values.length,
    );
    final validHeightUnitIndex = _ensureValidEnumIndex(
      heightUnitIndex,
      HeightUnitSystem.values.length,
    );
    final validSexIndex = _ensureValidEnumIndex(
      sexIndex,
      BiologicalSex.values.length,
    );
    final validActivityIndex = _ensureValidEnumIndex(
      activityIndex,
      ActivityLevel.values.length,
    );

    return UserSettings(
      height: height,
      age: age,
      sex: BiologicalSex.values[validSexIndex],
      activityLevel: ActivityLevel.values[validActivityIndex],
      weightUnit: WeightUnitSystem.values[validWeightUnitIndex],
      heightUnit: HeightUnitSystem.values[validHeightUnitIndex],
      goalRate: goalRate,
      weightAlpha: _constrainValue(weightAlpha, 0.001, 0.999),
      weightAlphaMin: _constrainValue(weightAlphaMin, 0.001, weightAlphaMax),
      weightAlphaMax: _constrainValue(weightAlphaMax, weightAlphaMin, 0.999),
      calorieAlpha: _constrainValue(calorieAlpha, 0.001, 0.999),
      calorieAlphaMin: _constrainValue(calorieAlphaMin, 0.001, calorieAlphaMax),
      calorieAlphaMax: _constrainValue(calorieAlphaMax, calorieAlphaMin, 0.999),
      trendSmoothingDays: _constrainValue(trendSmoothingDays, 1, 30),
    );
  }

  /// Ensures an enum index is valid by constraining it to the available range
  int _ensureValidEnumIndex(int index, int length) {
    return index.clamp(0, length - 1);
  }

  /// Constrains a value to be within min and max
  T _constrainValue<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Saves all settings to SharedPreferences
  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    // Save user profile data
    await prefs.setDouble(_keyHeight, settings.height);
    await prefs.setInt(_keyAge, settings.age);
    await prefs.setInt(_keySex, settings.sex.index);
    await prefs.setInt(_keyActivityLevel, settings.activityLevel.index);
    await prefs.setDouble(_keyGoalRate, settings.goalRate);

    // Save unit preferences
    await prefs.setInt(_keyWeightUnit, settings.weightUnit.index);
    await prefs.setInt(_keyHeightUnit, settings.heightUnit.index);

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
    final defaultSettings = UserSettings(); // Has default algorithm parameters

    // Reset only algorithm parameters, keep user profile and unit settings
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

  /// Exports basic log data as CSV string with unit information
  Future<String> exportBasicCsv(List<LogEntry> entries) async {
    final settings = await loadSettings();
    final weightUnit = settings.weightUnitString;

    // Header row with unit information
    final csvBuffer = StringBuffer(
      'Date,Weight (${weightUnit}),PreviousDayCalories (kcal)\n',
    );

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

  /// Exports detailed log data as JSON string with settings context
  Future<String> exportDetailedJson(
    List<LogEntry> entries,
    UserSettings settings,
  ) async {
    final calculationEngine = CalculationEngine();
    final jsonList = [];

    // Sort entries by date (oldest first) for consistent processing
    final sortedEntries = List<LogEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Process entries chronologically to build up calculation history
    List<LogEntry> processedEntries = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      processedEntries.add(sortedEntries[i]);

      // Calculate status for this day using all entries up to this point
      final result = await calculationEngine.calculateStatus(
        processedEntries,
        settings,
      );

      // Create JSON object for this day with all relevant data
      final entryMap = {
        'Date': sortedEntries[i].date,
        'RawWeight': sortedEntries[i].rawWeight,
        'WeightUnit': settings.weightUnit.toString().split('.').last,
        'RawPreviousDayCalories': sortedEntries[i].rawPreviousDayCalories,
        'WeightEMA': result.trueWeight > 0 ? result.trueWeight : null,
        'CalorieEMA':
            result.averageCalories > 0 ? result.averageCalories : null,
        'SmoothedTrend_unit_per_week': result.weightTrend,
        'TrendUnit': '${settings.weightUnit.toString().split('.').last}/week',
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

    // Include current settings in the export for reference
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'exportAppVersion': '1.0.0', // Add version tracking
      'settingsSnapshot': {
        'height': settings.height,
        'heightUnit': settings.heightUnit.toString().split('.').last,
        'age': settings.age,
        'sex': settings.sex.toString().split('.').last,
        'activityLevel': settings.activityLevel.toString().split('.').last,
        'weightUnit': settings.weightUnit.toString().split('.').last,
        'goalRate': settings.goalRate,
        'weightAlpha': settings.weightAlpha,
        'weightAlphaMin': settings.weightAlphaMin,
        'weightAlphaMax': settings.weightAlphaMax,
        'calorieAlpha': settings.calorieAlpha,
        'calorieAlphaMin': settings.calorieAlphaMin,
        'calorieAlphaMax': settings.calorieAlphaMax,
        'trendSmoothingDays': settings.trendSmoothingDays,
      },
      'logData': jsonList,
    };

    return jsonEncode(exportData);
  }

  /// Saves export data to a file and returns the file path
  Future<String> saveExportToFile(
    String data,
    String prefix,
    String extension,
  ) async {
    try {
      // Get documents directory for file storage
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

  /// Parses CSV data into LogEntry objects
  /// Returns the list of parsed entries for processing by the caller
  Future<List<LogEntry>> parseBasicCsvToLogEntries(String csvData) async {
    try {
      final lines = csvData.split('\n');
      if (lines.isEmpty) return [];

      // Check for header row and skip if present
      int startIndex = 0;
      if (lines[0].toLowerCase().contains('date') &&
          (lines[0].toLowerCase().contains('weight') ||
              lines[0].toLowerCase().contains('previousdaycalories') ||
              lines[0].toLowerCase().contains('calories'))) {
        startIndex = 1; // Skip header row
      }

      final importedEntries = <LogEntry>[];
      for (int i = startIndex; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final columns = line.split(',');
        // Expecting at least Date column
        if (columns.length < 1) continue;

        // Parse date - require valid format
        final date = columns[0].trim();
        if (!_isValidDateFormat(date)) continue;

        // Parse weight - might be empty/null
        double? weight;
        if (columns.length > 1 && columns[1].trim().isNotEmpty) {
          weight = double.tryParse(columns[1].trim());
          // Ignore nonsensical weight values (negative or extremely high)
          if (weight != null && (weight <= 0 || weight > 1000)) {
            weight = null;
          }
        }

        // Parse calories - might be empty/null
        int? calories;
        if (columns.length > 2 && columns[2].trim().isNotEmpty) {
          calories = int.tryParse(columns[2].trim());
          // Ignore nonsensical calorie values (negative or extremely high)
          if (calories != null && (calories < 0 || calories > 10000)) {
            calories = null;
          }
        }

        // Create and add the entry if it has valid date
        final entry = LogEntry(
          date: date,
          rawWeight: weight,
          rawPreviousDayCalories: calories,
        );
        importedEntries.add(entry);
      }

      // Sort entries by date to ensure chronological order
      importedEntries.sort((a, b) => a.date.compareTo(b.date));

      return importedEntries;
    } catch (e) {
      throw Exception('Error parsing CSV data: $e');
    }
  }

  /// Validates date format (YYYY-MM-DD)
  bool _isValidDateFormat(String date) {
    // Expected format: YYYY-MM-DD
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!pattern.hasMatch(date)) return false;

    // Further validate as a real date
    try {
      final parts = date.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      if (month < 1 || month > 12) return false;
      if (day < 1 || day > 31) return false;

      // Simple month length validation (ignoring leap years for simplicity)
      if ([4, 6, 9, 11].contains(month) && day > 30) return false;
      if (month == 2 && day > 29) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}
