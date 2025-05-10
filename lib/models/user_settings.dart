/// Shared model for user profile and algorithm parameters
/// Used by SettingsRepository and CalculationEngine

enum BiologicalSex { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

class UserSettings {
  /// Profile
  final double height; // in cm or inches based on units setting
  final int age;
  final BiologicalSex sex;
  final ActivityLevel activityLevel;

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
    this.height = 170.0,
    this.age = 30,
    this.sex = BiologicalSex.male,
    this.activityLevel = ActivityLevel.lightlyActive,
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
}
