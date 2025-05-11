// lib/calculation/calculation_engine.dart
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
  static const double _energyEquivalentPerLb = 3500.0; // kcal/lb
  static const double _energyEquivalentPerKg = 7700.0; // kcal/kg
  static const int _trendSmoothingDays =
      7; // Default, should be overridden by settings
  static const double _initialTdeeBlendDecayFactor = 0.85;
  static const int _tdeeBlendDurationDays = 21; // Approx 3 weeks
  static const int _minDaysForTrend = 5;

  // Unit conversion constants
  static const double _lbsPerKg = 2.20462;
  static const double _kgPerLb = 1 / _lbsPerKg;
  static const double _cmPerInch = 2.54;
  static const double _inchesPerFoot = 12.0;

  /// Runs the full calculation given historical entries and user settings.
  Future<CalculationResult> calculateStatus(
    List<LogEntry> history,
    UserSettings settings,
  ) async {
    if (history.isEmpty) {
      // Calculate standard TDEE even with no history, using profile data
      final standardTdeeInitial = _calculateStandardTdee(settings, 0.0);

      // For zero weight, target calories should be based on standard TDEE
      // Goal rate would be meaningless with zero weight
      final targetStandardInitial = standardTdeeInitial;

      return CalculationResult(
        trueWeight: 0.0,
        weightTrend: 0.0,
        averageCalories: 0.0,
        estimatedTdeeAlgo: 0.0,
        targetCaloriesAlgo: 0.0,
        estimatedTdeeStandard: standardTdeeInitial,
        targetCaloriesStandard:
            targetStandardInitial > 0 ? targetStandardInitial : 0.0,
        deltaTdee: 0.0,
        deltaTarget: 0.0,
        currentAlphaWeight: settings.weightAlpha,
        currentAlphaCalorie: settings.calorieAlpha,
        tdeeBlendFactorUsed: 1.0, // Using 100% standard TDEE when no data
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
        // Initialize with first weight value or 0
        currentWeightEma = rawWeights[i] ?? 0.0;
      } else {
        if (rawWeights[i] != null) {
          // Calculate relative prediction error for dynamic alpha adjustment
          if (previousWeightEma > 0) {
            double error =
                ((rawWeights[i]! - previousWeightEma).abs() /
                    previousWeightEma) *
                100.0;
            relativePredictionErrors.add(error);
            if (relativePredictionErrors.length > settings.trendSmoothingDays) {
              relativePredictionErrors.removeAt(
                0,
              ); // Keep only most recent errors
            }
          }

          // Adjust alpha_weight based on recent errors
          if (relativePredictionErrors.length == settings.trendSmoothingDays) {
            double avgRelError =
                relativePredictionErrors.reduce((a, b) => a + b) /
                settings.trendSmoothingDays;

            if (avgRelError < 0.25) {
              // Weight is very stable - increase responsiveness
              currentWeightAlpha = min(
                settings.weightAlphaMax,
                currentWeightAlpha + 0.01,
              );
            } else if (avgRelError > 0.75) {
              // Weight is fluctuating a lot - increase smoothing
              currentWeightAlpha = max(
                settings.weightAlphaMin,
                currentWeightAlpha - 0.01,
              );
            }
            // Otherwise keep alpha the same
          }

          // Calculate today's EMA using current alpha
          currentWeightEma =
              (rawWeights[i]! * currentWeightAlpha) +
              (previousWeightEma * (1 - currentWeightAlpha));
        } else {
          // No weight data today - carry forward yesterday's EMA
          currentWeightEma = previousWeightEma;
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
    int calorieWindowSize = 10; // As per blueprint for CV calculation

    for (int i = 0; i < rawCalories.length; i++) {
      double currentCalorieEma;
      if (i == 0) {
        // Initialize with first calorie value or 0
        currentCalorieEma = (rawCalories[i] ?? 0).toDouble();
      } else {
        if (rawCalories[i] != null) {
          // Track recent calories for coefficient of variation calculation
          recentCaloriesForCv.add(rawCalories[i]!);
          if (recentCaloriesForCv.length > calorieWindowSize) {
            recentCaloriesForCv.removeAt(0); // Keep only most recent values
          }

          // Count missing days in recent window (for data quality assessment)
          int startSublist = max(0, i - calorieWindowSize + 1);
          if (i + 1 >= calorieWindowSize) {
            // If we have a full window of data
            missingDaysInWindow =
                rawCalories
                    .sublist(startSublist, i + 1)
                    .where((c) => c == null)
                    .length;
          } else {
            // If we don't have a full window yet
            missingDaysInWindow =
                rawCalories.sublist(0, i + 1).where((c) => c == null).length;
          }

          // Adjust alpha_calorie based on data consistency and completeness
          if (recentCaloriesForCv.length >=
                  (calorieWindowSize - missingDaysInWindow) &&
              recentCaloriesForCv.isNotEmpty) {
            // Calculate coefficient of variation (CV)
            double mean =
                recentCaloriesForCv.reduce((a, b) => a + b) /
                recentCaloriesForCv.length;
            double stdDev = 0.0;
            if (mean > 0 && recentCaloriesForCv.length > 1) {
              stdDev = sqrt(
                recentCaloriesForCv
                        .map((x) => pow(x - mean, 2))
                        .reduce((a, b) => a + b) /
                    (recentCaloriesForCv.length - 1),
              );
            }
            double cv = (mean == 0) ? 1.0 : (stdDev / mean);
            double missingPercent =
                (calorieWindowSize == 0)
                    ? 0.0
                    : (missingDaysInWindow / calorieWindowSize) * 100.0;

            // Adjust alpha based on data quality metrics
            if (cv < 0.20 && missingPercent < 15.0) {
              // Data is consistent and complete - increase responsiveness
              currentCalorieAlpha = min(
                settings.calorieAlphaMax,
                currentCalorieAlpha + 0.01,
              );
            } else if (cv > 0.35 || missingPercent > 30.0) {
              // Data is inconsistent or incomplete - increase smoothing
              currentCalorieAlpha = max(
                settings.calorieAlphaMin,
                currentCalorieAlpha - 0.01,
              );
            }
            // Otherwise keep alpha the same
          }

          // Calculate today's calorie EMA
          currentCalorieEma =
              (rawCalories[i]!.toDouble() * currentCalorieAlpha) +
              (previousCalorieEma * (1 - currentCalorieAlpha));
        } else {
          // No calorie data today - carry forward yesterday's EMA
          currentCalorieEma = previousCalorieEma;
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
        // No delta for the first day
        dailyWeightDeltaHistory.add(0.0);
      } else {
        double delta = weightEmaHistory[i] - weightEmaHistory[i - 1];

        // Detect and dampen extreme outliers that are likely errors
        if (weightEmaHistory[i - 1] > 0 &&
            (delta.abs() / weightEmaHistory[i - 1]).abs() > 0.05) {
          dailyWeightDeltaHistory.add(0.0); // 5% daily change is excessive
        } else {
          dailyWeightDeltaHistory.add(delta);
        }
      }
    }

    // Calculate smoothed trend over specified period
    double finalWeightTrendPerDay = 0.0;
    if (dailyWeightDeltaHistory.length >= settings.trendSmoothingDays) {
      // Use the most recent N days for the trend
      finalWeightTrendPerDay =
          dailyWeightDeltaHistory
              .sublist(
                dailyWeightDeltaHistory.length - settings.trendSmoothingDays,
              )
              .reduce((a, b) => a + b) /
          settings.trendSmoothingDays;
    } else if (dailyWeightDeltaHistory.isNotEmpty) {
      // Use all available days if we don't have enough
      finalWeightTrendPerDay =
          dailyWeightDeltaHistory.reduce((a, b) => a + b) /
          dailyWeightDeltaHistory.length;
    }
    double finalWeightTrendPerWeek = finalWeightTrendPerDay * 7;

    // --- 4. TDEE Estimation (Algorithm) ---
    // Get appropriate energy equivalent based on weight unit setting
    double energyEquivalent = _getEnergyEquivalent(settings);
    double estimatedTdeeAlgo = 0.0;

    if (calorieEmaHistory.isNotEmpty &&
        weightEmaHistory.length >= _minDaysForTrend) {
      // Calculate TDEE using energy balance principle:
      // TDEE = Calories In - (Energy Equivalent * Weight Change)
      double lastCalorieEma = calorieEmaHistory.last;
      estimatedTdeeAlgo =
          lastCalorieEma - (energyEquivalent * finalWeightTrendPerDay);

      // Sanity check - TDEE should be within reasonable bounds
      if (estimatedTdeeAlgo < 500 || estimatedTdeeAlgo > 7000) {
        // If current estimate is unreasonable but we have previous estimates
        if (tdeeAlgoHistory.isNotEmpty &&
            tdeeAlgoHistory.last > 500 &&
            tdeeAlgoHistory.last < 7000) {
          estimatedTdeeAlgo = tdeeAlgoHistory.last; // Use previous estimate
        } else {
          // Use standard formula as fallback
          estimatedTdeeAlgo = _calculateStandardTdee(settings, finalTrueWeight);
        }
      }

      tdeeAlgoHistory.add(estimatedTdeeAlgo);
    } else if (tdeeAlgoHistory.isNotEmpty) {
      // Use previous estimate if available
      estimatedTdeeAlgo = tdeeAlgoHistory.last;
    } else {
      // Initial fallback to standard formula
      estimatedTdeeAlgo = _calculateStandardTdee(settings, finalTrueWeight);
      tdeeAlgoHistory.add(estimatedTdeeAlgo);
    }

    // --- TDEE Blending (Initial Phase) ---
    // During initial weeks, blend algorithm TDEE with standard formula
    double tdeeBlendFactor = 1.0; // Default: 100% standard formula

    if (history.length < _tdeeBlendDurationDays &&
        history.length >= _minDaysForTrend) {
      // Calculate blend factor that decays over time
      tdeeBlendFactor =
          pow(
            _initialTdeeBlendDecayFactor,
            history.length - _minDaysForTrend,
          ).toDouble();
      tdeeBlendFactor = max(0.0, min(1.0, tdeeBlendFactor));

      // Blend the standard TDEE with algorithm TDEE
      double standardTdeeForBlend = _calculateStandardTdee(
        settings,
        finalTrueWeight,
      );
      estimatedTdeeAlgo =
          (standardTdeeForBlend * tdeeBlendFactor) +
          (estimatedTdeeAlgo * (1 - tdeeBlendFactor));
    } else if (history.length >= _tdeeBlendDurationDays) {
      tdeeBlendFactor = 0.0; // Fully data-driven after transition period
    }

    double finalEstimatedTdeeAlgo = estimatedTdeeAlgo;

    // --- 5. Calorie Target Recommendation (Algorithm) ---
    double targetDeficitOrSurplusPerDay = 0;
    if (finalTrueWeight > 0) {
      // Calculate target daily deficit/surplus from goal rate and weight
      targetDeficitOrSurplusPerDay =
          (settings.goalRate / 100.0) *
          finalTrueWeight *
          (energyEquivalent / 7.0);
    }

    // Target = TDEE - Deficit (for weight loss) or TDEE + Surplus (for gain)
    double targetCaloriesAlgo =
        finalEstimatedTdeeAlgo - targetDeficitOrSurplusPerDay;

    // --- Standard Formula Calculations (for comparison) ---
    double estimatedTdeeStandard = _calculateStandardTdee(
      settings,
      finalTrueWeight,
    );
    double targetCaloriesStandard =
        estimatedTdeeStandard - targetDeficitOrSurplusPerDay;

    // --- Deltas for diagnostic purposes ---
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

  /// Returns the appropriate energy equivalent based on weight unit setting
  double _getEnergyEquivalent(UserSettings settings) {
    if (settings.weightUnit == WeightUnitSystem.lbs) {
      return _energyEquivalentPerLb;
    } else {
      return _energyEquivalentPerKg;
    }
  }

  /// Calculates TDEE using standard Mifflin-St Jeor formula.
  /// Handles unit conversions appropriately based on settings.
  double _calculateStandardTdee(UserSettings settings, double currentWeight) {
    // Early exit for invalid inputs to avoid calculation errors
    if (currentWeight <= 0 && settings.height <= 0 && settings.age <= 0) {
      return 0.0;
    }

    // --- 1. Convert all inputs to metric for the formula ---
    // Convert weight to kg (formula requires kg)
    double weightInKg;
    if (settings.weightUnit == WeightUnitSystem.lbs) {
      weightInKg = currentWeight * _kgPerLb;
    } else {
      weightInKg = currentWeight; // Already in kg
    }

    // Ensure weight is valid for calculations
    if (weightInKg <= 0) weightInKg = 0;

    // Convert height to cm (formula requires cm)
    double heightInCm;
    if (settings.heightUnit == HeightUnitSystem.ft_in) {
      // Height is stored as total inches if ft_in is selected
      heightInCm = settings.height * _cmPerInch;
    } else {
      heightInCm = settings.height; // Already in cm
    }

    // Ensure height is valid for calculations
    if (heightInCm <= 0) heightInCm = 0;

    // --- 2. Calculate BMR using Mifflin-St Jeor formula ---
    double bmr;
    if (settings.sex == BiologicalSex.male) {
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * settings.age) + 5;
    } else {
      // Female formula
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * settings.age) - 161;
    }

    // Ensure BMR is not negative
    bmr = max(0, bmr);

    // --- 3. Apply activity multiplier ---
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
        activityMultiplier = 1.2; // Default to sedentary
    }

    // --- 4. Calculate and return TDEE ---
    return bmr * activityMultiplier;
  }
}
