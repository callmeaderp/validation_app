import 'package:flutter/foundation.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/calculation/calculation_engine.dart';

/// ViewModel for the "Log Input & Status" screen.
/// Manages logging data, loading history, running calculations, and exposing results.
class LogInputStatusNotifier extends ChangeNotifier {
  final TrackerRepository _repository;
  final CalculationEngine _engine;

  LogInputStatusNotifier(this._repository, this._engine) {
    _loadDataAndCalculate();
  }

  // Loading & error state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Calculation results (exposed as strings for easy display)
  String _trueWeight = '---';
  String get trueWeight => _trueWeight;

  String _weightTrend = '---';
  String get weightTrend => _weightTrend;

  String _averageCalories = '---';
  String get averageCalories => _averageCalories;

  String _algoTdee = '---';
  String get algoTdee => _algoTdee;

  String _algoTarget = '---';
  String get algoTarget => _algoTarget;

  String _standardTdee = '---';
  String get standardTdee => _standardTdee;

  String _standardTarget = '---';
  String get standardTarget => _standardTarget;

  String _deltaTdee = '---';
  String get deltaTdee => _deltaTdee;

  String _deltaTarget = '---';
  String get deltaTarget => _deltaTarget;

  String _currentAlphaWeight = '---';
  String get currentAlphaWeight => _currentAlphaWeight;

  String _currentAlphaCalorie = '---';
  String get currentAlphaCalorie => _currentAlphaCalorie;

  /// Called when the user taps "Log Data".
  Future<void> logData(String weightInput, String caloriesInput) async {
    final weight = double.tryParse(weightInput);
    final calories = double.tryParse(caloriesInput);
    if (weight == null || calories == null) {
      _errorMessage = 'Please enter valid numbers.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final entry = LogEntry(
        date: today,
        rawWeight: weight,
        rawPreviousDayCalories: calories.toInt(),
      );
      await _repository.insertOrUpdateLogEntry(entry);
      await _loadDataAndCalculate();
    } catch (e) {
      _errorMessage = 'Error logging data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all history, runs the calculation engine, and updates exposed fields.
  Future<void> _loadDataAndCalculate() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Fetch historical entries (oldest-first)
      final history = await _repository.getAllLogEntriesOldestFirst();

      // Run the core algorithm
      // If your engine.calculateStatus requires UserSettings, adjust accordingly
      final result = await _engine.calculateStatus(history);

      _trueWeight =
          result.trueWeight != null
              ? result.trueWeight!.toStringAsFixed(2)
              : '---';

      _weightTrend =
          result.weightTrend != null
              ? result.weightTrend!.toStringAsFixed(2)
              : '---';

      _averageCalories =
          result.averageCalories != null
              ? result.averageCalories!.round().toString()
              : '---';

      _algoTdee =
          result.estimatedTdeeAlgo != null
              ? result.estimatedTdeeAlgo!.round().toString()
              : '---';

      _algoTarget =
          result.targetCaloriesAlgo != null
              ? result.targetCaloriesAlgo!.round().toString()
              : '---';

      _standardTdee =
          result.estimatedTdeeStandard != null
              ? result.estimatedTdeeStandard!.round().toString()
              : '---';

      _standardTarget =
          result.targetCaloriesStandard != null
              ? result.targetCaloriesStandard!.round().toString()
              : '---';

      _deltaTdee =
          result.deltaTdee != null
              ? result.deltaTdee!.round().toString()
              : '---';

      _deltaTarget =
          result.deltaTarget != null
              ? result.deltaTarget!.round().toString()
              : '---';

      _currentAlphaWeight =
          result.currentAlphaWeight != null
              ? result.currentAlphaWeight!.toStringAsFixed(3)
              : '---';

      _currentAlphaCalorie =
          result.currentAlphaCalorie != null
              ? result.currentAlphaCalorie!.toStringAsFixed(3)
              : '---';
    } catch (e) {
      _errorMessage = 'Error loading data: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}
