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
  static const double _energyEquivalentPerLb = 3500.0;
  static const double _energyEquivalentPerKg = 7700.0;
  static const int _trendSmoothingDays =
      7; // Default, should come from settings
  static const double _initialTdeeBlendDecayFactor = 0.85;
  static const int _tdeeBlendDurationDays = 21; // Approx 3 weeks
  static const int _minDaysForTrend = 5;

  // START OF CHANGES: Constants for conversions
  static const double _lbsPerKg = 2.20462;
  static const double _kgPerLb = 1 / _lbsPerKg;
  static const double _cmPerInch = 2.54;
  static const double _inchesPerFoot = 12.0;
  // END OF CHANGES

  /// Runs the full calculation given historical entries and user settings.
  Future<CalculationResult> calculateStatus(
    List<LogEntry> history,
    UserSettings settings,
  ) async {
    if (history.isEmpty) {
      // Not enough data to calculate anything meaningful
      // Calculate standard TDEE even with no history, using profile data (weight 0)
      final standardTdeeInitial = _calculateStandardTdee(settings, 0.0);
      // Target calories would also be based on this potentially zero TDEE
      // and a goal rate, which might not be meaningful.
      // For an empty history, target can also be 0 or based on standard TDEE.
      final targetDeficitOrSurplusPerDay =
          (settings.goalRate / 100.0) *
          0.0 *
          (_getEnergyEquivalent(settings) / 7.0); // Based on 0 weight
      final targetStandardInitial =
          standardTdeeInitial - targetDeficitOrSurplusPerDay;

      return CalculationResult(
        trueWeight: 0.0,
        weightTrend: 0.0,
        averageCalories: 0.0,
        estimatedTdeeAlgo: 0.0, // No data for algo TDEE
        targetCaloriesAlgo: 0.0, // No data for algo target
        estimatedTdeeStandard: standardTdeeInitial,
        targetCaloriesStandard:
            targetStandardInitial > 0 ? targetStandardInitial : 0.0,
        deltaTdee: 0.0, // Algo TDEE is 0, standard TDEE might be calculated
        deltaTarget: 0.0,
        currentAlphaWeight: settings.weightAlpha,
        currentAlphaCalorie: settings.calorieAlpha,
        tdeeBlendFactorUsed:
            1.0, // Effectively using 100% standard if algo TDEE is 0
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
            if (relativePredictionErrors.length > settings.trendSmoothingDays) {
              // Use setting
              relativePredictionErrors.removeAt(0);
            }
          }

          // Adjust alpha_weight
          if (relativePredictionErrors.length == settings.trendSmoothingDays) {
            // Use setting
            double avgRelError =
                relativePredictionErrors.reduce((a, b) => a + b) /
                settings.trendSmoothingDays; // Use setting
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
    int calorieWindowSize = 10; // As per blueprint for CV calc

    for (int i = 0; i < rawCalories.length; i++) {
      double currentCalorieEma;
      if (i == 0) {
        currentCalorieEma = (rawCalories[i] ?? 0).toDouble(); // Seed
      } else {
        if (rawCalories[i] != null) {
          recentCaloriesForCv.add(rawCalories[i]!);
          if (recentCaloriesForCv.length > calorieWindowSize) {
            recentCaloriesForCv.removeAt(0);
          }

          int startSublist = max(
            0,
            i - calorieWindowSize + 1,
          ); // ensure non-negative
          if (i + 1 >= calorieWindowSize) {
            // check if current index i is part of a full window
            missingDaysInWindow =
                rawCalories
                    .sublist(
                      startSublist,
                      i + 1,
                    ) // sublist up to current index i
                    .where((c) => c == null)
                    .length;
          } else {
            // if not a full window yet (less than 10 days of data)
            missingDaysInWindow =
                rawCalories
                    .sublist(
                      0,
                      i + 1,
                    ) // sublist from beginning up to current index i
                    .where((c) => c == null)
                    .length;
          }

          if (recentCaloriesForCv.length >=
                  (calorieWindowSize - missingDaysInWindow) &&
              recentCaloriesForCv.isNotEmpty) {
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
            double cv = (mean == 0) ? 1.0 : (stdDev / mean);
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
        double delta = weightEmaHistory[i] - weightEmaHistory[i - 1];
        if (weightEmaHistory[i - 1] != 0 &&
            (delta.abs() / weightEmaHistory[i - 1]).abs() > 0.05) {
          dailyWeightDeltaHistory.add(0.0); // Dampen extreme outlier
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
    double energyEquivalent = _getEnergyEquivalent(settings);
    double estimatedTdeeAlgo = 0.0;

    if (calorieEmaHistory.isNotEmpty &&
        weightEmaHistory.length >= _minDaysForTrend) {
      double lastCalorieEma = calorieEmaHistory.last;
      estimatedTdeeAlgo =
          lastCalorieEma - (energyEquivalent * finalWeightTrendPerDay);
      if (estimatedTdeeAlgo < 500 || estimatedTdeeAlgo > 7000) {
        if (tdeeAlgoHistory.isNotEmpty &&
            tdeeAlgoHistory.last > 500 &&
            tdeeAlgoHistory.last < 7000) {
          estimatedTdeeAlgo = tdeeAlgoHistory.last;
        } else {
          estimatedTdeeAlgo = _calculateStandardTdee(settings, finalTrueWeight);
        }
      }
      tdeeAlgoHistory.add(estimatedTdeeAlgo);
    } else if (tdeeAlgoHistory.isNotEmpty) {
      estimatedTdeeAlgo = tdeeAlgoHistory.last; // Carry forward
    } else {
      estimatedTdeeAlgo = _calculateStandardTdee(
        settings,
        finalTrueWeight,
      ); // Initial fallback
      tdeeAlgoHistory.add(estimatedTdeeAlgo);
    }

    // --- TDEE Blending (Initial Phase) ---
    double tdeeBlendFactor = 1.0;
    if (history.length < _tdeeBlendDurationDays &&
        history.length >= _minDaysForTrend) {
      tdeeBlendFactor =
          pow(
            _initialTdeeBlendDecayFactor,
            history.length - _minDaysForTrend,
          ).toDouble();
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
    // If less than _minDaysForTrend, estimatedTdeeAlgo is already standardTdee via fallback

    double finalEstimatedTdeeAlgo = estimatedTdeeAlgo;

    // --- 5. Calorie Target Recommendation (Algorithm) ---
    double targetDeficitOrSurplusPerDay = 0;
    if (finalTrueWeight > 0) {
      targetDeficitOrSurplusPerDay =
          (settings.goalRate / 100.0) *
          finalTrueWeight *
          (energyEquivalent / 7.0);
    }
    double targetCaloriesAlgo =
        finalEstimatedTdeeAlgo - targetDeficitOrSurplusPerDay;

    // --- Standard Formula Calculations (Mifflin-St Jeor for diagnostics) ---
    double estimatedTdeeStandard = _calculateStandardTdee(
      settings,
      finalTrueWeight,
    );
    double targetCaloriesStandard =
        estimatedTdeeStandard - targetDeficitOrSurplusPerDay;

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
    // START OF CHANGES: Use explicit unit setting
    if (settings.weightUnit == WeightUnitSystem.lbs) {
      return _energyEquivalentPerLb;
    } else {
      // Default or kg
      return _energyEquivalentPerKg;
    }
    // END OF CHANGES
  }

  /// Calculates TDEE using Mifflin-St Jeor formula.
  /// `currentWeight` is assumed to be in the unit specified by `settings.weightUnit`.
  double _calculateStandardTdee(UserSettings settings, double currentWeight) {
    if (currentWeight <= 0 && settings.height <= 0)
      return 0.0; // Cannot calculate with no weight or height

    double weightInKg;
    double heightInCm;

    // START OF CHANGES: Convert weight and height based on explicit unit settings
    // Convert currentWeight to KG for the formula
    if (settings.weightUnit == WeightUnitSystem.lbs) {
      weightInKg = currentWeight * _kgPerLb;
    } else {
      // Already in KG or default
      weightInKg = currentWeight;
    }
    if (currentWeight <= 0)
      weightInKg = 0; // Ensure non-negative for formula after conversion

    // Convert settings.height to CM for the formula
    if (settings.heightUnit == HeightUnitSystem.ft_in) {
      // Assuming settings.height stores total inches if ft_in is selected
      // e.g., 5 feet 6 inches = 66 inches.
      // A more complex setup might involve separate feet and inches fields.
      heightInCm = settings.height * _cmPerInch;
    } else {
      // Already in CM or default
      heightInCm = settings.height;
    }
    if (settings.height <= 0) heightInCm = 0; // Ensure non-negative
    // END OF CHANGES

    // If after conversion, weight or height is still not positive, BMR part of formula might be weird.
    // Return 0 if critical values are not positive.
    if (weightInKg <= 0 && heightInCm <= 0 && settings.age <= 0) return 0.0;
    // Allow calculation if at least one stat is positive, formula handles 0s for others.

    double bmr;
    if (settings.sex == BiologicalSex.male) {
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * settings.age) + 5;
    } else {
      // female
      bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * settings.age) - 161;
    }
    // Ensure BMR is not negative if inputs are very small or age is very high.
    if (bmr < 0) bmr = 0;

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
        activityMultiplier = 1.2; // Should not happen if settings are valid
    }
    return bmr * activityMultiplier;
  }
}
