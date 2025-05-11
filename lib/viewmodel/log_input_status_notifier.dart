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

  // Inputs
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
  // START OF CHANGES: Add tdeeBlendFactorUsed
  double? tdeeBlendFactorUsed;
  // END OF CHANGES

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
  Future<void> logData(double weight, int calories) async {
    _errorMessage = '';
    _isLoading = true;
    notifyListeners();

    final today = DateTime.now();
    // Ensure date is in<y_bin_46>-MM-DD format for DB consistency
    final String dateString =
        "${today.year.toString().padLeft(4, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.day.toString().padLeft(2, '0')}";

    final entry = LogEntry(
      date: dateString,
      rawWeight: weight,
      rawPreviousDayCalories: calories,
    );

    try {
      await _repository.insertOrUpdateLogEntry(entry);
      await _loadDataAndCalculate(); // This will reload settings and recalculate
    } catch (e) {
      _errorMessage = 'Error logging data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches history, loads settings, runs the engine, and updates state.
  Future<void> _loadDataAndCalculate() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final history = await _repository.getAllLogEntriesOldestFirst();
      _currentUserSettings = await _settingsRepo.loadSettings();

      final result = await _calculationEngine.calculateStatus(
        history,
        _currentUserSettings!,
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
      // START OF CHANGES: Assign tdeeBlendFactorUsed
      tdeeBlendFactorUsed = result.tdeeBlendFactorUsed;
      // END OF CHANGES
    } catch (e) {
      _errorMessage = 'Error calculating status: $e';
      _currentUserSettings = null;
      // START OF CHANGES: Clear calculation results on error too
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
      // END OF CHANGES
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the calculation based on latest data.
  /// Called when returning to this screen or after settings changes.
  Future<void> refreshCalculations() async {
    await _loadDataAndCalculate();
  }
}
