// lib/models/user_settings.dart

/// Shared model for user profile and algorithm parameters
/// Used by SettingsRepository and CalculationEngine
library;

enum BiologicalSex { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

// START OF CHANGES
enum WeightUnitSystem { kg, lbs }

enum HeightUnitSystem { cm, ft_in }
// END OF CHANGES

class UserSettings {
  /// Profile
  final double height;
  final int age;
  final BiologicalSex sex;
  final ActivityLevel activityLevel;

  // START OF CHANGES
  /// Unit Preferences
  final WeightUnitSystem weightUnit;
  final HeightUnitSystem heightUnit;
  // END OF CHANGES

  /// Goal
  final double goalRate; // e.g. percentage per week or lbs per week

  /// EMA parameters
  final double weightAlpha;
  final double weightAlphaMin;
  final double weightAlphaMax;
  final double calorieAlpha;
  final double calorieAlphaMin;
  final double calorieAlphaMax;
  final int trendSmoothingDays;

  UserSettings({
    this.height =
        170.0, // Default height unit will correspond to default heightUnit (cm)
    this.age = 30,
    this.sex = BiologicalSex.male,
    this.activityLevel = ActivityLevel.lightlyActive,
    // START OF CHANGES
    this.weightUnit = WeightUnitSystem.kg, // Default to kg
    this.heightUnit = HeightUnitSystem.cm, // Default to cm
    // END OF CHANGES
    this.goalRate = 0.0,
    this.weightAlpha = 0.1,
    this.weightAlphaMin = 0.05,
    this.weightAlphaMax = 0.2,
    this.calorieAlpha = 0.1,
    this.calorieAlphaMin = 0.05,
    this.calorieAlphaMax = 0.2,
    this.trendSmoothingDays = 7,
  });

  UserSettings copyWith({
    double? height,
    int? age,
    BiologicalSex? sex,
    ActivityLevel? activityLevel,
    // START OF CHANGES
    WeightUnitSystem? weightUnit,
    HeightUnitSystem? heightUnit,
    // END OF CHANGES
    double? goalRate,
    double? weightAlpha,
    double? weightAlphaMin,
    double? weightAlphaMax,
    double? calorieAlpha,
    double? calorieAlphaMin,
    double? calorieAlphaMax,
    int? trendSmoothingDays,
  }) {
    return UserSettings(
      height: height ?? this.height,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      // START OF CHANGES
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      // END OF CHANGES
      goalRate: goalRate ?? this.goalRate,
      weightAlpha: weightAlpha ?? this.weightAlpha,
      weightAlphaMin: weightAlphaMin ?? this.weightAlphaMin,
      weightAlphaMax: weightAlphaMax ?? this.weightAlphaMax,
      calorieAlpha: calorieAlpha ?? this.calorieAlpha,
      calorieAlphaMin: calorieAlphaMin ?? this.calorieAlphaMin,
      calorieAlphaMax: calorieAlphaMax ?? this.calorieAlphaMax,
      trendSmoothingDays: trendSmoothingDays ?? this.trendSmoothingDays,
    );
  }

  // START OF CHANGES
  // Helper to get a string representation for display
  String get weightUnitString =>
      weightUnit == WeightUnitSystem.kg ? 'kg' : 'lbs';
  String get heightUnitString =>
      heightUnit == HeightUnitSystem.cm ? 'cm' : 'ft/in';
  // END OF CHANGES
}
