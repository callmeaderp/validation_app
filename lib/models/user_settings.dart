// lib/models/user_settings.dart

/// Shared model for user profile and settings
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

enum WeightUnitSystem { kg, lbs }

enum HeightUnitSystem { cm, ft_in }

class UserSettings {
  /// Profile
  final double height;
  final int age;
  final BiologicalSex sex;
  final ActivityLevel activityLevel;

  /// Unit Preferences
  final WeightUnitSystem weightUnit;
  final HeightUnitSystem heightUnit;

  /// Goal
  final double goalRate; // e.g. percentage per week or lbs per week

  UserSettings({
    this.height = 170.0, // Default height unit will correspond to default heightUnit (cm)
    this.age = 30,
    this.sex = BiologicalSex.male,
    this.activityLevel = ActivityLevel.lightlyActive,
    this.weightUnit = WeightUnitSystem.kg, // Default to kg
    this.heightUnit = HeightUnitSystem.cm, // Default to cm
    this.goalRate = 0.0,
  });

  UserSettings copyWith({
    double? height,
    int? age,
    BiologicalSex? sex,
    ActivityLevel? activityLevel,
    WeightUnitSystem? weightUnit,
    HeightUnitSystem? heightUnit,
    double? goalRate,
  }) {
    return UserSettings(
      height: height ?? this.height,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      goalRate: goalRate ?? this.goalRate,
    );
  }

  // Helper to get a string representation for display
  String get weightUnitString =>
      weightUnit == WeightUnitSystem.kg ? 'kg' : 'lbs';
  String get heightUnitString =>
      heightUnit == HeightUnitSystem.cm ? 'cm' : 'ft/in';
}
