# CLAUDE.md

This file provides guidance to Claude Code when working on the Validation App project. It captures project context, preferences, and key notes to ensure effective contributions.

## Project Overview

* **Name:** Weight Tracker Validation App
* **Purpose:** A personal tool to test and refine weight and calorie tracking algorithms. Implements both EMA-based and 2-State Kalman Filter approaches for comparison. Not intended for public release; used solely for private experimentation and validation.
* **Stack:** Flutter (Dart), Provider for state management, SQLite via `sqflite`, Shared Preferences, `fl_chart` for graphs.
* **Pattern:** MVVM—Models, Data (Repository/Database), Calculation Engine, ViewModels, UI Screens.

## Core Algorithms

* **2-State Kalman Filter:** Primary algorithm for weight and trend estimation. Implemented in `WeightKalmanFilter` class with Matrix math support.
  * Simultaneously estimates both true weight and daily weight change rate
  * Provides direct access to trend via state vector (`weightEstimate`, `changeRateEstimate`, `weeklyChangeRateEstimate`)
  * Handles unit scaling appropriately (LBS vs KG)
* **Legacy EMA Approach:** Alternative algorithm using single-state Kalman filter or EMA for weight and fixed-window averaging for trend.
  * Toggled via `useKalmanFilter` flag in `AlgorithmParameters`
* **TDEE Estimation:** Uses energy balance equation `TDEE = Calories In - (Energy Equivalent * Weight Change)`. Weekly trend is converted to daily rate by dividing by 7.0.
* **Planned Self-Correcting Functionality:** 
  * Future implementation will include self-tuning parameter adaptation based on innovation sequence analysis
  * Algorithm parameters will automatically adjust as more data points are collected
  * Will improve accuracy over time through statistical analysis of prediction errors
  * Outlier detection and dynamic process noise adjustment planned
  * TODOs exist in the codebase (marked in `WeightKalmanFilter` class) for these enhancements

## Testing

* **Approach:** Build and run the app locally on a device or emulator, interact with the UI, and manually note any issues or bugs. No formal unit or widget tests are required; iterative feedback based on personal usage is sufficient.

## Repository Etiquette

* **Branches:** `feature/<name>`, `bugfix/<ticket>`, `hotfix/<issue>`
* **Commits:** Use imperative, present tense (e.g., "Add weight EMA logic").
* **Pull Requests:** Rebase to maintain a linear history; squash minor fix commits.
* **Self-Review:** Focus on clarity, correctness, and minimal personal style consistency.

## Known Limitations & Warnings

* **Personal Use Only:** This validation app is for private algorithm refinement. It does not need to meet production or public-ready standards.
* **No Cloud Sync:** Data remains local; use manual import/export as needed.
* **Orientation Locked:** Portrait mode only.
* **Dynamic Alpha Ranges:** Defined in `UserSettings`; adjust via the Settings screen as needed.
* **UI Tooltips:** Information icons in the calculation results section provide accurate descriptions of how values are calculated. These have been updated to match the 2-State Kalman filter implementation.