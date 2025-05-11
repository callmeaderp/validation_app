import 'dart:math';
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
  final double tdeeBlendFactorUsed; // For diagnostic export

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
    required this.tdeeBlendFactorUsed,
  });
}

/// Core engine that processes weight & calorie history into insights
class CalculationEngine {
  // Constants
  static const double _energyEquivalentPerLb = 3500.0;
  static const double _energyEquivalentPerKg = 7700.0;
  static const int _trendSmoothingDays = 7;
  static const double _initialTdeeBlendDecayFactor = 0.85;
  static const int _tdeeBlendDurationDays = 21; // Approx 3 weeks
  static const int _minDaysForTrend = 5;

  /// Runs the full calculation given historical entries and user settings.
  Future<CalculationResult> calculateStatus(
    List<LogEntry> history,
    UserSettings settings,
  ) async {
    if (history.isEmpty) {
      // Not enough data to calculate anything meaningful
      return CalculationResult(
        trueWeight: 0.0,
        weightTrend: 0.0,
        averageCalories: 0.0,
        estimatedTdeeAlgo: 0.0,
        targetCaloriesAlgo: 0.0,
        estimatedTdeeStandard: _calculateStandardTdee(
          settings,
          0.0,
        ), // Use 0 for current weight if no history
        targetCaloriesStandard: 0.0,
        deltaTdee: 0.0,
        deltaTarget: 0.0,
        currentAlphaWeight: settings.weightAlpha,
        currentAlphaCalorie: settings.calorieAlpha,
        tdeeBlendFactorUsed: 1.0,
      );
    }

    // --- Initialize internal calculation lists ---
    List<double?> rawWeights = history.map((e) => e.rawWeight).toList();
    List<int?> rawCalories =
        history.map((e) => e.rawPreviousDayCalories).toList();

    List<double> weightEmaHistory = [];
    List<double> calorieEmaHistory = [];
    List<double> dailyWeightDeltaHistory = [];
    List<double> tdeeAlgoHistory = [];

    double currentWeightAlpha = settings.weightAlpha;
    double currentCalorieAlpha = settings.calorieAlpha;

    // --- 1. "True Weight" (WeightEMA) & Dynamic Alpha_Weight ---
    double previousWeightEma = 0.0;
    List<double> relativePredictionErrors = [];

    for (int i = 0; i < rawWeights.length; i++) {
      double currentWeightEma;
      if (i == 0) {
        currentWeightEma =
            rawWeights[i] ?? 0.0; // Seed with first value or 0 if null
      } else {
        if (rawWeights[i] != null) {
          // Calculate relative prediction error for dynamic alpha
          if (previousWeightEma != 0) {
            double error =
                ((rawWeights[i]! - previousWeightEma).abs() /
                    previousWeightEma) *
                100.0;
            relativePredictionErrors.add(error);
            if (relativePredictionErrors.length > _trendSmoothingDays) {
              relativePredictionErrors.removeAt(0); // Keep only last 7
            }
          }

          // Adjust alpha_weight
          if (relativePredictionErrors.length == _trendSmoothingDays) {
            double avgRelError =
                relativePredictionErrors.reduce((a, b) => a + b) /
                _trendSmoothingDays;
            if (avgRelError < 0.25) {
              currentWeightAlpha = min(
                settings.weightAlphaMax,
                currentWeightAlpha + 0.01,
              );
            } else if (avgRelError > 0.75) {
              currentWeightAlpha = max(
                settings.weightAlphaMin,
                currentWeightAlpha - 0.01,
              );
            }
          }
          currentWeightEma =
              (rawWeights[i]! * currentWeightAlpha) +
              (previousWeightEma * (1 - currentWeightAlpha));
        } else {
          currentWeightEma = previousWeightEma; // Carry forward if missing
        }
      }
      weightEmaHistory.add(currentWeightEma);
      previousWeightEma = currentWeightEma;
    }
    double finalTrueWeight =
        weightEmaHistory.isNotEmpty ? weightEmaHistory.last : 0.0;

    // --- 2. "Average Calorie Intake" (CalorieEMA) & Dynamic Alpha_Calorie ---
    double previousCalorieEma = 0.0;
    List<int> recentCaloriesForCv = [];
    int missingDaysInWindow = 0;
    int calorieWindowSize = 10;

    for (int i = 0; i < rawCalories.length; i++) {
      double currentCalorieEma;
      if (i == 0) {
        currentCalorieEma = (rawCalories[i] ?? 0).toDouble(); // Seed
      } else {
        if (rawCalories[i] != null) {
          // Update recent calories for CV calculation
          recentCaloriesForCv.add(rawCalories[i]!);
          if (recentCaloriesForCv.length > calorieWindowSize) {
            recentCaloriesForCv.removeAt(0);
          }
          // Update missing days count (simplified: assumes current day is NOT missing if rawCalories[i] is not null)
          // A more robust approach would be to check the actual dates if available
          if (i >= calorieWindowSize) {
            missingDaysInWindow =
                rawCalories
                    .sublist(i - calorieWindowSize, i)
                    .where((c) => c == null)
                    .length;
          } else {
            missingDaysInWindow =
                rawCalories.sublist(0, i).where((c) => c == null).length;
          }

          // Adjust alpha_calorie
          if (recentCaloriesForCv.length >=
                  calorieWindowSize - missingDaysInWindow &&
              recentCaloriesForCv.isNotEmpty) {
            // Ensure enough data for CV
            double mean =
                recentCaloriesForCv.reduce((a, b) => a + b) /
                recentCaloriesForCv.length;
            double stdDev = 0.0;
            if (mean != 0 && recentCaloriesForCv.length > 1) {
              stdDev = sqrt(
                recentCaloriesForCv
                        .map((x) => pow(x - mean, 2))
                        .reduce((a, b) => a + b) /
                    (recentCaloriesForCv.length - 1),
              );
            }
            double cv =
                (mean == 0)
                    ? 1.0
                    : (stdDev /
                        mean); // Handle mean == 0 to avoid division by zero; treat as high variance.
            double missingPercent =
                (calorieWindowSize == 0)
                    ? 0.0
                    : (missingDaysInWindow / calorieWindowSize) * 100.0;

            if (cv < 0.20 && missingPercent < 15.0) {
              currentCalorieAlpha = min(
                settings.calorieAlphaMax,
                currentCalorieAlpha + 0.01,
              );
            } else if (cv > 0.35 || missingPercent > 30.0) {
              currentCalorieAlpha = max(
                settings.calorieAlphaMin,
                currentCalorieAlpha - 0.01,
              );
            }
          }
          currentCalorieEma =
              (rawCalories[i]!.toDouble() * currentCalorieAlpha) +
              (previousCalorieEma * (1 - currentCalorieAlpha));
        } else {
          currentCalorieEma = previousCalorieEma; // Carry forward
        }
      }
      calorieEmaHistory.add(currentCalorieEma);
      previousCalorieEma = currentCalorieEma;
    }
    double finalAverageCalories =
        calorieEmaHistory.isNotEmpty ? calorieEmaHistory.last : 0.0;

    // --- 3. "Actual Weight Trend" Calculation ---
    for (int i = 0; i < weightEmaHistory.length; i++) {
      if (i == 0) {
        dailyWeightDeltaHistory.add(0.0); // No delta for the first day
      } else {
        // Basic outlier detection for daily delta (e.g. >5% of bodyweight change in a day is unlikely)
        double delta = weightEmaHistory[i] - weightEmaHistory[i - 1];
        if (weightEmaHistory[i - 1] != 0 &&
            (delta.abs() / weightEmaHistory[i - 1]).abs() > 0.05) {
          // If delta is an extreme outlier, dampen it or use 0. For simplicity, using 0.
          dailyWeightDeltaHistory.add(0.0);
        } else {
          dailyWeightDeltaHistory.add(delta);
        }
      }
    }

    double finalWeightTrendPerDay = 0.0;
    if (dailyWeightDeltaHistory.length >= settings.trendSmoothingDays) {
      finalWeightTrendPerDay =
          dailyWeightDeltaHistory
              .sublist(
                dailyWeightDeltaHistory.length - settings.trendSmoothingDays,
              )
              .reduce((a, b) => a + b) /
          settings.trendSmoothingDays;
    } else if (dailyWeightDeltaHistory.isNotEmpty) {
      finalWeightTrendPerDay =
          dailyWeightDeltaHistory.reduce((a, b) => a + b) /
          dailyWeightDeltaHistory.length;
    }
    double finalWeightTrendPerWeek = finalWeightTrendPerDay * 7;

    // --- 4. TDEE Estimation (Algorithm) ---
    double energyEquivalent = _getEnergyEquivalent(
      settings,
    ); // Based on lbs/kg unit
    double estimatedTdeeAlgo = 0.0;

    if (calorieEmaHistory.isNotEmpty &&
        weightEmaHistory.length >= _minDaysForTrend) {
      // Only calculate TDEE if there's a meaningful calorie EMA and enough weight data for a trend
      double lastCalorieEma = calorieEmaHistory.last;
      estimatedTdeeAlgo =
          lastCalorieEma - (energyEquivalent * finalWeightTrendPerDay);

      // Basic plausibility check for TDEE
      if (estimatedTdeeAlgo < 500 || estimatedTdeeAlgo > 7000) {
        // If TDEE is implausible, try to use previous day's TDEE or a fallback
        if (tdeeAlgoHistory.isNotEmpty &&
            tdeeAlgoHistory.last > 500 &&
            tdeeAlgoHistory.last < 7000) {
          estimatedTdeeAlgo = tdeeAlgoHistory.last;
        } else {
          estimatedTdeeAlgo = _calculateStandardTdee(
            settings,
            finalTrueWeight,
          ); // Fallback to standard
        }
      }
      tdeeAlgoHistory.add(estimatedTdeeAlgo);
    } else if (tdeeAlgoHistory.isNotEmpty) {
      estimatedTdeeAlgo =
          tdeeAlgoHistory.last; // Carry forward if cannot calculate today
    } else {
      estimatedTdeeAlgo = _calculateStandardTdee(
        settings,
        finalTrueWeight,
      ); // Initial fallback
      tdeeAlgoHistory.add(estimatedTdeeAlgo);
    }

    // --- TDEE Blending (Initial Phase) ---
    double tdeeBlendFactor = 1.0; // Weight for formula TDEE
    if (history.length < _tdeeBlendDurationDays &&
        history.length >= _minDaysForTrend) {
      tdeeBlendFactor =
          pow(
            _initialTdeeBlendDecayFactor,
            history.length - _minDaysForTrend,
          ).toDouble();
      // Ensure blend factor doesn't become too small or negative
      tdeeBlendFactor = max(0.0, min(1.0, tdeeBlendFactor));

      double standardTdeeForBlend = _calculateStandardTdee(
        settings,
        finalTrueWeight,
      );
      estimatedTdeeAlgo =
          (standardTdeeForBlend * tdeeBlendFactor) +
          (estimatedTdeeAlgo * (1 - tdeeBlendFactor));
    } else if (history.length >= _tdeeBlendDurationDays) {
      tdeeBlendFactor = 0.0; // Fully data-driven
    }
    // If less than _minDaysForTrend, estimatedTdeeAlgo is already standardTdee, so blendFactor effectively 1.0

    double finalEstimatedTdeeAlgo = estimatedTdeeAlgo;

    // --- 5. Calorie Target Recommendation (Algorithm) ---
    // Goal rate is % of current true weight per week
    double targetDeficitOrSurplusPerDay = 0;
    if (finalTrueWeight > 0) {
      // Avoid division by zero if true weight is somehow 0
      targetDeficitOrSurplusPerDay =
          (settings.goalRate / 100.0) *
          finalTrueWeight *
          (energyEquivalent / 7.0);
    }
    double targetCaloriesAlgo =
        finalEstimatedTdeeAlgo -
        targetDeficitOrSurplusPerDay; // Subtract deficit, add surplus for goal rate logic

    // --- Standard Formula Calculations (Mifflin-St Jeor for diagnostics) ---
    double estimatedTdeeStandard = _calculateStandardTdee(
      settings,
      finalTrueWeight,
    );
    double targetCaloriesStandard =
        estimatedTdeeStandard -
        targetDeficitOrSurplusPerDay; // Use same deficit/surplus for fair comparison

    // --- Deltas ---
    double deltaTdee = finalEstimatedTdeeAlgo - estimatedTdeeStandard;
    double deltaTarget = targetCaloriesAlgo - targetCaloriesStandard;

    return CalculationResult(
      trueWeight: finalTrueWeight,
      weightTrend: finalWeightTrendPerWeek,
      averageCalories: finalAverageCalories,
      estimatedTdeeAlgo: finalEstimatedTdeeAlgo,
      targetCaloriesAlgo: targetCaloriesAlgo,
      estimatedTdeeStandard: estimatedTdeeStandard,
      targetCaloriesStandard: targetCaloriesStandard,
      deltaTdee: deltaTdee,
      deltaTarget: deltaTarget,
      currentAlphaWeight: currentWeightAlpha,
      currentAlphaCalorie: currentCalorieAlpha,
      tdeeBlendFactorUsed: tdeeBlendFactor,
    );
  }

  double _getEnergyEquivalent(UserSettings settings) {
    // Assuming settings will have a unit system preference in the future.
    // For now, hardcoding to a common scenario or requiring it in UserSettings.
    // Let's assume goalRate is always % of body weight, and we need to determine if user uses lbs or kg.
    // This is a simplification. A robust app would have explicit unit settings.
    // For the validation app, we might assume one unit or make it part of UserSettings if not already.
    // Based on blueprint, user can set lbs/kg in settings.
    // We need a way to know which unit the current 'trueWeight' is in to apply the correct energyEquivalent.
    // For this implementation, let's assume UserSettings has a field like `WeightUnitSystem (enum {lbs, kg})`
    // If not, we'll default to one, e.g., kg, as it's more standard in many places.
    // The blueprint mentions "Units: Weight (lbs/kg)" in settings [cite: 208]

    // TODO: Properly get this from UserSettings. For now, assuming 'kg' if not specified.
    // For the validation app, it might be simpler to just pick one (e.g. kg) or
    // ensure the UserSettings passed in has this preference.
    // Given the prompt, UserSettings doesn't explicitly have a unit system field yet for direct use here.
    // Let's assume the 'goalRate' is tied to the units of 'trueWeight' and 'energyEquivalent'.
    // The blueprint specifies `EnergyEquivalent is approx. 3500 kcal per pound or 7700 kcal per kg` [cite: 105]
    // We need a way to determine which one to use.
    // For simplicity, if settings.height is > 100 it's likely cm (so kg is likely weight unit).
    // If height is < 10, it's likely ft (so lbs is likely weight unit). This is a heuristic.
    bool useKg = true; // Default
    if (settings.height < 10) {
      // Assuming height in feet implies weight in lbs
      useKg = false;
    }
    // A better way would be an explicit UserSettings.weightUnit property.
    return useKg ? _energyEquivalentPerKg : _energyEquivalentPerLb;
  }

  /// Calculates TDEE using Mifflin-St Jeor formula.
  double _calculateStandardTdee(UserSettings settings, double currentWeight) {
    if (currentWeight <= 0) return 0.0; // Cannot calculate with no weight

    double bmr;
    // Convert height to cm if necessary (assuming height in settings is always stored in a consistent unit, e.g. cm for calculations)
    // The blueprint states "Units: Weight (lbs/kg), Height (ft+in/cm)" [cite: 208]
    // This means settings.height could be in cm or a value representing ft+in.
    // For Mifflin-St Jeor, height needs to be in cm and weight in kg.
    // We need robust unit conversion here.

    double weightInKg = currentWeight;
    double heightInCm = settings.height;

    // Heuristic: if height is small (e.g. < 10), assume it's feet and convert.
    // A proper implementation would have units stored with the values or explicit conversion settings.
    bool isImperial = settings.height < 10; // Very rough heuristic

    if (isImperial) {
      // Assume currentWeight is lbs, settings.height is ft
      weightInKg = currentWeight * 0.453592;
      // Assume settings.height is just feet for simplicity here, no inches.
      // A full implementation would parse ft and inches.
      heightInCm = settings.height * 30.48;
    }
    // If not "isImperial" by this heuristic, assume weightInKg is already kg and heightInCm is already cm.

    if (settings.sex == BiologicalSex.male) {
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * settings.age) + 5;
    } else {
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * settings.age) - 161;
    }

    double activityMultiplier;
    switch (settings.activityLevel) {
      case ActivityLevel.sedentary:
        activityMultiplier = 1.2;
        break;
      case ActivityLevel.lightlyActive:
        activityMultiplier = 1.375;
        break;
      case ActivityLevel.moderatelyActive:
        activityMultiplier = 1.55;
        break;
      case ActivityLevel.veryActive:
        activityMultiplier = 1.725;
        break;
      case ActivityLevel.extraActive:
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.2;
    }
    return bmr * activityMultiplier;
  }
}
