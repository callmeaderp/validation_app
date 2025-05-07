import '../data/database/log_entry.dart'; // Import your data model
// TODO: Import UserSettings model when created
import 'dart:math'; // Needed for min/max, maybe standard deviation later

// Data class to hold all the calculated results
class CalculationResult {
  final double? trueWeight; // WeightEMA
  final double? weightTrend; // lbs or kg per week
  final double? averageCalories; // CalorieEMA
  final double? estimatedTdeeAlgo;
  final double? targetCaloriesAlgo;
  final double? estimatedTdeeStandard; // For comparison
  final double? targetCaloriesStandard; // For comparison
  final double? deltaTdee;
  final double? deltaTarget;
  final double? currentAlphaWeight;
  final double? currentAlphaCalorie;
  // Add any other results needed

  CalculationResult({
    this.trueWeight,
    this.weightTrend,
    this.averageCalories,
    this.estimatedTdeeAlgo,
    this.targetCaloriesAlgo,
    this.estimatedTdeeStandard,
    this.targetCaloriesStandard,
    this.deltaTdee,
    this.deltaTarget,
    this.currentAlphaWeight,
    this.currentAlphaCalorie,
  });
}

// Placeholder for User Settings data structure
// Replace with actual UserSettings class later
class UserSettings {
  final double
  goalRate; // e.g., lbs/week or %/week (need to define how it's stored)
  final double heightCm;
  final int ageYears;
  final String sex; // e.g., "Male", "Female"
  final String activityLevel; // e.g., "Sedentary", "LightlyActive" (or factor)
  // TODO: Add algo parameters (alphas, trend period etc.)
  final double defaultWeightAlpha = 0.1;
  final double defaultCalorieAlpha = 0.1;
  final int trendPeriodDays = 7;

  UserSettings({
    this.goalRate = 0.0,
    this.heightCm = 170.0, // Example default
    this.ageYears = 30, // Example default
    this.sex = "Male", // Example default
    this.activityLevel = "LightlyActive", // Example default
  });
}

class CalculationEngine {
  // Main calculation function
  // Takes historical data and current settings, returns all results
  Future<CalculationResult> calculateStatus(
    List<LogEntry> history,
    UserSettings settings,
  ) async {
    // --- Input Validation and Preparation ---
    if (history.length < 2) {
      // Not enough data for most calculations
      return CalculationResult(); // Return empty results
    }

    // TODO: Apply outlier checks/filtering to history if needed
    // List<LogEntry> filteredHistory = _applyOutlierChecks(history);
    final filteredHistory = history; // Use raw for now

    // Extract lists of nullable doubles/ints, handling potential nulls
    final weights = filteredHistory.map((e) => e.rawWeight).toList();
    final calories =
        filteredHistory
            .map((e) => e.rawPreviousDayCalories?.toDouble())
            .toList(); // Convert Int? to Double?

    // --- Core Calculations (Using Stubs/Defaults for now) ---

    // TODO: Implement full dynamic alpha calculation based on history volatility
    final double currentWeightAlpha = _calculateDynamicWeightAlpha(
      filteredHistory,
      settings,
    );
    final double currentCalorieAlpha = _calculateDynamicCalorieAlpha(
      filteredHistory,
      settings,
    );

    // Calculate EMAs (using dynamic alpha eventually)
    final List<double?> weightEmaSeries = _calculateEmaSeries(
      weights,
      currentWeightAlpha,
    );
    final List<double?> calorieEmaSeries = _calculateEmaSeries(
      calories,
      currentCalorieAlpha,
    );

    final double? latestWeightEma =
        weightEmaSeries.isNotEmpty ? weightEmaSeries.last : null;
    final double? latestCalorieEma =
        calorieEmaSeries.isNotEmpty ? calorieEmaSeries.last : null;

    // Calculate Trend
    final double? trendPerDay = _calculateTrend(
      weightEmaSeries,
      settings.trendPeriodDays,
    );
    final double? trendPerWeek = trendPerDay != null ? trendPerDay * 7.0 : null;

    // TODO: Implement TDEE blending logic for initial phase
    // final double blendFactor = _calculateBlendFactor(filteredHistory.length);

    // Calculate Algo TDEE & Target (Simplified for now)
    double? estimatedTdeeAlgo = null;
    double? targetCaloriesAlgo = null;
    if (latestCalorieEma != null && trendPerDay != null) {
      const kcalPerUnit =
          3500.0 / 7.0; // Approx kcal per lb per day (adjust if using kg)
      estimatedTdeeAlgo = latestCalorieEma - (trendPerDay * kcalPerUnit);

      // Convert goal rate (% or lbs/week) to kcal/day deficit/surplus
      // TODO: Handle goal rate being % vs absolute
      final double targetDeficitSurplus =
          (settings.goalRate / 7.0) *
          kcalPerUnit; // Assuming goalRate is lbs/week
      targetCaloriesAlgo = estimatedTdeeAlgo + targetDeficitSurplus;
    }

    // Calculate Standard TDEE & Target (for comparison)
    double? estimatedTdeeStandard = null;
    double? targetCaloriesStandard = null;
    if (latestWeightEma != null) {
      estimatedTdeeStandard = _calculateStandardTdee(latestWeightEma, settings);
      if (estimatedTdeeAlgo != null && targetCaloriesAlgo != null) {
        // Apply same deficit/surplus for fair comparison
        final double algoDeficitSurplus =
            targetCaloriesAlgo - estimatedTdeeAlgo;
        targetCaloriesStandard = estimatedTdeeStandard + algoDeficitSurplus;
      }
    }

    // --- Package Results ---
    return CalculationResult(
      trueWeight: latestWeightEma,
      weightTrend: trendPerWeek,
      averageCalories: latestCalorieEma,
      estimatedTdeeAlgo: estimatedTdeeAlgo,
      targetCaloriesAlgo: targetCaloriesAlgo,
      estimatedTdeeStandard: estimatedTdeeStandard,
      targetCaloriesStandard: targetCaloriesStandard,
      deltaTdee:
          (estimatedTdeeAlgo != null && estimatedTdeeStandard != null)
              ? estimatedTdeeAlgo - estimatedTdeeStandard
              : null,
      deltaTarget:
          (targetCaloriesAlgo != null && targetCaloriesStandard != null)
              ? targetCaloriesAlgo - targetCaloriesStandard
              : null,
      currentAlphaWeight: currentWeightAlpha, // Use calculated dynamic alpha
      currentAlphaCalorie: currentCalorieAlpha, // Use calculated dynamic alpha
    );
  }

  // --- Private Helper Function Stubs ---

  // Basic EMA calculation (replace with dynamic alpha logic later)
  List<double?> _calculateEmaSeries(List<double?> data, double alpha) {
    List<double?> emaValues = [];
    double? previousEma;

    for (final value in data) {
      if (value != null) {
        // Only process non-null values
        if (previousEma == null) {
          previousEma = value; // Start with the first valid value
        } else {
          previousEma = (value * alpha) + (previousEma * (1.0 - alpha));
        }
        emaValues.add(previousEma);
      } else {
        emaValues.add(previousEma); // Carry forward EMA if data is null
      }
    }
    return emaValues;
  }

  // Basic Trend calculation (moving average of daily diffs)
  double? _calculateTrend(List<double?> emaSeries, int trendPeriod) {
    List<double> diffs = [];
    // Calculate daily differences
    for (int i = 1; i < emaSeries.length; i++) {
      if (emaSeries[i] != null && emaSeries[i - 1] != null) {
        diffs.add(emaSeries[i]! - emaSeries[i - 1]!);
      }
    }

    if (diffs.length < max(1, trendPeriod - 1))
      return null; // Need enough diffs for MA window

    // Calculate moving average of the differences over the trend period
    final relevantDiffs = diffs.sublist(max(0, diffs.length - trendPeriod));
    if (relevantDiffs.isEmpty) return null;

    double sum = relevantDiffs.reduce((a, b) => a + b);
    return sum / relevantDiffs.length; // Average daily change
  }

  // Standard TDEE (Mifflin-St Jeor + Activity Factor)
  double _calculateStandardTdee(double weightKg, UserSettings settings) {
    // Convert weight to kg if needed (assuming input is kg for formula)
    // TODO: Add unit conversion based on settings
    double weightInKg = weightKg; // Assume kg for now
    double heightInCm = settings.heightCm;
    int age = settings.ageYears;
    String sex = settings.sex;

    double bmr;
    if (sex.toLowerCase() == "male") {
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * age) + 5;
    } else {
      // Assume Female
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * age) - 161;
    }

    // Apply Activity Factor
    // TODO: Define activity factors more robustly based on setting string
    double activityFactor = 1.375; // Default to Lightly Active
    if (settings.activityLevel.toLowerCase().contains("sedentary"))
      activityFactor = 1.2;
    if (settings.activityLevel.toLowerCase().contains("moderately"))
      activityFactor = 1.55;
    if (settings.activityLevel.toLowerCase().contains("very"))
      activityFactor = 1.725;
    if (settings.activityLevel.toLowerCase().contains("extra"))
      activityFactor = 1.9;

    return bmr * activityFactor;
  }

  // Placeholder for dynamic alpha logic
  double _calculateDynamicWeightAlpha(
    List<LogEntry> history,
    UserSettings settings,
  ) {
    // TODO: Implement logic based on relative prediction error / std dev
    // For now, return default
    return settings.defaultWeightAlpha;
  }

  // Placeholder for dynamic alpha logic
  double _calculateDynamicCalorieAlpha(
    List<LogEntry> history,
    UserSettings settings,
  ) {
    // TODO: Implement logic based on CV and missing days
    // For now, return default
    return settings.defaultCalorieAlpha;
  }

  // Placeholder for TDEE blending logic
  // double _calculateBlendFactor(int daysOfData) {
  //   // TODO: Implement decay logic
  //   return 0.0; // Return 0.0 when fully data-driven
  // }

  // Placeholder for outlier checks
  // List<LogEntry> _applyOutlierChecks(List<LogEntry> history) {
  //   // TODO: Implement logic to flag/ignore/dampen outliers
  //   return history;
  // }
}
