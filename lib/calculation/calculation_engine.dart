// lib/calculation/calculation_engine.dart
import 'dart:math';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/database/log_entry.dart';

/// Simple matrix implementation for Kalman filter calculations
class Matrix {
  final List<List<double>> data;

  Matrix(this.data);

  factory Matrix.column(List<double> values) {
    return Matrix(values.map((v) => [v]).toList());
  }

  factory Matrix.row(List<double> values) {
    return Matrix([values]);
  }

  factory Matrix.diagonal(List<double> values) {
    final n = values.length;
    final result = List.generate(n, (_) => List.filled(n, 0.0));
    for (int i = 0; i < n; i++) {
      result[i][i] = values[i];
    }
    return Matrix(result);
  }

  factory Matrix.identity(int n) {
    return Matrix.diagonal(List.filled(n, 1.0));
  }

  int get rows => data.length;
  int get cols => data.isEmpty ? 0 : data[0].length;

  Matrix operator +(Matrix other) {
    assert(rows == other.rows && cols == other.cols);
    final result = List.generate(
      rows,
      (i) => List.generate(cols, (j) => data[i][j] + other.data[i][j]),
    );
    return Matrix(result);
  }

  Matrix operator -(Matrix other) {
    assert(rows == other.rows && cols == other.cols);
    final result = List.generate(
      rows,
      (i) => List.generate(cols, (j) => data[i][j] - other.data[i][j]),
    );
    return Matrix(result);
  }

  Matrix operator *(Matrix other) {
    assert(cols == other.rows);
    final result = List.generate(
      rows,
      (i) => List.generate(other.cols, (j) {
        double sum = 0.0;
        for (int k = 0; k < cols; k++) {
          sum += data[i][k] * other.data[k][j];
        }
        return sum;
      }),
    );
    return Matrix(result);
  }

  Matrix transpose() {
    final result = List.generate(
      cols,
      (j) => List.generate(rows, (i) => data[i][j]),
    );
    return Matrix(result);
  }

  Matrix inverse() {
    assert(rows == cols); // Only square matrices can be inverted
    if (rows == 1) {
      return Matrix([
        [1.0 / data[0][0]],
      ]);
    } else if (rows == 2) {
      final a = data[0][0];
      final b = data[0][1];
      final c = data[1][0];
      final d = data[1][1];
      final det = a * d - b * c;
      assert(det != 0);
      return Matrix([
        [d / det, -b / det],
        [-c / det, a / det],
      ]);
    } else {
      throw UnimplementedError('Matrix inverse not implemented for sizes > 2');
    }
  }

  double getValue(int row, int col) => data[row][col];

  @override
  String toString() {
    return data.map((row) => row.join(', ')).join('\n');
  }
}

/// Two-state Kalman filter implementation for weight tracking
/// Maintains separate estimates for weight level and weight change rate
class WeightKalmanFilter {
  // State vector: [weight, weight_change_rate]
  Matrix _x; // State estimate
  Matrix _P; // Error covariance
  Matrix _F; // State transition matrix
  Matrix _H; // Observation matrix
  Matrix _Q; // Process noise covariance
  Matrix _R; // Measurement noise covariance
  double _processNoiseWeight; // Process noise for weight
  double _processNoiseRate; // Process noise for rate
  double _measurementNoise; // Measurement noise
  double _dt; // Time step (in days)

  WeightKalmanFilter({
    required double initialWeight,
    double initialChangeRate = 0.0,
    required double processNoiseWeight,
    required double processNoiseRate,
    required double measurementNoise,
    double dt = 1.0, // Default time step is 1 day
  }) : _processNoiseWeight = processNoiseWeight,
       _processNoiseRate = processNoiseRate,
       _measurementNoise = measurementNoise,
       _dt = dt,
       // Initialize state vector [weight, weight_change_rate]
       _x = Matrix.column([initialWeight, initialChangeRate]),
       // Initialize error covariance with initial uncertainty
       _P = Matrix.diagonal([1.0, 0.01]),
       // State transition matrix (assuming constant change rate)
       _F = Matrix([
         [1.0, dt], // weight = previous_weight + change_rate * dt
         [0.0, 1.0], // change_rate = previous_change_rate
       ]),
       // Observation matrix (we only observe weight, not change rate)
       _H = Matrix([
         [1.0, 0.0],
       ]),
       // Process noise covariance
       _Q = Matrix.diagonal([processNoiseWeight, processNoiseRate]),
       // Measurement noise covariance
       _R = Matrix([
         [measurementNoise],
       ]);

  /// Updates the filter with a new weight measurement
  void update(double weightMeasurement) {
    // --- Predict step ---
    // Project state ahead: x = F*x
    _x = _F * _x;
    // Project error covariance ahead: P = F*P*F' + Q
    _P = _F * _P * _F.transpose() + _Q;

    // --- Update step ---
    // Innovation (measurement residual): y = z - H*x
    Matrix y = Matrix.column([weightMeasurement]) - _H * _x;
    // Innovation covariance: S = H*P*H' + R
    Matrix S = _H * _P * _H.transpose() + _R;
    // Kalman gain: K = P*H'*S^-1
    Matrix K = _P * _H.transpose() * S.inverse();

    // Update state estimate: x = x + K*y
    _x = _x + K * y;
    // Update error covariance: P = (I - K*H)*P
    _P = (Matrix.identity(2) - K * _H) * _P;
  }

  /// Returns the current weight estimate
  double get weightEstimate => _x.getValue(0, 0);

  /// Returns the current weight change rate (units per day)
  double get changeRateEstimate => _x.getValue(1, 0);

  /// Returns the current weight change rate (units per week)
  double get weeklyChangeRateEstimate => changeRateEstimate * 7.0;

  /// Returns the error covariance for weight
  double get weightVariance => _P.getValue(0, 0);

  /// Returns the error covariance for rate
  double get rateVariance => _P.getValue(1, 1);

  /// Updates filter parameters if needed
  void updateParameters({
    double? processNoiseWeight,
    double? processNoiseRate,
    double? measurementNoise,
    double? dt,
  }) {
    bool parametersChanged = false;

    if (processNoiseWeight != null &&
        processNoiseWeight != _processNoiseWeight) {
      _processNoiseWeight = processNoiseWeight;
      parametersChanged = true;
    }

    if (processNoiseRate != null && processNoiseRate != _processNoiseRate) {
      _processNoiseRate = processNoiseRate;
      parametersChanged = true;
    }

    if (measurementNoise != null && measurementNoise != _measurementNoise) {
      _measurementNoise = measurementNoise;
      parametersChanged = true;
      _R = Matrix([
        [measurementNoise],
      ]);
    }

    if (dt != null && dt != _dt) {
      _dt = dt;
      parametersChanged = true;
      // Update state transition matrix with new dt
      _F = Matrix([
        [1.0, dt], // weight = previous_weight + change_rate * dt
        [0.0, 1.0], // change_rate = previous_change_rate
      ]);
    }

    if (parametersChanged) {
      // Update process noise covariance
      _Q = Matrix.diagonal([_processNoiseWeight, _processNoiseRate]);
    }
  }

  // TODO: Implement self-tuning parameter adaptation based on innovation sequence
  // This would analyze the sequence of measurement residuals (innovations)
  // and automatically adjust the process and measurement noise parameters
  // to optimize filter performance for each user's unique weight fluctuation patterns.

  // TODO: Add methods to detect and handle outliers in the measurement stream
  // by dynamically adjusting the measurement noise when suspicious values are detected

  // TODO: Implement methods to detect changes in the process dynamics
  // (e.g., when a user changes diet or exercise habits) and adapt the filter parameters
  // accordingly to respond more quickly to genuine changes in trends
}

/// Configuration for the algorithm parameters (Kalman filter and EMA)
class AlgorithmParameters {
  // Two-state Kalman filter parameters for weight trend estimation
  final double
  processNoiseVariance; // Process noise variance for weight (Q_weight)
  final double measurementNoiseVariance; // Measurement noise variance (R)
  final double
  processNoiseRateVariance; // Process noise variance for rate (Q_rate)
  final bool useKalmanFilter; // Toggle between Kalman filter and legacy EMA

  // Legacy weight EMA parameters (kept for backward compatibility)
  final double weightAlpha; // Current smoothing factor for weight
  final double weightAlphaMin; // Lower bound for dynamic weight alpha
  final double weightAlphaMax; // Upper bound for dynamic weight alpha

  // Calorie EMA parameters
  final double calorieAlpha; // Current smoothing factor for calories
  final double calorieAlphaMin; // Lower bound for dynamic calorie alpha
  final double calorieAlphaMax; // Upper bound for dynamic calorie alpha

  // Trend calculation parameters
  final int trendSmoothingDays; // Days used for trend calculation

  // Constants for TDEE blending
  static const double _initialTdeeBlendDecayFactor = 0.85;
  static const int _tdeeBlendDurationDays = 21; // Approx 3 weeks
  static const int _minDaysForTrend = 5;

  // Default constructor with reasonable defaults
  AlgorithmParameters({
    this.processNoiseVariance = 0.01,
    this.measurementNoiseVariance = 0.25,
    this.processNoiseRateVariance = 0.001, // Much smaller than weight noise
    this.useKalmanFilter = true, // Default to using Kalman filter
    this.weightAlpha = 0.1,
    this.weightAlphaMin = 0.05,
    this.weightAlphaMax = 0.2,
    this.calorieAlpha = 0.1,
    this.calorieAlphaMin = 0.05,
    this.calorieAlphaMax = 0.2,
    this.trendSmoothingDays = 7,
  });

  // Create a copy with some values changed
  AlgorithmParameters copyWith({
    double? processNoiseVariance,
    double? measurementNoiseVariance,
    double? processNoiseRateVariance,
    bool? useKalmanFilter,
    double? weightAlpha,
    double? weightAlphaMin,
    double? weightAlphaMax,
    double? calorieAlpha,
    double? calorieAlphaMin,
    double? calorieAlphaMax,
    int? trendSmoothingDays,
  }) {
    return AlgorithmParameters(
      processNoiseVariance: processNoiseVariance ?? this.processNoiseVariance,
      measurementNoiseVariance:
          measurementNoiseVariance ?? this.measurementNoiseVariance,
      processNoiseRateVariance:
          processNoiseRateVariance ?? this.processNoiseRateVariance,
      useKalmanFilter: useKalmanFilter ?? this.useKalmanFilter,
      weightAlpha: weightAlpha ?? this.weightAlpha,
      weightAlphaMin: weightAlphaMin ?? this.weightAlphaMin,
      weightAlphaMax: weightAlphaMax ?? this.weightAlphaMax,
      calorieAlpha: calorieAlpha ?? this.calorieAlpha,
      calorieAlphaMin: calorieAlphaMin ?? this.calorieAlphaMin,
      calorieAlphaMax: calorieAlphaMax ?? this.calorieAlphaMax,
      trendSmoothingDays: trendSmoothingDays ?? this.trendSmoothingDays,
    );
  }

  // Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'processNoiseVariance': processNoiseVariance,
      'measurementNoiseVariance': measurementNoiseVariance,
      'processNoiseRateVariance': processNoiseRateVariance,
      'useKalmanFilter': useKalmanFilter,
      'weightAlpha': weightAlpha,
      'weightAlphaMin': weightAlphaMin,
      'weightAlphaMax': weightAlphaMax,
      'calorieAlpha': calorieAlpha,
      'calorieAlphaMin': calorieAlphaMin,
      'calorieAlphaMax': calorieAlphaMax,
      'trendSmoothingDays': trendSmoothingDays,
    };
  }

  // Create from a map (e.g., from SharedPreferences)
  factory AlgorithmParameters.fromMap(Map<String, dynamic> map) {
    return AlgorithmParameters(
      processNoiseVariance: map['processNoiseVariance'] as double? ?? 0.01,
      measurementNoiseVariance:
          map['measurementNoiseVariance'] as double? ?? 0.25,
      processNoiseRateVariance:
          map['processNoiseRateVariance'] as double? ?? 0.001,
      useKalmanFilter: map['useKalmanFilter'] as bool? ?? true,
      weightAlpha: map['weightAlpha'] as double? ?? 0.1,
      weightAlphaMin: map['weightAlphaMin'] as double? ?? 0.05,
      weightAlphaMax: map['weightAlphaMax'] as double? ?? 0.2,
      calorieAlpha: map['calorieAlpha'] as double? ?? 0.1,
      calorieAlphaMin: map['calorieAlphaMin'] as double? ?? 0.05,
      calorieAlphaMax: map['calorieAlphaMax'] as double? ?? 0.2,
      trendSmoothingDays: map['trendSmoothingDays'] as int? ?? 7,
    );
  }

  // Access to static constants
  int get minDaysForTrend => _minDaysForTrend;
  int get tdeeBlendDurationDays => _tdeeBlendDurationDays;
  double get initialTdeeBlendDecayFactor => _initialTdeeBlendDecayFactor;
}

/// Holds the outputs of the calculation engine for display
class CalculationResult {
  final double trueWeight; // Smoothed "true" weight (Kalman filter)
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

  // Unit conversion constants
  static const double _lbsPerKg = 2.20462;
  static const double _kgPerLb = 1 / _lbsPerKg;
  static const double _cmPerInch = 2.54;
  static const double _inchesPerFoot = 12.0;

  // Default algorithm parameters
  AlgorithmParameters _algorithmParams = AlgorithmParameters();

  // Getters/setters for algorithm parameters
  AlgorithmParameters get algorithmParameters => _algorithmParams;
  set algorithmParameters(AlgorithmParameters params) {
    _algorithmParams = params;
  }

  // Constructor allows setting initial algorithm parameters
  CalculationEngine({AlgorithmParameters? algorithmParameters}) {
    if (algorithmParameters != null) {
      _algorithmParams = algorithmParameters;
    }
  }

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
        currentAlphaWeight: _algorithmParams.weightAlpha,
        currentAlphaCalorie: _algorithmParams.calorieAlpha,
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

    double currentWeightAlpha = _algorithmParams.weightAlpha;
    double currentCalorieAlpha = _algorithmParams.calorieAlpha;

    // --- 1. Weight processing: either Kalman filter or legacy EMA ---

    // Determine appropriate Kalman filter parameters based on unit system
    double processNoiseWeight;
    double processNoiseRate;
    double measurementNoiseVariance;

    if (settings.weightUnit == WeightUnitSystem.lbs) {
      // Use imperial values
      processNoiseWeight =
          _algorithmParams.processNoiseVariance; // Default 0.01
      processNoiseRate =
          _algorithmParams.processNoiseRateVariance; // Default 0.001
      measurementNoiseVariance =
          _algorithmParams.measurementNoiseVariance; // Default 0.25
    } else {
      // Use metric values - scaled down for kg
      processNoiseWeight =
          _algorithmParams.processNoiseVariance * 0.21; // Scale for kg
      processNoiseRate =
          _algorithmParams.processNoiseRateVariance * 0.21; // Scale for kg
      measurementNoiseVariance =
          _algorithmParams.measurementNoiseVariance * 0.21; // Scale for kg
    }

    // Initialize variables based on selected algorithm
    double finalTrueWeight = 0.0;
    double finalWeightTrendPerWeek = 0.0;

    if (_algorithmParams.useKalmanFilter) {
      // --- Two-state Kalman Filter implementation ---
      WeightKalmanFilter? kalmanFilter;

      // Process all weight measurements with the Kalman filter
      for (int i = 0; i < rawWeights.length; i++) {
        if (rawWeights[i] == null) {
          // Skip days with no weight data, but still store the previous estimate
          if (kalmanFilter != null) {
            weightEmaHistory.add(kalmanFilter.weightEstimate);
          }
          continue;
        }

        if (kalmanFilter == null) {
          // Initialize Kalman filter with first valid weight measurement
          kalmanFilter = WeightKalmanFilter(
            initialWeight: rawWeights[i]!,
            initialChangeRate: 0.0, // Start with no trend
            processNoiseWeight: processNoiseWeight,
            processNoiseRate: processNoiseRate,
            measurementNoise: measurementNoiseVariance,
          );
          weightEmaHistory.add(kalmanFilter.weightEstimate);
        } else {
          // Update filter with new measurement
          kalmanFilter.update(rawWeights[i]!);
          weightEmaHistory.add(kalmanFilter.weightEstimate);

          // Calculate and store daily weight deltas (for legacy code compatibility)
          if (weightEmaHistory.length >= 2) {
            double delta =
                weightEmaHistory.last -
                weightEmaHistory[weightEmaHistory.length - 2];
            dailyWeightDeltaHistory.add(delta);
          } else {
            dailyWeightDeltaHistory.add(0.0);
          }
        }

        // For compatibility with UI, adjust alpha based on filter uncertainty
        // (this doesn't affect the Kalman filter, just for display)
        if (kalmanFilter.weightVariance < 0.1) {
          // Low uncertainty - increase responsiveness
          currentWeightAlpha = min(
            _algorithmParams.weightAlphaMax,
            currentWeightAlpha + 0.01,
          );
        } else if (kalmanFilter.weightVariance > 0.5) {
          // High uncertainty - increase smoothing
          currentWeightAlpha = max(
            _algorithmParams.weightAlphaMin,
            currentWeightAlpha - 0.01,
          );
        }
      }

      // If we successfully created a Kalman filter, use its final estimates
      if (kalmanFilter != null) {
        finalTrueWeight = kalmanFilter.weightEstimate;

        // IMPORTANT: Use the Kalman filter's rate estimate directly instead of calculating deltas
        // This is the key improvement - getting rate directly from the state estimate
        finalWeightTrendPerWeek = kalmanFilter.weeklyChangeRateEstimate;

        // TODO: Add self-correcting parameter adaptation mechanism here
        // This would analyze innovation sequence and adjust process/measurement noise parameters

        // TODO: Implement "confidence interval" calculation using the error covariance matrix
        // to provide users with uncertainty bounds on their weight trend estimates
      } else {
        // Fallback to zero if no valid weights were found
        finalTrueWeight = 0.0;
        finalWeightTrendPerWeek = 0.0;
      }
    } else {
      // --- Legacy single-state Kalman Filter implementation ---
      // This is the original code kept for backward compatibility

      // Kalman filter state variables
      double stateEstimate = 0.0; // x̂ (estimated true weight)
      double estimateError = 1.0; // P (uncertainty in the estimate)
      double kalmanGain; // K (Kalman gain - how much to trust new measurements)

      for (int i = 0; i < rawWeights.length; i++) {
        if (i == 0 && rawWeights[i] != null) {
          // Initialize state with first weight value
          stateEstimate = rawWeights[i]!;
          estimateError = 1.0; // Initial uncertainty
          weightEmaHistory.add(stateEstimate);
          continue;
        }

        // Skip processing if no weight data for this entry
        if (rawWeights[i] == null) {
          // No weight data today - carry forward previous estimate
          if (weightEmaHistory.isNotEmpty) {
            weightEmaHistory.add(stateEstimate);
          }
          continue;
        }

        // --- PREDICT STEP ---
        // Project the state ahead (prediction)
        // In a simple tracking problem, the process model is x_k = x_{k-1}
        // So our prior estimate is just the previous state
        double priorEstimate = stateEstimate;

        // Project the error covariance ahead
        // P_k = P_{k-1} + Q (add process noise)
        double priorEstimateError = estimateError + processNoiseWeight;

        // --- UPDATE STEP ---
        // Compute the Kalman gain
        // K_k = P_k / (P_k + R)
        kalmanGain =
            priorEstimateError /
            (priorEstimateError + measurementNoiseVariance);

        // Update estimate with measurement
        // x̂_k = x̂_k' + K_k(z_k - x̂_k')
        stateEstimate =
            priorEstimate + kalmanGain * (rawWeights[i]! - priorEstimate);

        // Update the error covariance
        // P_k = (1 - K_k)P_k'
        estimateError = (1 - kalmanGain) * priorEstimateError;

        // Store the filtered weight for this day
        weightEmaHistory.add(stateEstimate);

        // For compatibility with current UI display, preserve current alpha
        // This will eventually be removed as alpha is not used in Kalman filtering
        if (estimateError < 0.1) {
          // Low uncertainty - increase responsiveness
          currentWeightAlpha = min(
            _algorithmParams.weightAlphaMax,
            currentWeightAlpha + 0.01,
          );
        } else if (estimateError > 0.5) {
          // High uncertainty - increase smoothing
          currentWeightAlpha = max(
            _algorithmParams.weightAlphaMin,
            currentWeightAlpha - 0.01,
          );
        }
      }

      finalTrueWeight =
          weightEmaHistory.isNotEmpty ? weightEmaHistory.last : 0.0;

      // Calculate daily weight deltas for trend calculation
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
      if (dailyWeightDeltaHistory.length >=
          _algorithmParams.trendSmoothingDays) {
        // Use the most recent N days for the trend
        finalWeightTrendPerDay =
            dailyWeightDeltaHistory
                .sublist(
                  dailyWeightDeltaHistory.length -
                      _algorithmParams.trendSmoothingDays,
                )
                .reduce((a, b) => a + b) /
            _algorithmParams.trendSmoothingDays;
      } else if (dailyWeightDeltaHistory.isNotEmpty) {
        // Use all available days if we don't have enough
        finalWeightTrendPerDay =
            dailyWeightDeltaHistory.reduce((a, b) => a + b) /
            dailyWeightDeltaHistory.length;
      }
      finalWeightTrendPerWeek = finalWeightTrendPerDay * 7;
    }

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
                _algorithmParams.calorieAlphaMax,
                currentCalorieAlpha + 0.01,
              );
            } else if (cv > 0.35 || missingPercent > 30.0) {
              // Data is inconsistent or incomplete - increase smoothing
              currentCalorieAlpha = max(
                _algorithmParams.calorieAlphaMin,
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

    // --- 4. TDEE Estimation (Algorithm) ---
    // Get appropriate energy equivalent based on weight unit setting
    double energyEquivalent = _getEnergyEquivalent(settings);
    double estimatedTdeeAlgo = 0.0;

    if (calorieEmaHistory.isNotEmpty &&
        weightEmaHistory.length >= _algorithmParams.minDaysForTrend) {
      // Calculate TDEE using energy balance principle:
      // TDEE = Calories In - (Energy Equivalent * Weight Change)
      double lastCalorieEma = calorieEmaHistory.last;
      estimatedTdeeAlgo =
          lastCalorieEma - (energyEquivalent * (finalWeightTrendPerWeek / 7.0));

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

    if (history.length < _algorithmParams.tdeeBlendDurationDays &&
        history.length >= _algorithmParams.minDaysForTrend) {
      // Calculate blend factor that decays over time
      tdeeBlendFactor =
          pow(
            _algorithmParams.initialTdeeBlendDecayFactor,
            history.length - _algorithmParams.minDaysForTrend,
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
    } else if (history.length >= _algorithmParams.tdeeBlendDurationDays) {
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

    // Target = TDEE + Deficit/Surplus (negative for weight loss, positive for gain)
    double targetCaloriesAlgo =
        finalEstimatedTdeeAlgo + targetDeficitOrSurplusPerDay;

    // --- Standard Formula Calculations (for comparison) ---
    double estimatedTdeeStandard = _calculateStandardTdee(
      settings,
      finalTrueWeight,
    );
    double targetCaloriesStandard =
        estimatedTdeeStandard + targetDeficitOrSurplusPerDay;

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
