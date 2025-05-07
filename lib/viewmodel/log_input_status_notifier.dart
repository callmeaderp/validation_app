import 'package:flutter/foundation.dart'; // Required for ChangeNotifier
import '../data/database/log_entry.dart';
import '../data/repository/tracker_repository.dart';
import '../calculation/calculation_engine.dart'; // Import CalculationEngine & Result
import 'dart:async'; // For Future

// Using ChangeNotifier as a simple ViewModel/State Management solution for now
class LogInputStatusNotifier extends ChangeNotifier {
  final TrackerRepository _repository;
  final CalculationEngine _calculationEngine;

  // Constructor - Repository and Engine are dependencies
  LogInputStatusNotifier(this._repository, this._calculationEngine) {
    // Load initial data when the notifier is created
    _loadDataAndCalculate();
  }

  // --- Private State Variables ---
  // Use private fields with public getters to expose state
  bool _isLoading = true;
  String _trueWeight = "---";
  String _weightTrend = "---";
  String _algoTdee = "---";
  String _algoTarget = "---";
  String _standardTdee = "---";
  String _standardTarget = "---";
  String _deltaTdee = "---";
  String _deltaTarget = "---";
  String _currentAlphaWeight = "---";
  String _currentAlphaCalorie = "---";
  String _errorMessage = ""; // To display potential errors

  // --- Public Getters for UI ---
  bool get isLoading => _isLoading;
  String get trueWeight => _trueWeight;
  String get weightTrend => _weightTrend;
  String get algoTdee => _algoTdee;
  String get algoTarget => _algoTarget;
  String get standardTdee => _standardTdee;
  String get standardTarget => _standardTarget;
  String get deltaTdee => _deltaTdee;
  String get deltaTarget => _deltaTarget;
  String get currentAlphaWeight => _currentAlphaWeight;
  String get currentAlphaCalorie => _currentAlphaCalorie;
  String get errorMessage => _errorMessage;

  // --- Public Methods (Actions from UI) ---

  Future<void> logData(String? weightInput, String? caloriesInput) async {
    _errorMessage = ""; // Clear previous errors
    _isLoading = true; // Indicate loading state
    notifyListeners(); // Notify UI about loading start

    final weight = weightInput != null ? double.tryParse(weightInput) : null;
    final calories = caloriesInput != null ? int.tryParse(caloriesInput) : null;

    if (weight == null || weight <= 0) {
      _errorMessage = "Invalid weight input";
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (calories != null && calories < 0) {
      _errorMessage = "Invalid calorie input";
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Get today's date string (simplified, consider timezones if needed)
    final String todayDate = DateTime.now().toIso8601String().substring(0, 10);

    final newEntry = LogEntry(
      date: todayDate,
      rawWeight: weight,
      rawPreviousDayCalories: calories,
    );

    try {
      await _repository.insertOrUpdateLogEntry(newEntry);
      // After successfully logging, reload all data and recalculate
      await _loadDataAndCalculate();
    } catch (e) {
      _errorMessage = "Error logging data: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Private Helper Methods ---

  Future<void> _loadDataAndCalculate() async {
    _isLoading = true;
    _errorMessage = "";
    // Notify UI *before* async work if you want immediate loading state
    // notifyListeners(); // Optional: Notify UI immediately that loading started

    try {
      // Fetch all necessary data from the repository
      final history = await _repository.getAllLogEntriesOldestFirst();
      // TODO: Fetch UserSettings from repository when implemented
      final settings = UserSettings(); // Using placeholder for now

      // Run calculations
      final results = await _calculationEngine.calculateStatus(
        history,
        settings,
      );

      // Update state variables
      _updateStateFromResults(results);
    } catch (e) {
      _errorMessage = "Error calculating status: ${e.toString()}";
      print("Error in _loadDataAndCalculate: $e"); // Log error
    } finally {
      _isLoading = false; // Ensure loading is set to false
      notifyListeners(); // IMPORTANT: Notify UI that data is ready or error occurred
    }
  }

  void _updateStateFromResults(CalculationResult results) {
    _trueWeight = results.trueWeight?.toStringAsFixed(1) ?? "---";
    _weightTrend =
        results.weightTrend != null
            ? "${results.weightTrend! > 0 ? '+' : ''}${results.weightTrend!.toStringAsFixed(2)} units/week" // TODO: Add units based on settings
            : "---";
    _averageCalories =
        results.averageCalories?.round().toString() ?? "---"; // Added this line
    _algoTdee = results.estimatedTdeeAlgo?.round().toString() ?? "---";
    _algoTarget = results.targetCaloriesAlgo?.round().toString() ?? "---";
    _standardTdee = results.estimatedTdeeStandard?.round().toString() ?? "---";
    _standardTarget =
        results.targetCaloriesStandard?.round().toString() ?? "---";
    _deltaTdee = results.deltaTdee?.round().toString() ?? "---";
    _deltaTarget = results.deltaTarget?.round().toString() ?? "---";
    _currentAlphaWeight =
        results.currentAlphaWeight?.toStringAsFixed(3) ?? "---";
    _currentAlphaCalorie =
        results.currentAlphaCalorie?.toStringAsFixed(3) ?? "---";
  }

  // Added declaration for _averageCalories
  String _averageCalories = "---";
  // Added getter for averageCalories
  String get averageCalories => _averageCalories;
}
