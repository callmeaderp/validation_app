import 'package:flutter/foundation.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/data/repository/settings_repository.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:validation_app/calculation/calculation_engine.dart';

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
    final entry = LogEntry(
      date:
          DateTime(
            today.year,
            today.month,
            today.day,
          ).toIso8601String().split('T').first,
      rawWeight: weight,
      rawPreviousDayCalories: calories,
    );

    try {
      await _repository.insertOrUpdateLogEntry(entry);
      await _loadDataAndCalculate();
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
      final settings = await _settingsRepo.loadSettings();

      final result = await _calculationEngine.calculateStatus(
        history,
        settings,
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
    } catch (e) {
      _errorMessage = 'Error calculating status: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
