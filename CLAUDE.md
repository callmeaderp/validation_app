# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter-based Weight Tracker Validation app that helps users track their weight and calorie intake, and provides personalized recommendations based on both standard formulas and an algorithmic approach that analyzes the user's actual data.

Key features:
- Weight and calorie tracking
- Weight trend analysis using Exponential Moving Average (EMA)
- TDEE (Total Daily Energy Expenditure) calculation using both standard formulas and data-driven algorithms
- Personalized calorie targets based on user goals
- Data visualization with graphs
- CSV/JSON import and export

## Development Commands

### Setup and Installation

```bash
# Install Flutter dependencies
flutter pub get

# Run the app in debug mode
flutter run

# Run the app on a specific device 
flutter run -d <device_id>
```

### Build and Release

```bash
# Build APK for Android
flutter build apk

# Build app bundle for Android Play Store
flutter build appbundle

# Build for iOS
flutter build ios

# Build for web
flutter build web
```

### Testing

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart
```

### Formatting and Linting

```bash
# Format code
flutter format .

# Analyze code for issues
flutter analyze
```

## Core Architecture

The app follows a Model-View-ViewModel (MVVM) pattern:

1. **Models** (`/lib/models/`)
   - `user_settings.dart` - Contains user profile data and algorithm parameters

2. **Data Layer** (`/lib/data/`)
   - `database/DatabaseHelper.dart` - SQLite database access
   - `database/log_entry.dart` - Entity for weight/calorie entries
   - `repository/tracker_repository.dart` - Repository for log entries
   - `repository/settings_repository.dart` - Repository for user settings

3. **Calculation Engine** (`/lib/calculation/`)
   - `calculation_engine.dart` - Core algorithm for weight trend analysis and TDEE calculation

4. **UI** (`/lib/ui/`)
   - Screen implementations (input, graphs, history, settings)
   - `app_theme.dart` - Theming configuration
   - `graph_screen.dart` - Interactive data visualization with dual-axis support for weight and calorie data

5. **ViewModels** (`/lib/viewmodel/`)
   - `log_input_status_notifier.dart` - ViewModel connecting UI to data/calculation layers

6. **Main Application** (`/lib/main.dart`)
   - App initialization and primary UI setup
   - Navigation structure

## Key Calculations

### Weight Analysis

The app uses a dynamic Exponential Moving Average (EMA) to smooth weight data:
- EMA_today = α × weight_today + (1-α) × EMA_yesterday
- α is dynamically adjusted based on data consistency
- Trend is calculated over a configurable period (default 7 days)

### TDEE Calculation

Two methods are used:

1. **Algorithm-based**: 
   - TDEE = Average Calories - (Energy Equivalent × Weight Change)
   - Energy Equivalent is 3500 kcal/lb or 7700 kcal/kg

2. **Standard Formula** (Mifflin-St Jeor):
   - BMR = 10W + 6.25H - 5A + s  (where W=weight, H=height, A=age, s=5 for males, -161 for females)
   - TDEE = BMR × Activity Multiplier

### Target Calorie Calculation

- Target Calories = TDEE + (Goal Rate × Current Weight × Energy Equivalent / 7)
  - Goal Rate is expressed as a percentage of body weight per week
  - Negative Goal Rate indicates desired weight loss
  - Positive Goal Rate indicates desired weight gain

## Important Implementation Notes

1. **Database Structure**:
   - Single table `log_entries` with date as PRIMARY KEY
   - Fields: date, rawWeight, rawPreviousDayCalories

2. **Unit Systems**:
   - Support for both metric (kg, cm) and imperial (lbs, ft/in)
   - Calculation engine handles conversions internally

3. **Data Import/Export**:
   - Basic CSV format for compatibility
   - Detailed JSON format with calculation history
   - Support for both file import and direct text paste

4. **Dynamic Algorithm Parameters**:
   - Alpha values for EMAs are adjusted dynamically based on data quality
   - Standard formula results are blended with algorithm results during initial weeks

5. **Data Visualization**:
   - Dual-axis charting for weight and calorie data simultaneously
   - Scaling system to display weight and calorie data with proper visual correlation
   - Toggle between relative scale (optimized for visible data) and absolute scale (starting from 0)
   - Interactive tooltips showing accurate values for all data series