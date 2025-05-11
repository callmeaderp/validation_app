// lib/viewmodel/log_input_status_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/data/repository/settings_repository.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:validation_app/models/user_settings.dart'; // Import UserSettings

/// ViewModel for the "Log Input & Status" screen.
/// Uses persisted UserSettings to drive calculations.
class LogInputStatusNotifier extends ChangeNotifier {
  final TrackerRepository _repository;
  final SettingsRepository _settingsRepo;
  final CalculationEngine _calculationEngine;

  // Inputs from UI
  double? weightInput;
  int? caloriesInput;

  // Loading & error state
  bool _isLoading = false;
  String _errorMessage = '';
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  UserSettings? _currentUserSettings;
  UserSettings? get currentUserSettings => _currentUserSettings;

  // Calculation results
  double? trueWeight;
  double? weightTrendPerWeek;
  double? averageCalories;
  double? estimatedTdeeAlgo;
  double? targetCaloriesAlgo;
  double? estimatedTdeeStandard;
  double? targetCaloriesStandard;
  double? deltaTdee;
  double? deltaTarget;
  double? currentAlphaWeight;
  double? currentAlphaCalorie;
  double? tdeeBlendFactorUsed;

  LogInputStatusNotifier({
    required TrackerRepository repository,
    required SettingsRepository settingsRepo,
    CalculationEngine? calculationEngine,
  }) : _repository = repository,
       _settingsRepo = settingsRepo,
       _calculationEngine = calculationEngine ?? CalculationEngine() {
    _loadDataAndCalculate();
  }

  /// Called when the user taps "Log Data".
  /// Accepts nullable inputs and returns true on success, false on failure.
  Future<bool> logData(double? weight, int? calories) async {
    _errorMessage = ''; // Clear previous error
    _isLoading = true;
    notifyListeners();

    // Ensure at least one value is provided to log
    if (weight == null && calories == null) {
      _errorMessage = 'Please enter weight or calories to log.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final today = DateTime.now();
    // Ensure date is in YYYY-MM-DD format for DB consistency
    final String dateString =
        "${today.year.toString().padLeft(4, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.day.toString().padLeft(2, '0')}";

    final entry = LogEntry(
      date: dateString,
      rawWeight: weight, // Can be null
      rawPreviousDayCalories: calories, // Can be null
    );

    try {
      await _repository.insertOrUpdateLogEntry(entry);
      // Important: Clear the temporary input fields after successful logging
      // The UI will clear its controllers, but the notifier's copies should also clear.
      weightInput = null;
      caloriesInput = null;
      await _loadDataAndCalculate(); // This will reload settings and recalculate
      // _isLoading is set to false in _loadDataAndCalculate's finally block
      return true; // Indicate success
    } catch (e) {
      _errorMessage = 'Error logging data: $e';
      _isLoading = false;
      notifyListeners();
      return false; // Indicate failure
    }
  }

  /// Fetches history, loads settings, runs the engine, and updates state.
  Future<void> _loadDataAndCalculate() async {
    _isLoading = true;
    _errorMessage = ''; // Clear error at the start of loading
    // Notify listeners early if you want to show a loading state immediately
    // based on _isLoading, but typically it's done once before try and in finally.
    // For simplicity, keeping one notifyListeners() before try for now.
    notifyListeners();

    try {
      // Fetch fresh settings every time calculations are run.
      _currentUserSettings = await _settingsRepo.loadSettings();

      // Ensure settings are loaded before proceeding with history that might depend on them
      // or before passing them to calculationEngine.
      if (_currentUserSettings == null) {
        // This case should ideally not happen if loadSettings() is robust
        // or provides default settings. If it can return null, handle it.
        throw Exception("User settings could not be loaded.");
      }

      final history = await _repository.getAllLogEntriesOldestFirst();
      final result = await _calculationEngine.calculateStatus(
        history,
        _currentUserSettings!, // Now safe to use ! due to check above or if loadSettings ensures non-null
      );

      trueWeight = result.trueWeight;
      weightTrendPerWeek = result.weightTrend;
      averageCalories = result.averageCalories;
      estimatedTdeeAlgo = result.estimatedTdeeAlgo;
      targetCaloriesAlgo = result.targetCaloriesAlgo;
      estimatedTdeeStandard = result.estimatedTdeeStandard;
      targetCaloriesStandard = result.targetCaloriesStandard;
      deltaTdee = result.deltaTdee;
      deltaTarget = result.deltaTarget;
      currentAlphaWeight = result.currentAlphaWeight;
      currentAlphaCalorie = result.currentAlphaCalorie;
      tdeeBlendFactorUsed = result.tdeeBlendFactorUsed;
    } catch (e) {
      _errorMessage = 'Error calculating status: $e';
      // Optionally clear sensitive/calculated data on error
      // _currentUserSettings = null; // Keep settings or clear? Depends on desired behavior.
      trueWeight = null;
      weightTrendPerWeek = null;
      averageCalories = null;
      estimatedTdeeAlgo = null;
      targetCaloriesAlgo = null;
      estimatedTdeeStandard = null;
      targetCaloriesStandard = null;
      deltaTdee = null;
      deltaTarget = null;
      currentAlphaWeight = null;
      currentAlphaCalorie = null;
      tdeeBlendFactorUsed = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the calculation based on latest data.
  /// Called when returning to this screen or after settings changes.
  Future<void> refreshCalculations() async {
    // Clear previous error before refreshing
    _errorMessage = '';
    await _loadDataAndCalculate();
  }
}
