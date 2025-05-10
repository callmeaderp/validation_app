import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/database/log_entry.dart';

/// Holds the outputs of the calculation engine for display
class CalculationResult {
  final double trueWeight; // Smoothed "true" weight (EMA)
  final double weightTrend; // 7-day average trend (units/week)
  final double averageCalories; // EMA of daily intake
  final double estimatedTdeeAlgo; // TDEE from algorithm
  final double targetCaloriesAlgo; // Target calories from algorithm
  final double estimatedTdeeStandard; // TDEE from standard formula
  final double targetCaloriesStandard; // Target calories from standard formula
  final double deltaTdee; // Difference between algo & standard TDEE
  final double deltaTarget; // Difference between algo & standard target
  final double currentAlphaWeight; // Current alpha for weight EMA
  final double currentAlphaCalorie; // Current alpha for calorie EMA

  CalculationResult({
    required this.trueWeight,
    required this.weightTrend,
    required this.averageCalories,
    required this.estimatedTdeeAlgo,
    required this.targetCaloriesAlgo,
    required this.estimatedTdeeStandard,
    required this.targetCaloriesStandard,
    required this.deltaTdee,
    required this.deltaTarget,
    required this.currentAlphaWeight,
    required this.currentAlphaCalorie,
  });
}

/// Core engine that processes weight & calorie history into insights
class CalculationEngine {
  /// Runs the full calculation given historical entries and user settings.
  Future<CalculationResult> calculateStatus(
    List<LogEntry> history,
    UserSettings settings,
  ) async {
    // TODO: Implement Exponential Moving Averages, dynamic alphas,
    //       trend calculation, TDEE estimation, and target derivation.

    // Placeholder stub values
    return CalculationResult(
      trueWeight: 0.0,
      weightTrend: 0.0,
      averageCalories: 0.0,
      estimatedTdeeAlgo: 0.0,
      targetCaloriesAlgo: 0.0,
      estimatedTdeeStandard: 0.0,
      targetCaloriesStandard: 0.0,
      deltaTdee: 0.0,
      deltaTarget: 0.0,
      currentAlphaWeight: 0.0,
      currentAlphaCalorie: 0.0,
    );
  }
}
